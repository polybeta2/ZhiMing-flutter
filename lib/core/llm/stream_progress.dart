import 'dart:async';

import 'package:flutter/foundation.dart';

import 'llm_types.dart';

enum StreamStage { idle, waitingFirstToken, thinking, outputting }

class StreamProgressState {
  const StreamProgressState({
    this.stage = StreamStage.idle,
    this.reasoningChars = 0,
    this.contentChars = 0,
    this.elapsedSeconds = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cachedTokens = 0,
    this.lastUsage,
  });

  final StreamStage stage;
  final int reasoningChars;
  final int contentChars;
  final double elapsedSeconds;
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final UsageReport? lastUsage;

  bool get isActive => stage != StreamStage.idle;

  double get cacheHitRate =>
      promptTokens > 0 ? (cachedTokens / promptTokens).clamp(0.0, 1.0) : 0.0;

  String get statusText {
    final sec = '${elapsedSeconds.toStringAsFixed(1)}s';
    final cacheTag = cachedTokens > 0 && promptTokens > 0
        ? ' · 缓存命中 ${(cacheHitRate * 100).round()}%'
        : '';
    return switch (stage) {
      StreamStage.idle => '',
      StreamStage.waitingFirstToken => '正在等待首 Token · $sec$cacheTag',
      StreamStage.thinking => '深度思考 $reasoningChars 字 · $sec$cacheTag',
      StreamStage.outputting => '正在输出 $contentChars 字 · $sec$cacheTag',
    };
  }

  StreamProgressState copyWith({
    StreamStage? stage,
    int? reasoningChars,
    int? contentChars,
    double? elapsedSeconds,
    int? promptTokens,
    int? completionTokens,
    int? cachedTokens,
    UsageReport? lastUsage,
    bool clearUsage = false,
  }) {
    return StreamProgressState(
      stage: stage ?? this.stage,
      reasoningChars: reasoningChars ?? this.reasoningChars,
      contentChars: contentChars ?? this.contentChars,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      lastUsage: clearUsage ? null : (lastUsage ?? this.lastUsage),
    );
  }
}

/// 流式生成状态跟踪器：等待首 Token → 深度思考 → 输出中
class StreamProgressTracker extends ValueNotifier<StreamProgressState> {
  StreamProgressTracker() : super(const StreamProgressState());

  DateTime _stageStart = DateTime.now();
  Timer? _timer;
  UsageReport? _lastCompletedUsage;

  /// 最近一次流式请求已上报的用量快照（在 `finish()` 后保留，直到下一次 `begin()` 清除）
  UsageReport? get lastCompletedUsage => _lastCompletedUsage;

  void begin() {
    _lastCompletedUsage = null;
    _enter(StreamStage.waitingFirstToken, resetCounters: true);
  }

  void handle(StreamEvent event) {
    switch (event) {
      case ReasoningDelta(:final text):
        final nextCount = value.reasoningChars + text.length;
        if (value.stage != StreamStage.outputting) {
          _enter(StreamStage.thinking);
        }
        value = value.copyWith(reasoningChars: nextCount);
      case ContentDelta(:final text):
        final nextCount = value.contentChars + text.length;
        _enter(StreamStage.outputting);
        value = value.copyWith(contentChars: nextCount);
      case UsageReport():
        final mergedPrompt = event.promptTokens > 0
            ? event.promptTokens
            : value.promptTokens;
        final mergedCompletion = event.completionTokens > 0
            ? event.completionTokens
            : value.completionTokens;
        final mergedCached = event.cachedTokens > 0
            ? event.cachedTokens
            : (event.promptTokens > 0 ? event.cachedTokens : value.cachedTokens);
        final mergedCacheCreation = event.cacheCreationTokens > 0
            ? event.cacheCreationTokens
            : (event.promptTokens > 0
                  ? event.cacheCreationTokens
                  : (value.lastUsage?.cacheCreationTokens ?? 0));
        final mergedReasoning = event.reasoningTokens > 0
            ? event.reasoningTokens
            : (value.lastUsage?.reasoningTokens ?? 0);
        final mergedUsage = UsageReport(
          promptTokens: mergedPrompt,
          completionTokens: mergedCompletion,
          cachedTokens: mergedCached,
          reasoningTokens: mergedReasoning,
          cacheCreationTokens: mergedCacheCreation,
        );
        _lastCompletedUsage = mergedUsage;
        value = value.copyWith(
          promptTokens: mergedPrompt,
          completionTokens: mergedCompletion,
          cachedTokens: mergedCached,
          lastUsage: mergedUsage,
        );
    }
  }

  void finish() {
    _timer?.cancel();
    _timer = null;
    value = StreamProgressState(lastUsage: _lastCompletedUsage);
  }

  void _enter(StreamStage nextStage, {bool resetCounters = false}) {
    if (!resetCounters && value.stage == nextStage) return;
    _stageStart = DateTime.now();
    _timer?.cancel();
    value = resetCounters
        ? StreamProgressState(stage: nextStage)
        : value.copyWith(stage: nextStage, elapsedSeconds: 0);
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (value.stage == StreamStage.idle) {
        _timer?.cancel();
        return;
      }
      final secs =
          DateTime.now().difference(_stageStart).inMilliseconds / 1000.0;
      value = value.copyWith(elapsedSeconds: secs);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
