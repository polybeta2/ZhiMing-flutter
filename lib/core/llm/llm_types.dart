import 'package:dio/dio.dart';

enum LLMRole {
  system('system'),
  user('user'),
  assistant('assistant');

  const LLMRole(this.value);
  final String value;
}

enum ReasoningEffort {
  none('none', 'OFF'),
  minimal('minimal', 'Minimal'),
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  xhigh('xhigh', 'Xhigh'),
  max('max', 'Max'),
  ultra('ultra', 'Ultra');

  const ReasoningEffort(this.wireValue, this.label);
  final String wireValue;
  final String label;

  /// UI 公开展示的 7 档标准努力程度：OFF / Low / Medium / High / Xhigh / Max / Ultra
  static const List<ReasoningEffort> selectableTiers = [
    none,
    low,
    medium,
    high,
    xhigh,
    max,
    ultra,
  ];

  /// 是否开启了推理思考（非 OFF）
  bool get isThinkingEnabled => this != ReasoningEffort.none;

  /// 是否属于扩展高档位（部分网关仅支持到 high，遇 400/422 时应显式提示而非静默降级）
  bool get isExtendedTier =>
      this == ReasoningEffort.xhigh ||
      this == ReasoningEffort.max ||
      this == ReasoningEffort.ultra;

  /// 宽松解析端点或本地缓存中的 effort 字符串
  static ReasoningEffort? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return switch (normalized) {
      'none' || 'off' || 'disabled' || 'disable' || '0' => ReasoningEffort.none,
      'minimal' || 'min' => ReasoningEffort.minimal,
      'low' => ReasoningEffort.low,
      'medium' || 'med' || 'mid' || 'normal' => ReasoningEffort.medium,
      'high' => ReasoningEffort.high,
      'xhigh' || 'x_high' || 'extra_high' || 'very_high' =>
        ReasoningEffort.xhigh,
      'max' || 'maximum' => ReasoningEffort.max,
      'ultra' => ReasoningEffort.ultra,
      _ => null,
    };
  }
}

/// 端点 Effort 能力探测结果：
/// - 若端点在 `/models` 或 `/models/{id}` 中明确声明了支持的档位，则 [fromEndpoint] 为 true，UI 仅展示声明档位；
/// - 否则 [fromEndpoint] 为 false，[displayEfforts] 回退为全部 7 档供用户自行尝试。
class EffortCapabilities {
  const EffortCapabilities({
    required this.supportedEfforts,
    required this.fromEndpoint,
    this.rawValues = const [],
  });

  const EffortCapabilities.fallbackAll()
    : supportedEfforts = const [],
      fromEndpoint = false,
      rawValues = const [];

  final List<ReasoningEffort> supportedEfforts;
  final bool fromEndpoint;
  final List<String> rawValues;

  List<ReasoningEffort> get displayEfforts =>
      (fromEndpoint && supportedEfforts.isNotEmpty)
      ? supportedEfforts
      : ReasoningEffort.selectableTiers;

  Map<String, dynamic> toJson() => {
    'supported': [for (final e in supportedEfforts) e.wireValue],
    'fromEndpoint': fromEndpoint,
    if (rawValues.isNotEmpty) 'rawValues': rawValues,
  };

  factory EffortCapabilities.fromJson(Map<String, dynamic> json) {
    final fromEndpoint = json['fromEndpoint'] == true;
    final rawList = json['supported'];
    final parsed = <ReasoningEffort>[];
    if (rawList is List) {
      for (final item in rawList) {
        final e = ReasoningEffort.tryParse(item?.toString());
        if (e != null && !parsed.contains(e)) {
          parsed.add(e);
        }
      }
    }
    final rawValues = json['rawValues'] is List
        ? (json['rawValues'] as List).map((e) => e.toString()).toList()
        : const <String>[];
    return EffortCapabilities(
      supportedEfforts: parsed,
      fromEndpoint: fromEndpoint && parsed.isNotEmpty,
      rawValues: rawValues,
    );
  }
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
    this.finishReason,
  });

  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int reasoningTokens;
  final int cacheCreationTokens;
  final String? finishReason;

  /// 是否因触发 `max_tokens` 输出上限被强制截断
  bool get isTruncatedByLength => finishReason == 'length';

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
