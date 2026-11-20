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
  });

  final StreamStage stage;
  final int reasoningChars;
  final int contentChars;
  final double elapsedSeconds;
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;

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
      StreamStage.waitingFirstToken => '正在等待首 Token · $sec',
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
  }) {
    return StreamProgressState(
      stage: stage ?? this.stage,
      reasoningChars: reasoningChars ?? this.reasoningChars,
      contentChars: contentChars ?? this.contentChars,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      cachedTokens: cachedTokens ?? this.cachedTokens,
    );
  }
}

/// 流式生成状态跟踪器：等待首 Token → 深度思考 → 输出中
class StreamProgressTracker extends ValueNotifier<StreamProgressState> {
  StreamProgressTracker() : super(const StreamProgressState());

  DateTime _stageStart = DateTime.now();
  Timer? _timer;

  void begin() {
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
      case UsageReport(
        :final promptTokens,
        :final completionTokens,
        :final cachedTokens,
      ):
        value = value.copyWith(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          cachedTokens: cachedTokens,
        );
    }
  }

  void finish() {
    _timer?.cancel();
    _timer = null;
    value = const StreamProgressState();
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
