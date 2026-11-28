import '../style/style_chapter_sampler.dart' show SampleChapter;

/// 续写导入末章完结/烂尾风险提示
class EndingWarningHint {
  const EndingWarningHint({
    required this.reason,
    required this.lastChapterTitle,
    required this.suggestedFallbackTitle,
  });

  final String reason;
  final String lastChapterTitle;
  final String suggestedFallbackTitle;
}

/// 网文原文净化器：
/// 自动剥离番茄/起点/刺猬猫等平台下载 TXT 中的元信息头、分隔线，以及章节末尾的
/// 《完》/作者退场感言/PS/求月票/红包口令等脏文本，防止污染 AI 续写上下文与文风计量。
abstract final class NovelTextCleaner {
  /// 识别章节尾部明显的完结标记或作者退场感言起始行
  static final RegExp _tailEndMarker = RegExp(
    r'^\s*(?:'
    r'[（(【《\[]?\s*(?:全书完|本书完|大结局完|正文完|剧终|完结撒花|完)\s*[。！!~～]*\s*[）)】》\]]?\s*$|'
    r'(?:作者有话说|作者的话|完本感言|切书感言|太监感言|PS[:：]|P\.S\.[:：]|求月票|求推荐票|求追读|求催更|求五星好评|求免费礼物|点点催更|请假条|番外预告|感谢大家的?支持|(?:元旦|春节|新年|中秋|国庆|圣诞|端午|情人节|七夕)快乐|发个?红包|包个?红包|zfb口令|支付宝口令|微信红包|口令红包|[-=＝—_*]{10,})'
    r')\s*',
    caseSensitive: false,
  );

  static final RegExp _endingTitleRe = RegExp(
    r'(?:大结局|终章|尾声|世界的终结|全书完|完结感言|后记|切书)',
  );

  static final RegExp _endingBodyRe = RegExp(
    r'(?:全书完|本书完|完结撒花|太监|切书|给.{0,8}作者带个话|写完再完结)',
  );

  /// 检测小说末章是否疑似完结/强行烂尾，供续写导入向导提前预警与一键回退到倒数第二章。
  static EndingWarningHint? detectEndingWarning(List<SampleChapter> chapters) {
    if (chapters.length < 2) return null;
    final last = chapters.last;
    final prev = chapters[chapters.length - 2];
    final title = last.marker.trim();
    final body = last.body.trim();
    final tail = body.length > 600 ? body.substring(body.length - 600) : body;

    if (_endingTitleRe.hasMatch(title)) {
      return EndingWarningHint(
        reason: '末章标题「$title」疑似结局/完结章，若属强行烂尾建议改从前一章切入续写。',
        lastChapterTitle: title,
        suggestedFallbackTitle: prev.marker.trim(),
      );
    }
    if (_endingBodyRe.hasMatch(tail)) {
      return EndingWarningHint(
        reason: '末章正文末尾出现完结/元叙述特征，若属强行烂尾建议改从前一章切入续写。',
        lastChapterTitle: title,
        suggestedFallbackTitle: prev.marker.trim(),
      );
    }
    return null;
  }

  /// 识别开篇常见的下载器元信息行（如 `book_id=...`、`在读：...`、`评分：...`）
  static final RegExp _metaLine = RegExp(
    r'^\s*(?:book_id\s*=|状态[:：]|评分[:：]|字数[:：]|章节[:：]|分类[:：]|标签[:：]|在读[:：]|下载来源[:：]|TXT下载|={8,}|-{8,})',
    caseSensitive: false,
  );

  /// 清洗单章正文：仅在章节尾部最后 30%（且不超过末 1200 字）扫描完结感言与作者 PS，
  /// 避免误伤正文对话里的“完了”“PS”等正常文本。
  static String cleanChapterBody(String body) {
    if (body.trim().isEmpty) return '';
    final lines = body.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return '';

    // 扫描末尾 40% 或最后 20 行（取较早位置，至少保留首行正文），防止长退场感言超过 30% 行数导致漏删
    final byRatio = (lines.length * 0.6).floor();
    final byTailLines = (lines.length - 20).clamp(1, lines.length);
    final scanStart = (byRatio < byTailLines ? byRatio : byTailLines).clamp(
      1,
      lines.length,
    );
    var cutIndex = lines.length;
    for (var i = scanStart; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (_tailEndMarker.hasMatch(line)) {
        // 验证：若命中纯分隔线，则必须位于正文最后 3 行且在后 70% 区间内才裁切，防止误伤章节内场景分隔线
        final isDividerOnly = RegExp(r'^[-=＝—_*]{10,}$').hasMatch(line);
        if (!isDividerOnly ||
            (i >= lines.length - 3 && i >= (lines.length * 0.7).floor())) {
          cutIndex = i;
          break;
        }
      }
    }

    var kept = lines.sublist(0, cutIndex);

    // 裁掉尾部的纯省略号/空行/颜文字（常紧跟在《完》之前的过渡尾行）
    while (kept.isNotEmpty) {
      final t = kept.last.trim();
      if (t.isEmpty ||
          RegExp(r'^[…\.。·\-=—_\s]+$').hasMatch(t) ||
          RegExp(r'^[\(（][^一-龥]{1,12}[\)）]$').hasMatch(t)) {
        kept = kept.sublist(0, kept.length - 1);
      } else {
        break;
      }
    }
    return kept.join('\n').trim();
  }

  /// 提取并清洗全文开篇元信息中的简介（可用于补充建档，不混入第一章正文）
  static String? extractHeaderSynopsis(String rawText) {
    final head = rawText.length > 2000 ? rawText.substring(0, 2000) : rawText;
    final match = RegExp(
      r'简介[:：]\s*([\s\S]+?)(?:\r?\n\s*={6,}|\r?\n\s*第[零一二三四五六七八九十百千万0-9]+[章回节])',
    ).firstMatch(head);
    final s = match?.group(1)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// 判断开篇前言块是否为网文下载器元信息（如番茄/起点的书名+作者+简介+分隔线），避免混入第一章正文
  static bool looksLikeHeaderMetadata(String preamble) {
    final p = preamble.trim();
    if (p.isEmpty) return false;
    final hasMeta =
        p.contains('书名：') ||
        p.contains('book_id=') ||
        p.contains('简介：') ||
        RegExp(r'={8,}').hasMatch(p);
    return hasMeta;
  }

  /// 清理无章节标记文本的头部元信息行
  static String stripLeadingMetadata(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    var start = 0;
    while (start < lines.length && start < 20) {
      final t = lines[start].trim();
      if (t.isEmpty || _metaLine.hasMatch(t)) {
        start++;
      } else {
        break;
      }
    }
    return lines.sublist(start).join('\n').trim();
  }
}
