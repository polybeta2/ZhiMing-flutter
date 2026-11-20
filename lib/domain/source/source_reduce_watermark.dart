/// 并发滚动归并水位追踪器：
/// 只有当连续前缀的 seq 全部完成时，水位才推进到该前缀的最大 hiPos，
/// 防止后发批先完成导致中间失败批被断点续跑静默跳过。
class SourceReduceWatermark {
  SourceReduceWatermark({required int nextSeq, int watermark = -1})
    : _nextContiguousSeq = nextSeq,
      _watermarkValue = watermark;

  int _nextContiguousSeq;
  int _watermarkValue;
  final Map<int, int> _completed = <int, int>{};

  int get watermark => _watermarkValue;
  int get nextContiguousSeq => _nextContiguousSeq;

  /// 记录 seq 完成（覆盖到 hiPos），若水位向前推进则返回新的水位，否则返回 null。
  int? complete({required int seq, required int hiPos}) {
    if (seq < _nextContiguousSeq) return null;
    _completed[seq] = hiPos;
    var advanced = false;
    while (_completed.containsKey(_nextContiguousSeq)) {
      final hi = _completed.remove(_nextContiguousSeq)!;
      if (hi > _watermarkValue) {
        _watermarkValue = hi;
        advanced = true;
      }
      _nextContiguousSeq += 1;
    }
    return advanced ? _watermarkValue : null;
  }
}
