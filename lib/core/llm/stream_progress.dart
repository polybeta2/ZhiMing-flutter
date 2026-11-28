import 'dart:async';

import 'package:flutter/foundation.dart';

import 'llm_types.dart';

enum StreamStage { idle, waitingFirstToken, thinking, outputting }

class StreamProgressState {
  const StreamProgressState({
    this.stage = StreamStage.idle,
    this.reasoningChars = 0,
    this.reasoningText = '',
    this.thinkingElapsedSeconds = 0,
    this.contentChars = 0,
    this.elapsedSeconds = 0,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.cachedTokens = 0,
    this.lastUsage,
  });

  final StreamStage stage;
  final int reasoningChars;
  final String reasoningText;
  final double thinkingElapsedSeconds;
  final int contentChars;
  final double elapsedSeconds;
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final UsageReport? lastUsage;

  bool get isActive => stage != StreamStage.idle;
  bool get hasReasoning => reasoningText.isNotEmpty || reasoningChars > 0;

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
    String? reasoningText,
    double? thinkingElapsedSeconds,
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
      reasoningText: reasoningText ?? this.reasoningText,
      thinkingElapsedSeconds:
          thinkingElapsedSeconds ?? this.thinkingElapsedSeconds,
      contentChars: contentChars ?? this.contentChars,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
      lastUsage: clearUsage ? null : (lastUsage ?? this.lastUsage),
    );
  }
}

/// 流式生成状态跟踪器：等待首 Token → 深度思考（实时捕获思考文本与耗时）→ 输出中
class StreamProgressTracker extends ValueNotifier<StreamProgressState> {
  StreamProgressTracker() : super(const StreamProgressState());

  /// 内存思考文本上限（超出仅截留末尾以防超长推理链撑爆 UI 渲染内存）
  static const int maxCapturedReasoningChars = 60000;

  DateTime _stageStart = DateTime.now();
  DateTime? _thinkingStart;
  Timer? _timer;
  UsageReport? _lastCompletedUsage;
  final StringBuffer _reasoningBuf = StringBuffer();
  int _lastCompletedReasoningChars = 0;
  String _lastCompletedReasoningText = '';
  double _lastCompletedThinkingSeconds = 0;

  /// 最近一次流式请求已上报的用量快照（在 `finish()` 后保留，直到下一次 `begin()` 清除）
  UsageReport? get lastCompletedUsage => _lastCompletedUsage;

  /// 最近一次流式请求捕获的思考链正文（在 `finish()` 后保留，直到下一次 `begin()` 清除）
  String get lastCompletedReasoningText => _lastCompletedReasoningText;

  /// 最近一次流式请求的思考阶段耗时（秒）
  double get lastCompletedThinkingSeconds => _lastCompletedThinkingSeconds;

  void begin() {
    _lastCompletedUsage = null;
    _reasoningBuf.clear();
    _thinkingStart = null;
    _lastCompletedReasoningChars = 0;
    _lastCompletedReasoningText = '';
    _lastCompletedThinkingSeconds = 0;
    _enter(StreamStage.waitingFirstToken, resetCounters: true);
  }

  void handle(StreamEvent event) {
    switch (event) {
      case ReasoningDelta(:final text):
        if (text.isEmpty) return;
        final nextCount = value.reasoningChars + text.length;
        _reasoningBuf.write(text);
        var captured = _reasoningBuf.toString();
        if (captured.length > maxCapturedReasoningChars) {
          captured =
              '…（前段已省略）\n${captured.substring(captured.length - maxCapturedReasoningChars)}';
        }
        _thinkingStart ??= DateTime.now();
        final thinkSec =
            DateTime.now().difference(_thinkingStart!).inMilliseconds / 1000.0;
        _lastCompletedReasoningChars = nextCount;
        _lastCompletedReasoningText = captured;
        _lastCompletedThinkingSeconds = thinkSec;
        if (value.stage != StreamStage.outputting) {
          _enter(StreamStage.thinking);
        }
        value = value.copyWith(
          reasoningChars: nextCount,
          reasoningText: captured,
          thinkingElapsedSeconds: thinkSec,
        );
      case ContentDelta(:final text):
        final nextCount = value.contentChars + text.length;
        if (_thinkingStart != null && value.stage == StreamStage.thinking) {
          _lastCompletedThinkingSeconds =
              DateTime.now().difference(_thinkingStart!).inMilliseconds /
              1000.0;
        }
        _enter(StreamStage.outputting);
        value = value.copyWith(
          contentChars: nextCount,
          thinkingElapsedSeconds: _lastCompletedThinkingSeconds,
        );
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
          finishReason: event.finishReason ?? value.lastUsage?.finishReason,
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
    if (_thinkingStart != null && value.stage == StreamStage.thinking) {
      _lastCompletedThinkingSeconds =
          DateTime.now().difference(_thinkingStart!).inMilliseconds / 1000.0;
    }
    value = StreamProgressState(
      reasoningChars: _lastCompletedReasoningChars,
      reasoningText: _lastCompletedReasoningText,
      thinkingElapsedSeconds: _lastCompletedThinkingSeconds,
      promptTokens: _lastCompletedUsage?.promptTokens ?? 0,
      completionTokens: _lastCompletedUsage?.completionTokens ?? 0,
      cachedTokens: _lastCompletedUsage?.cachedTokens ?? 0,
      lastUsage: _lastCompletedUsage,
    );
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
      if (value.stage == StreamStage.thinking && _thinkingStart != null) {
        final thinkSec =
            DateTime.now().difference(_thinkingStart!).inMilliseconds / 1000.0;
        _lastCompletedThinkingSeconds = thinkSec;
        value = value.copyWith(
          elapsedSeconds: secs,
          thinkingElapsedSeconds: thinkSec,
        );
      } else {
        value = value.copyWith(elapsedSeconds: secs);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
