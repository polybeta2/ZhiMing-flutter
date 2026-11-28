import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import 'llm_types.dart';

/// OpenAI 兼容 SSE 流式客户端：
/// - 修复原版 B5：分离连接超时（20s）与分片空闲超时（90s），不再因长思考/长输出 120s 总时长硬断；
/// - 完整支持 reasoning_content / reasoning / content / usage / finish_reason / 流中 error 帧；
/// - 支持默认推理强度注入、思考模式 32K 输出兜底、「思考链饿死正文」明确报错与端点扩展降级缓存；
/// - 支持可选 HTTP 代理配置。
class OpenAiSseClient implements LLMClient {
  OpenAiSseClient({
    required String baseUrl,
    required this.apiKey,
    required this.model,
    this.proxyUrl,
    this.defaultReasoningEffort,
    Dio? dio,
  }) : _baseUrl = baseUrl.trim(),
       _dio = dio ?? _createDio(proxyUrl);

  final String _baseUrl;
  final String apiKey;
  final String model;
  final String? proxyUrl;
  final ReasoningEffort? defaultReasoningEffort;
  final Dio _dio;

  /// 记录已知不支持 `response_format` / `reasoning_effort` 等扩展参数的网关+模型组合，
  /// 避免每次请求都重复试探一次 HTTP 400/422 往返。
  static final Set<String> _unsupportedExtensionEndpoints = <String>{};

  @visibleForTesting
  static void clearUnsupportedExtensionCache() {
    _unsupportedExtensionEndpoints.clear();
  }

  String _extensionCacheKey(ReasoningEffort? effort) =>
      '$_baseUrl|${model.trim()}|${effort?.wireValue ?? 'default'}';

  static bool _looksLikeEffortRejection(String body) {
    final lower = body.toLowerCase();
    return lower.contains('reasoning_effort') ||
        lower.contains('reasoning') ||
        lower.contains('effort');
  }

  static Dio _createDio(String? proxyUrl) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 150),
        validateStatus: (_) => true,
      ),
    );
    final trimmedProxy = proxyUrl?.trim();
    if (trimmedProxy != null && trimmedProxy.isNotEmpty) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          final cleaned = trimmedProxy
              .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
          client.findProxy = (_) => 'PROXY $cleaned';
          return client;
        },
      );
    }
    return dio;
  }

  Uri _buildEndpoint(String suffix) {
    if (_baseUrl.isEmpty) throw LLMException.invalidUrl();
    final normalized = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
    final uri = Uri.tryParse('$normalized$suffix');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw LLMException.invalidUrl();
    }
    return uri;
  }

  bool get _supportsExplicitCacheControl =>
      model.toLowerCase().contains('claude') ||
      _baseUrl.toLowerCase().contains('anthropic');

  /// 构造请求体：支持 JSON Mode、reasoning_effort 与 Anthropic 显式 cache_control 断点
  static Map<String, dynamic> buildRequestBody({
    required String model,
    required List<LLMMessage> messages,
    required GenerationConfig config,
    bool useExplicitCacheControl = false,
  }) {
    return <String, dynamic>{
      'model': model,
      'stream': true,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'messages': [
        for (final m in messages)
          m.toJson(withCacheControl: useExplicitCacheControl),
      ],
      if (config.includeUsage) 'stream_options': {'include_usage': true},
      if (config.jsonMode) 'response_format': {'type': 'json_object'},
      if (config.reasoningEffort != null)
        'reasoning_effort': config.reasoningEffort!.wireValue,
    };
  }

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final uri = _buildEndpoint('chat/completions');
    final resolvedEffort = config.reasoningEffort ?? defaultReasoningEffort;
    final isThinkingEnabled =
        resolvedEffort != null && resolvedEffort.isThinkingEnabled;
    final resolvedMaxTokens =
        (isThinkingEnabled &&
            config.maxTokens >= 12288 &&
            config.maxTokens < 32768)
        ? math.max(config.maxTokens, 32768)
        : config.maxTokens;
    final resolvedConfig = GenerationConfig(
      temperature: config.temperature,
      maxTokens: resolvedMaxTokens,
      includeUsage: config.includeUsage,
      jsonMode: config.jsonMode,
      reasoningEffort: resolvedEffort,
      enablePromptCacheControl: config.enablePromptCacheControl,
    );

    final extCacheKey = _extensionCacheKey(resolvedEffort);
    var allowOptionalExtensions =
        !_unsupportedExtensionEndpoints.contains(extCacheKey);
    final hasOptionalExtensions =
        resolvedConfig.jsonMode ||
        resolvedConfig.reasoningEffort != null ||
        (resolvedConfig.enablePromptCacheControl &&
            _supportsExplicitCacheControl);

    const maxPreTokenAttempts = 3;
    for (var attempt = 0; attempt < maxPreTokenAttempts; attempt++) {
      if (cancelToken?.isCancelled ?? false) return;
      // 仅以实际输出正文（ContentDelta）作为不可重放分界线；思考流中断可安全重连重试
      var yieldedContent = false;

      final effectiveConfig = allowOptionalExtensions
          ? resolvedConfig
          : GenerationConfig(
              temperature: resolvedConfig.temperature,
              maxTokens: resolvedConfig.maxTokens,
              includeUsage: resolvedConfig.includeUsage,
            );
      final useCache =
          allowOptionalExtensions &&
          effectiveConfig.enablePromptCacheControl &&
          _supportsExplicitCacheControl;
      final body = buildRequestBody(
        model: model,
        messages: messages,
        config: effectiveConfig,
        useExplicitCacheControl: useCache,
      );

      Response<ResponseBody> response;
      try {
        response = await _dio.postUri<ResponseBody>(
          uri,
          data: body,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            validateStatus: (_) => true,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'text/event-stream',
              'Authorization': 'Bearer $apiKey',
            },
          ),
        );
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) return;
        final isLast = attempt == maxPreTokenAttempts - 1;
        if (!isLast && _isRetryableDio(e)) {
          await _retryBackoff(attempt, cancelToken);
          continue;
        }
        final detail = e.error?.toString() ?? e.message ?? e.type.name;
        throw LLMException(
          LLMException.redactCredentials('网络请求失败（${e.type.name}）：$detail'),
        );
      }

      final status = response.statusCode ?? 0;
      final streamBody = response.data;
      if (streamBody == null) {
        if (attempt < maxPreTokenAttempts - 1) {
          await _retryBackoff(attempt, cancelToken);
          continue;
        }
        throw LLMException.httpStatus(status, '响应体为空');
      }

      if (status != 200) {
        final buffer = StringBuffer();
        await for (final chunk in streamBody.stream) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
          if (buffer.length >= 4096) {
            buffer.write('……');
            break;
          }
        }
        if ((status == 400 || status == 422) &&
            allowOptionalExtensions &&
            hasOptionalExtensions) {
          final errBody = buffer.toString();
          // 扩展高档位（Xhigh / Max / Ultra）被端点明确拒绝时，直接给出清晰提示便于用户改选可用档位，
          // 不静默吞掉也不污染标准档位缓存。
          if (resolvedEffort != null &&
              resolvedEffort.isExtendedTier &&
              _looksLikeEffortRejection(errBody)) {
            final safe = LLMException.redactCredentials(errBody);
            final clipped = safe.length > 200
                ? '${safe.substring(0, 200)}…'
                : safe;
            throw LLMException(
              '当前 API 端点不支持 Effort「${resolvedEffort.label}」'
              '（${resolvedEffort.wireValue}），请在 Effort 选择条改选其他档位。'
              '服务端返回：$clipped',
              statusCode: status,
            );
          }
          if (attempt < maxPreTokenAttempts - 1) {
            _unsupportedExtensionEndpoints.add(extCacheKey);
            allowOptionalExtensions = false;
            continue;
          }
        }
        if (attempt < maxPreTokenAttempts - 1 && _isRetryableStatus(status)) {
          await _retryBackoff(attempt, cancelToken);
          continue;
        }
        throw LLMException.httpStatus(status, buffer.toString());
      }

      final lineStream = streamBody.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter());

      var contentChars = 0;
      var reasoningChars = 0;
      String? finishReason;

      try {
        await for (final line in lineStream) {
          if (cancelToken?.isCancelled ?? false) return;
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          if (payload == '[DONE]') break;

          final errorText = extractInStreamError(payload);
          if (errorText != null) {
            if (!yieldedContent && attempt < maxPreTokenAttempts - 1) {
              throw _PreTokenRetrySignal(errorText);
            }
            throw LLMException.httpStatus(500, errorText);
          }
          final chunkFinish = extractFinishReason(payload);
          if (chunkFinish != null) {
            finishReason = chunkFinish;
          }
          for (final event in extractEvents(payload)) {
            if (event is ContentDelta && event.text.isNotEmpty) {
              yieldedContent = true;
              contentChars += event.text.length;
              yield event;
            } else if (event is ReasoningDelta && event.text.isNotEmpty) {
              reasoningChars += event.text.length;
              yield event;
            } else if (event is UsageReport) {
              yield (event.finishReason == null && finishReason != null)
                  ? UsageReport(
                      promptTokens: event.promptTokens,
                      completionTokens: event.completionTokens,
                      cachedTokens: event.cachedTokens,
                      reasoningTokens: event.reasoningTokens,
                      cacheCreationTokens: event.cacheCreationTokens,
                      finishReason: finishReason,
                    )
                  : event;
            } else {
              yield event;
            }
          }
        }
        if (contentChars == 0 &&
            reasoningChars > 0 &&
            finishReason == 'length') {
          throw LLMException(
            '模型思考过程（$reasoningChars 字）耗尽了最大输出上限（${effectiveConfig.maxTokens} tokens），导致正文输出为空。建议在「设置 → 推理思考模式」选择「智能分级（推荐）」或调大模型的最大输出 Token。',
          );
        }
        return;
      } on _PreTokenRetrySignal {
        await _retryBackoff(attempt, cancelToken);
        continue;
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) return;
        if (!yieldedContent && attempt < maxPreTokenAttempts - 1) {
          await _retryBackoff(attempt, cancelToken);
          continue;
        }
        final detail = e.error?.toString() ?? e.message ?? e.type.name;
        throw LLMException(
          LLMException.redactCredentials('流式读取中断（${e.type.name}）：$detail'),
        );
      } catch (e) {
        if (e is LLMException) rethrow;
        if (!yieldedContent && attempt < maxPreTokenAttempts - 1) {
          await _retryBackoff(attempt, cancelToken);
          continue;
        }
        throw LLMException(LLMException.redactCredentials('流式读取异常：$e'));
      }
    }
  }

  static bool _isRetryableStatus(int code) =>
      code == 429 || code == 500 || code == 502 || code == 503 || code == 504;

  static bool _isRetryableDio(DioException e) => switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => true,
    _ => false,
  };

  static Future<void> _retryBackoff(
    int attempt,
    CancelToken? cancelToken,
  ) async {
    final ms = attempt == 0 ? 1200 : 2500;
    for (var elapsed = 0; elapsed < ms; elapsed += 200) {
      if (cancelToken?.isCancelled ?? false) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Future<String> testConnection({CancelToken? cancelToken}) async {
    final buffer = StringBuffer();
    var sawReasoning = false;
    await for (final event in streamChat(
      const [LLMMessage(role: LLMRole.user, content: '回复“连接成功”四个字')],
      config: const GenerationConfig(
        temperature: 0,
        maxTokens: 512,
        includeUsage: false,
        reasoningEffort: ReasoningEffort.none,
      ),
      cancelToken: cancelToken,
    )) {
      if (event is ContentDelta) {
        buffer.write(event.text);
      } else if (event is ReasoningDelta && event.text.isNotEmpty) {
        sawReasoning = true;
      }
    }
    final out = buffer.toString().trim();
    if (out.isEmpty && sawReasoning) return '连接成功（推理模型已响应）';
    return out;
  }

  @override
  Future<List<String>> fetchModelIds({CancelToken? cancelToken}) async {
    final res = await fetchModelsWithCapabilities(cancelToken: cancelToken);
    return res.modelIds;
  }

  /// 拉取 `/models` 列表并同时解析各模型可能附带的 Effort 能力元数据
  Future<
    ({List<String> modelIds, Map<String, EffortCapabilities> capabilities})
  >
  fetchModelsWithCapabilities({CancelToken? cancelToken}) async {
    final uri = _buildEndpoint('models');
    final response = await _dio.getUri<dynamic>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (_) => true,
        headers: {'Authorization': 'Bearer $apiKey'},
      ),
    );
    final status = response.statusCode ?? 0;
    if (status != 200) {
      throw LLMException.httpStatus(status, '${response.data ?? ''}');
    }
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is! Map || data['data'] is! List) {
      throw LLMException.decoding('$data');
    }
    final ids = <String>[];
    final capabilities = <String, EffortCapabilities>{};
    for (final item in data['data'] as List) {
      if (item is Map && item['id'] is String) {
        final id = item['id'] as String;
        ids.add(id);
        final cap = parseSupportedEffortsFromModelObject(item);
        if (cap.fromEndpoint) {
          capabilities[id] = cap;
        }
      }
    }
    ids.sort();
    return (modelIds: ids, capabilities: capabilities);
  }

  /// 探测当前 `model` 在该端点支持的 Effort 档位：
  /// 1) 优先读取 `GET /models` 中对应模型对象（顺带缓存同端点所有声明了能力字段的模型）；
  /// 2) 若未声明，再尝试 `GET /models/{model}`（部分网关仅在单模型详情接口返回能力元数据）；
  /// 3) 均未声明或请求异常时安全回退为 [EffortCapabilities.fallbackAll]（UI 展示全部 7 档）。
  Future<
    ({
      EffortCapabilities target,
      Map<String, EffortCapabilities> allDiscovered,
    })
  >
  probeModelEffortCapabilities({CancelToken? cancelToken}) async {
    final targetModel = model.trim();
    final discovered = <String, EffortCapabilities>{};
    try {
      final res = await fetchModelsWithCapabilities(cancelToken: cancelToken);
      discovered.addAll(res.capabilities);
      final matched = _matchCapability(discovered, targetModel);
      if (matched != null && matched.fromEndpoint) {
        return (target: matched, allDiscovered: discovered);
      }
    } catch (_) {
      // 忽略 /models 失败，继续尝试单模型接口或直接回退全档位
    }

    if (targetModel.isNotEmpty && !(cancelToken?.isCancelled ?? false)) {
      try {
        final singleUri = _buildEndpoint(
          'models/${Uri.encodeComponent(targetModel)}',
        );
        final resp = await _dio.getUri<dynamic>(
          singleUri,
          cancelToken: cancelToken,
          options: Options(
            receiveTimeout: const Duration(seconds: 8),
            validateStatus: (_) => true,
            headers: {'Authorization': 'Bearer $apiKey'},
          ),
        );
        if ((resp.statusCode ?? 0) == 200 && resp.data != null) {
          final parsed = resp.data is String
              ? jsonDecode(resp.data as String)
              : resp.data;
          if (parsed is Map) {
            final cap = parseSupportedEffortsFromModelObject(parsed);
            if (cap.fromEndpoint) {
              discovered[targetModel] = cap;
              return (target: cap, allDiscovered: discovered);
            }
          }
        }
      } catch (_) {}
    }

    return (
      target: const EffortCapabilities.fallbackAll(),
      allDiscovered: discovered,
    );
  }

  static EffortCapabilities? _matchCapability(
    Map<String, EffortCapabilities> map,
    String targetModel,
  ) {
    if (map.containsKey(targetModel)) return map[targetModel];
    final lower = targetModel.toLowerCase();
    for (final entry in map.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  /// 从任意 OpenAI 兼容网关返回的单条模型元数据 JSON 中提取可用 Effort 档位。
  /// 兼容 OpenAI / OpenRouter / LiteLLM / NewAPI / OneAPI / 自定义网关的常见字段结构。
  static EffortCapabilities parseSupportedEffortsFromModelObject(
    Map<dynamic, dynamic> obj,
  ) {
    final rawStrings = <String>[];
    final found = <ReasoningEffort>[];

    void collectValues(dynamic value) {
      if (value is List) {
        for (final item in value) {
          if (item is String && item.trim().isNotEmpty) {
            rawStrings.add(item.trim());
            final parsed = ReasoningEffort.tryParse(item);
            if (parsed != null && !found.contains(parsed)) {
              found.add(parsed);
            }
          } else if (item is Map) {
            final v = item['value'] ?? item['id'] ?? item['name'];
            if (v is String && v.trim().isNotEmpty) {
              rawStrings.add(v.trim());
              final parsed = ReasoningEffort.tryParse(v);
              if (parsed != null && !found.contains(parsed)) {
                found.add(parsed);
              }
            }
          }
        }
      } else if (value is Map) {
        for (final k in const [
          'enum',
          'values',
          'options',
          'supported',
          'allowed',
          'levels',
          'efforts',
        ]) {
          if (value.containsKey(k)) {
            collectValues(value[k]);
          }
        }
      }
    }

    const effortListKeys = <String>{
      'supported_reasoning_efforts',
      'reasoning_efforts',
      'reasoning_effort_levels',
      'allowed_reasoning_efforts',
      'reasoning_effort_values',
      'effort_levels',
      'supported_efforts',
      'efforts',
      'reasoning_effort',
      'effort',
    };

    const nestedContainers = <String>{
      'capabilities',
      'parameters',
      'extra_params',
      'reasoning',
      'metadata',
      'config',
      'model_info',
      'data',
    };

    void scanMap(Map<dynamic, dynamic> map, int depth) {
      if (depth > 4) return;
      for (final entry in map.entries) {
        final key = entry.key.toString().toLowerCase();
        final val = entry.value;
        if (effortListKeys.contains(key)) {
          if (val is List || val is Map) {
            collectValues(val);
          }
        }
        if (val is Map && nestedContainers.contains(key)) {
          scanMap(val, depth + 1);
        }
      }
    }

    scanMap(obj, 0);

    if (found.isEmpty) {
      return const EffortCapabilities.fallbackAll();
    }

    // 保持标准顺序（OFF -> Low -> Medium -> High -> Xhigh -> Max -> Ultra；若有 minimal 保留在 OFF 与 Low 之间）
    const canonicalOrder = [
      ReasoningEffort.none,
      ReasoningEffort.minimal,
      ReasoningEffort.low,
      ReasoningEffort.medium,
      ReasoningEffort.high,
      ReasoningEffort.xhigh,
      ReasoningEffort.max,
      ReasoningEffort.ultra,
    ];
    final ordered = [
      for (final tier in canonicalOrder)
        if (found.contains(tier)) tier,
    ];
    return EffortCapabilities(
      supportedEfforts: ordered,
      fromEndpoint: true,
      rawValues: rawStrings,
    );
  }

  /// 提取单帧 SSE 中的 `choices[0].finish_reason`
  static String? extractFinishReason(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final reason = first['finish_reason']?.toString().trim();
    return (reason == null || reason.isEmpty) ? null : reason;
  }

  /// 解析单帧 SSE JSON：可同时包含思维链、正文与用量信息
  static List<StreamEvent> extractEvents(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map<String, dynamic>) return const [];

    final events = <StreamEvent>[];
    String? finishReason;
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final rawReason = first['finish_reason']?.toString().trim();
        if (rawReason != null && rawReason.isNotEmpty) {
          finishReason = rawReason;
        }
      }
      if (first is Map && first['delta'] is Map) {
        final delta = first['delta'] as Map;
        final reasoning = delta['reasoning_content'] ?? delta['reasoning'];
        if (reasoning is String && reasoning.isNotEmpty) {
          events.add(ReasoningDelta(reasoning));
        }
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          events.add(ContentDelta(content));
        }
      }
    }
    final usage = decoded['usage'];
    if (usage is Map) {
      final prompt =
          (usage['prompt_tokens'] as num?)?.toInt() ??
          (usage['input_tokens'] as num?)?.toInt() ??
          0;
      final completion =
          (usage['completion_tokens'] as num?)?.toInt() ??
          (usage['output_tokens'] as num?)?.toInt() ??
          0;
      final promptDetails = usage['prompt_tokens_details'];
      final completionDetails = usage['completion_tokens_details'];
      final cached =
          (usage['prompt_cache_hit_tokens'] as num?)?.toInt() ??
          (promptDetails is Map
              ? (promptDetails['cached_tokens'] as num?)?.toInt()
              : null) ??
          (usage['cache_read_input_tokens'] as num?)?.toInt() ??
          0;
      final cacheCreation =
          (usage['cache_creation_input_tokens'] as num?)?.toInt() ?? 0;
      final reasoning = completionDetails is Map
          ? (completionDetails['reasoning_tokens'] as num?)?.toInt() ?? 0
          : 0;
      if (prompt > 0 || completion > 0 || cached > 0 || cacheCreation > 0) {
        events.add(
          UsageReport(
            promptTokens: prompt,
            completionTokens: completion,
            cachedTokens: cached,
            reasoningTokens: reasoning,
            cacheCreationTokens: cacheCreation,
            finishReason: finishReason,
          ),
        );
      }
    }
    return events;
  }

  /// 流中错误帧识别：`{"error": ...}` 且无 choices
  static String? extractInStreamError(String payload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded.containsKey('choices')) return null;
    final err = decoded['error'];
    if (err == null) return null;
    if (err is Map && err['message'] is String) {
      final msg = err['message'] as String;
      if (msg.isNotEmpty) return msg;
    }
    return err.toString();
  }
}

class _PreTokenRetrySignal implements Exception {
  const _PreTokenRetrySignal(this.reason);
  final String reason;
}
