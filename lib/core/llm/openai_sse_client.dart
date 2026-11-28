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

  String get _endpointCacheKey => '$_baseUrl|${model.trim()}';

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
        resolvedEffort == ReasoningEffort.low ||
        resolvedEffort == ReasoningEffort.medium ||
        resolvedEffort == ReasoningEffort.high;
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

    var allowOptionalExtensions =
        !_unsupportedExtensionEndpoints.contains(_endpointCacheKey);
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
            hasOptionalExtensions &&
            attempt < maxPreTokenAttempts - 1) {
          _unsupportedExtensionEndpoints.add(_endpointCacheKey);
          allowOptionalExtensions = false;
          continue;
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
    final uri = _buildEndpoint('models');
    final response = await _dio.getUri<dynamic>(
      uri,
      cancelToken: cancelToken,
      options: Options(
        receiveTimeout: const Duration(seconds: 30),
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
    for (final item in data['data'] as List) {
      if (item is Map && item['id'] is String) {
        ids.add(item['id'] as String);
      }
    }
    ids.sort();
    return ids;
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
