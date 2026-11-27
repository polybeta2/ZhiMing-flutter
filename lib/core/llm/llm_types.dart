import 'package:dio/dio.dart';

enum LLMRole {
  system('system'),
  user('user'),
  assistant('assistant');

  const LLMRole(this.value);
  final String value;
}

enum ReasoningEffort {
  minimal('minimal'),
  low('low'),
  medium('medium'),
  high('high');

  const ReasoningEffort(this.wireValue);
  final String wireValue;
}

class LLMMessage {
  const LLMMessage({
    required this.role,
    required this.content,
    this.cacheControl = false,
  });

  final LLMRole role;
  final String content;
  final bool cacheControl;

  Map<String, dynamic> toJson({bool withCacheControl = false}) {
    if (withCacheControl && cacheControl) {
      return {
        'role': role.value,
        'content': [
          {
            'type': 'text',
            'text': content,
            'cache_control': {'type': 'ephemeral'},
          },
        ],
      };
    }
    return {'role': role.value, 'content': content};
  }
}

class GenerationConfig {
  const GenerationConfig({
    this.temperature = 0.8,
    this.maxTokens = 16384,
    this.includeUsage = true,
    this.jsonMode = false,
    this.reasoningEffort,
    this.enablePromptCacheControl = false,
  });

  final double temperature;
  final int maxTokens;
  final bool includeUsage;
  final bool jsonMode;
  final ReasoningEffort? reasoningEffort;
  final bool enablePromptCacheControl;
}

/// 流式事件：思维链、正文与真实用量分通道
sealed class StreamEvent {
  const StreamEvent();
}

final class ReasoningDelta extends StreamEvent {
  const ReasoningDelta(this.text);
  final String text;
}

final class ContentDelta extends StreamEvent {
  const ContentDelta(this.text);
  final String text;
}

final class UsageReport extends StreamEvent {
  const UsageReport({
    required this.promptTokens,
    required this.completionTokens,
    this.cachedTokens = 0,
    this.reasoningTokens = 0,
    this.cacheCreationTokens = 0,
  });

  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int reasoningTokens;
  final int cacheCreationTokens;

  /// KV 前缀缓存命中率（0.0 ~ 1.0）
  double get cacheHitRate =>
      promptTokens > 0 ? (cachedTokens / promptTokens).clamp(0.0, 1.0) : 0.0;
}

class LLMException implements Exception {
  const LLMException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory LLMException.invalidUrl() => const LLMException('接口地址无效');

  factory LLMException.httpStatus(int code, String body) {
    final safe = redactCredentials(body);
    final clipped = safe.length > 240 ? '${safe.substring(0, 240)}…' : safe;
    return LLMException('请求失败（$code）：$clipped', statusCode: code);
  }

  factory LLMException.decoding(String raw) {
    final safe = redactCredentials(raw);
    final clipped = safe.length > 240 ? '${safe.substring(0, 240)}…' : safe;
    return LLMException('响应解析失败：$clipped');
  }

  static final RegExp _bearerRe = RegExp(
    r'Bearer\s+\S+',
    caseSensitive: false,
  );

  /// 抹掉错误文本中可能被上游网关回显的 Bearer 凭据
  static String redactCredentials(String raw) =>
      raw.replaceAll(_bearerRe, 'Bearer ***');

  @override
  String toString() => message;
}

abstract class LLMClient {
  Stream<StreamEvent> streamChat(
    List<LLMMessage> messages, {
    required GenerationConfig config,
    CancelToken? cancelToken,
  });

  Future<String> testConnection({CancelToken? cancelToken});

  Future<List<String>> fetchModelIds({CancelToken? cancelToken});
}

extension LLMMessageListExt on List<LLMMessage> {
  int get totalContentChars => fold(0, (sum, m) => sum + m.content.length);
}
