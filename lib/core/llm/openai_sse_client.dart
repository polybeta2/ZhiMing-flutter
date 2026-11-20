import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import 'llm_types.dart';

/// OpenAI 兼容 SSE 流式客户端：
/// - 修复原版 B5：分离连接超时（20s）与分片空闲超时（90s），不再因长思考/长输出 120s 总时长硬断；
/// - 完整支持 reasoning_content / reasoning / content / usage / 流中 error 帧；
/// - 支持可选 HTTP 代理配置。
class OpenAiSseClient implements LLMClient {
  OpenAiSseClient({
    required String baseUrl,
    required this.apiKey,
    required this.model,
    this.proxyUrl,
    Dio? dio,
  }) : _baseUrl = baseUrl.trim(),
       _dio = dio ?? _createDio(proxyUrl);

  final String _baseUrl;
  final String apiKey;
  final String model;
  final String? proxyUrl;
  final Dio _dio;

  static Dio _createDio(String? proxyUrl) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 90),
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

  @override
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  }) async* {
    final uri = _buildEndpoint('chat/completions');
    final body = <String, dynamic>{
      'model': model,
      'stream': true,
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'messages': [for (final m in messages) m.toJson()],
      if (config.includeUsage) 'stream_options': {'include_usage': true},
    };

    Response<ResponseBody> response;
    try {
      response = await _dio.postUri<ResponseBody>(
        uri,
        data: body,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      throw LLMException(
        LLMException.redactCredentials(e.message ?? '网络请求失败'),
      );
    }

    final status = response.statusCode ?? 0;
    final streamBody = response.data;
    if (streamBody == null) {
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
      throw LLMException.httpStatus(status, buffer.toString());
    }

    final lineStream = streamBody.stream
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (cancelToken?.isCancelled ?? false) break;
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      if (payload == '[DONE]') break;

      final errorText = extractInStreamError(payload);
      if (errorText != null) {
        throw LLMException.httpStatus(500, errorText);
      }
      for (final event in extractEvents(payload)) {
        yield event;
      }
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
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
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
      final prompt = (usage['prompt_tokens'] as num?)?.toInt() ?? 0;
      final completion = (usage['completion_tokens'] as num?)?.toInt() ?? 0;
      final promptDetails = usage['prompt_tokens_details'];
      final completionDetails = usage['completion_tokens_details'];
      final cached =
          (usage['prompt_cache_hit_tokens'] as num?)?.toInt() ??
          (promptDetails is Map
              ? (promptDetails['cached_tokens'] as num?)?.toInt() ?? 0
              : 0);
      final reasoning = completionDetails is Map
          ? (completionDetails['reasoning_tokens'] as num?)?.toInt() ?? 0
          : 0;
      if (prompt > 0 || completion > 0) {
        events.add(
          UsageReport(
            promptTokens: prompt,
            completionTokens: completion,
            cachedTokens: cached,
            reasoningTokens: reasoning,
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
