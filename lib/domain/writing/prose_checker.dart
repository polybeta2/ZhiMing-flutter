import 'dart:math' as math;

/// 本地文风快检：纯文本统计，零 LLM 成本，为「去 AI 味」与风格体检提供客观线索。
class ProseIssue {
  const ProseIssue({required this.rule, required this.detail});

  final String rule;
  final String detail;
}

abstract final class ProseChecker {
  static const List<({String phrase, String advice})> _clichePhrases = [
    (phrase: '瞳孔', advice: '换成可观察的具体反应'),
    (phrase: '倒吸一口凉气', advice: '改为动作或沉默'),
    (phrase: '倒吸凉气', advice: '改为动作或沉默'),
    (phrase: '勾起一抹', advice: '删掉程式化笑意描写'),
    (phrase: '嘴角勾起', advice: '换具体笑法或省略'),
    (phrase: '眼中闪过', advice: '改为可见行为'),
    (phrase: '眼底闪过', advice: '改为可见行为'),
    (phrase: '心中涌起', advice: '情绪外化为动作'),
    (phrase: '一股暖流', advice: '改为具体身体感受'),
    (phrase: '喉结滚动', advice: '减少特写式套件'),
    (phrase: '指尖微颤', advice: '减少特写式套件'),
    (phrase: '深吸一口气', advice: '同段多次才需要替换'),
  ];

  static const List<String> _transitionPhrases = [
    '与此同时',
    '刹那间',
    '霎时间',
    '瞬间，',
    '总而言之',
    '值得一提的是',
  ];

  static const List<String> _abstractSlopPhrases = [
    '某种难以言喻',
    '难以言喻的',
    '一丝不易察觉',
    '一抹不易察觉',
    '不易察觉的',
    '不容置疑的意味',
    '空气仿佛凝固',
    '空气瞬间凝固',
  ];

  static const List<String> _tidyEndingPhrases = [
    '命运的齿轮',
    '真正的考验',
    '一切才刚刚开始',
    '才刚刚开始',
    '属于他的传奇',
    '属于她的传奇',
  ];

  static final RegExp _duijuRe = RegExp(r'不是[^。！？\n]{1,16}[，,]?而是');
  static final RegExp _progressiveSlopRe = RegExp(
    r'(不仅|不只|不仅仅)[^。！？\n]{1,18}[，,]?(而且|更是|还是)',
  );
  static final RegExp _simileRe = RegExp(r'仿佛|犹如|宛如|好似');
  static final RegExp _causationRe = RegExp(
    r'[让令使][人他她它][^。！？\n]{0,6}(感到|不禁|生出|产生)',
  );
  static final RegExp _cognitionRe = RegExp(r'意识到|心中一凛|内心深处|心里清楚');
  static final RegExp _stoneRippleRe = RegExp(
    r'像(一颗|一块|一粒)?小?石子[^。！？\n]{0,14}(投入|落入|砸进|丢进)[^。！？\n]{0,14}(涟漪|波澜)',
  );
  static final RegExp _emotionTagTailRe = RegExp(
    r'(语气|声音|话语|语调)(中|里)?(带着|透着|夹杂着|藏着)(一丝|一抹|几分)|不容置疑的(意味|语气|口吻)',
  );
  static final RegExp _leRe = RegExp('了');

  static List<String> reportLines(String text, {int maxLines = 8}) {
    return check(
      text,
    ).take(maxLines).map((i) => '- ${i.rule}：${i.detail}').toList();
  }

  static List<ProseIssue> check(String text) {
    final issues = <ProseIssue>[];
    final trimmed = text.trim();
    if (trimmed.length < 60) return issues;

    final duiju = _duijuRe.allMatches(text).length;
    if (duiju > 0) {
      issues.add(
        ProseIssue(
          rule: '解释性对举句',
          detail: '命中 $duiju 处「不是…而是…」式说明腔，建议改由画面直接呈现',
        ),
      );
    }

    final progressive = _progressiveSlopRe.allMatches(text).length;
    if (progressive > 0) {
      issues.add(
        ProseIssue(
          rule: '递进说明腔',
          detail: '命中 $progressive 处「不仅…而且… / 这不仅仅是…更是…」论文式递进句，建议拆成动作或对白',
        ),
      );
    }

    final abstractHits = [
      for (final p in _abstractSlopPhrases)
        if (text.contains(p)) p,
    ];
    if (abstractHits.isNotEmpty) {
      issues.add(
        ProseIssue(
          rule: '空洞抽象修饰',
          detail: '命中「${abstractHits.take(3).join('、')}」，请改写为具体感官或微动作',
        ),
      );
    }

    final tidyHits = [
      for (final p in _tidyEndingPhrases)
        if (text.contains(p)) p,
    ];
    if (tidyHits.isNotEmpty) {
      issues.add(
        ProseIssue(
          rule: '强行升华套话',
          detail: '命中「${tidyHits.take(3).join('、')}」，避免章末或段末强行上价值',
        ),
      );
    }

    final simile = _simileRe.allMatches(text).length;
    if (simile >= 3) {
      issues.add(
        ProseIssue(
          rule: '比喻滥用',
          detail: '「仿佛/犹如/宛如」出现 $simile 次，保留至多一处必要的',
        ),
      );
    }

    final causation = _causationRe.allMatches(text).length;
    if (causation > 0) {
      issues.add(
        ProseIssue(
          rule: '强加因果',
          detail: '「让/令/使 + 感受」结构 $causation 处，改为角色自身的动作反应',
        ),
      );
    }

    final cognition = _cognitionRe.allMatches(text).length;
    if (cognition >= 2) {
      issues.add(
        ProseIssue(
          rule: '认知直陈',
          detail: '「意识到/心中一凛」类 $cognition 处，用身体反应与环境互动外化',
        ),
      );
    }

    final stoneRipple = _stoneRippleRe.allMatches(text).length;
    if (stoneRipple > 0) {
      issues.add(
        ProseIssue(
          rule: '公式化投石开头',
          detail: '命中 $stoneRipple 处「像石子投入湖面激起涟漪」类陈腐比喻，请换成直接的场景细节或动作起笔',
        ),
      );
    }

    final emotionTail = _emotionTagTailRe.allMatches(text).length;
    if (emotionTail > 0) {
      issues.add(
        ProseIssue(
          rule: '动作后情绪解读尾巴',
          detail: '命中 $emotionTail 处「语气带着一丝…/不容置疑的意味」类情绪直说，若只有一丝或不易察觉就不要替读者说破',
        ),
      );
    }

    final clicheHits = [
      for (final item in _clichePhrases)
        if (text.contains(item.phrase)) item.phrase,
    ];
    if (clicheHits.isNotEmpty) {
      issues.add(
        ProseIssue(
          rule: '模板动作套话',
          detail: '命中 ${clicheHits.take(4).join('、')}等，替换为符合人物的具体小动作',
        ),
      );
    }

    var transitionTotal = 0;
    for (final phrase in _transitionPhrases) {
      transitionTotal += RegExp(RegExp.escape(phrase)).allMatches(text).length;
    }
    if (transitionTotal >= 3) {
      issues.add(
        ProseIssue(
          rule: '过渡套话',
          detail: '「与此同时/刹那间」类出现 $transitionTotal 次，多数可直接删除或换具体时序',
        ),
      );
    }

    final sentences = _splitSentences(text);
    if (sentences.length >= 8) {
      final lengths = sentences.map((s) => s.length).toList();
      final total = lengths.fold(0, (a, b) => a + b);
      final mean = total / lengths.length;
      var sqDiff = 0.0;
      for (final len in lengths) {
        final d = len - mean;
        sqDiff += d * d;
      }
      final cv = mean > 0 ? math.sqrt(sqDiff / lengths.length) / mean : 0.0;
      if (cv < 0.35) {
        issues.add(
          ProseIssue(
            rule: '句长均一',
            detail: '句长变异系数 ${cv.toStringAsFixed(2)}（<0.35 即偏机械），请长短句交替',
          ),
        );
      }
    }

    final leCount = _leRe.allMatches(text).length;
    final density = leCount / math.max(trimmed.length, 1);
    if (density > 0.03) {
      issues.add(
        ProseIssue(
          rule: '「了」密度偏高',
          detail: '占比 ${(density * 100).toStringAsFixed(1)}%，部分可改为完成态描述或直接动词',
        ),
      );
    }

    return issues;
  }

  static List<String> _splitSentences(String text) {
    final result = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buf.write(ch);
      if (ch == '。' || ch == '！' || ch == '？' || ch == '\n') {
        final t = buf.toString().trim();
        if (t.length >= 2) result.add(t);
        buf.clear();
      }
    }
    final tail = buf.toString().trim();
    if (tail.length >= 2) result.add(tail);
    return result;
  }
}
