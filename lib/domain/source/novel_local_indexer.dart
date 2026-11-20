import 'dart:convert';
import 'dart:math' as math;

import '../models/style_models.dart';
import '../style/style_chapter_sampler.dart';
import '../style/style_metrics.dart';
import 'novel_text_cleaner.dart';

class IndexedChapter {
  const IndexedChapter({
    required this.chapterNo,
    required this.title,
    required this.body,
  });

  /// 1-based 章序
  final int chapterNo;
  final String title;
  final String body;
}

class EntityStat {
  const EntityStat({
    required this.name,
    required this.mentions,
    required this.chapterCount,
    required this.firstChapter,
    required this.lastChapter,
    required this.recentChapterHits,
    this.voiceSamples = const [],
  });

  final String name;
  final int mentions;
  final int chapterCount;
  final int firstChapter;
  final int lastChapter;
  final int recentChapterHits;
  final List<String> voiceSamples;

  Map<String, dynamic> toCompactJson() => {
    'name': name,
    'mentions': mentions,
    'chapters': chapterCount,
    'span': '$firstChapter-$lastChapter',
    'recentHits': recentChapterHits,
  };
}

class GrepEvidence {
  const GrepEvidence({
    required this.chapterNo,
    required this.chapterTitle,
    required this.snippet,
  });

  final int chapterNo;
  final String chapterTitle;
  final String snippet;

  String format() => '[第$chapterNo章 $chapterTitle] …$snippet…';
}

/// 零 Token 本地小说检索引擎（几十毫秒完成全书清洗、实体自动发现、共现关系、声音样本库与按需 grep）。
/// 专为「证据驱动建档」与「写作助手按需查书（zm-search）」设计，彻底替代盲目全书逐章 Map-Reduce。
class NovelLocalIndexer {
  NovelLocalIndexer._({
    required this.chapters,
    required this.headerSynopsis,
    required this.topEntities,
    required this.cooccurrence,
    required this.recentMetrics,
  });

  final List<IndexedChapter> chapters;
  final String? headerSynopsis;
  final List<EntityStat> topEntities;
  final Map<String, Map<String, int>> cooccurrence;
  final StyleMetricsSnapshot recentMetrics;

  /// 中文说话/动作主语识别（精准抓 2-3 字中文人名与音译 2-4 字角色名）
  static final RegExp _speakerPattern = RegExp(
    r'(?:^|[\n\r，。！？…\s　“”"「」])([一-龥]{2,4})(?=(?:说道|问道|笑道|冷笑道|淡笑道|苦笑道|轻笑道|嘀咕道|喊道|骂道|喝道|叹了口气|叹气|皱眉|皱了皱眉|咬牙|咬了咬牙|愣了愣|微微一愣|摇了摇头|点了点头|开口|低声|望着|看着|看向|转身|伸手|翻了个白眼|翻了翻白眼|哼了一声|嗤笑|沉默))',
  );

  /// 常见非人名高频停用词（过滤代词、副词、泛称与常见动作词）
  static const Set<String> _stopWords = {
    '我们', '你们', '他们', '她们', '它们', '自己', '大家', '众人', '人们', '人类',
    '这个', '那个', '这些', '那些', '什么', '怎么', '为什么', '哪里', '这里', '那里',
    '时候', '时间', '突然', '立刻', '马上', '缓缓', '慢慢', '轻轻', '微微', '直接',
    '已经', '正在', '还是', '或者', '但是', '不过', '虽然', '因为', '所以', '如果',
    '居然', '竟然', '似乎', '仿佛', '好像', '其实', '当然', '确实', '果然', '只是',
    '不是', '没有', '知道', '明白', '觉得', '感觉', '发现', '看见', '听到', '听见',
    '此时', '此刻', '这时', '现在', '刚才', '之前', '之后', '以后', '以前', '今天',
    '明天', '昨天', '一旁', '旁边', '周围', '四周', '面前', '眼前', '身后', '远处',
    '天空', '空中', '地面', '地上', '房间', '屋内', '门外', '里面', '外面', '地方',
    '东西', '事情', '问题', '办法', '声音', '低语', '身影', '目光', '眼神', '脸色',
    '表情', '心里', '心中', '内心', '脑海', '脑袋', '身体', '双手', '左手', '右手',
    '女孩', '小女孩', '男孩', '青年', '少年', '少女', '男人', '女人', '老头', '大妈',
    '家伙', '怪物', '孩子', '小孩', '一人', '两人', '三人', '几人', '所有', '一切',
    '一样', '一般', '一下', '一边', '一面', '一步', '一声', '口气', '口水', '冷汗',
    '瞳孔', '眼睛', '嘴角', '眉头', '手掌', '手指', '对方', '别人', '他人', '有人',
    '无人', '所有人', '那人', '此人', '听着', '望着', '看着', '说着', '笑着', '想着',
    '见状', '闻言', '顿时', '随即', '随后', '接着', '然后', '于是', '只见', '不知',
    '不能', '不会', '不敢', '不想', '不要', '不用', '不行', '不对', '不好', '没事',
    '算了', '好了', '行吧', '好吧', '如此', '这样', '那样', '这么', '那么', '多么',
    '非常', '十分', '极其', '有点', '有些', '一点', '一些', '很多', '不少', '完全',
    '根本', '简直', '几乎', '原来', '难怪', '难道', '恐怕', '大概', '或许', '也许',
    '肯定', '一定', '必须', '应该', '可以', '能够', '需要', '想要', '准备', '开始',
    '继续', '停止', '结束', '回到', '来到', '走到', '跑到', '飞到', '落在', '站在',
    '坐在', '躺在', '跪在', '一个', '两个', '三个', '几个', '每个', '整个', '半个',
    '一只', '两只', '一群', '一阵', '一道', '一片', '一股', '一团', '一抹', '一丝',
    '忽然', '瞬间', '刹那', '猛然', '蓦然', '连忙', '赶紧', '急忙',
    '狼人', '灾祸', '守夜', '城主', '大人', '老板', '大叔', '大爷', '阿姨', '姑娘',
  };

  /// 从原始全文构建本地索引（零外部依赖，适合在 Isolate.run 中运行）
  factory NovelLocalIndexer.fromRawText(String rawText) {
    final headerSynopsis = NovelTextCleaner.extractHeaderSynopsis(rawText);
    final rawChapters = StyleChapterSampler.split(rawText);
    final chapters = <IndexedChapter>[];

    if (rawChapters.isEmpty) {
      final cleaned = NovelTextCleaner.cleanChapterBody(
        NovelTextCleaner.stripLeadingMetadata(rawText),
      );
      if (cleaned.isNotEmpty) {
        chapters.add(
          IndexedChapter(chapterNo: 1, title: '全文', body: cleaned),
        );
      }
    } else {
      for (var i = 0; i < rawChapters.length; i++) {
        final cleaned = NovelTextCleaner.cleanChapterBody(rawChapters[i].body);
        if (cleaned.isEmpty) continue;
        chapters.add(
          IndexedChapter(
            chapterNo: chapters.length + 1,
            title: rawChapters[i].marker.trim(),
            body: cleaned,
          ),
        );
      }
    }

    return NovelLocalIndexer.fromChapters(
      chapters,
      headerSynopsis: headerSynopsis,
    );
  }

  /// 从已有章节列表（如作品库内章节）构建索引
  factory NovelLocalIndexer.fromChapters(
    List<IndexedChapter> chapters, {
    String? headerSynopsis,
  }) {
    if (chapters.isEmpty) {
      return NovelLocalIndexer._(
        chapters: const [],
        headerSynopsis: headerSynopsis,
        topEntities: const [],
        cooccurrence: const {},
        recentMetrics: const StyleMetricsSnapshot(),
      );
    }

    // 1. 候选实体自动发现：按说话/动作主语打分
    final speakerHits = <String, int>{};
    for (final ch in chapters) {
      for (final m in _speakerPattern.allMatches(ch.body)) {
        final raw = m.group(1)!;
        final candidate = _trimLeadingParticle(raw);
        if (candidate.length < 2 || candidate.length > 4) continue;
        if (_stopWords.contains(candidate)) continue;
        if (_hasBadPrefixOrSuffix(candidate)) continue;
        speakerHits[candidate] = (speakerHits[candidate] ?? 0) + 1;
      }
    }

    // 取候选 Top 45，再在全书做精确出现统计（过滤掉出现次数太少的偶发词）
    final candidates = speakerHits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCandidates = candidates
        .where((e) => e.value >= (chapters.length >= 20 ? 3 : 1))
        .take(45)
        .map((e) => e.key)
        .toList();

    // 2. 精确统计每个候选实体的总提及、跨章数、首尾章与近期活跃度
    final recentStart = math.max(1, chapters.length - 14);
    final chapterEntitySets = <int, Set<String>>{};
    final stats = <EntityStat>[];

    for (final name in topCandidates) {
      var total = 0;
      var chCount = 0;
      var firstCh = 0;
      var lastCh = 0;
      var recentHits = 0;
      final re = RegExp(RegExp.escape(name));

      for (final ch in chapters) {
        final c = re.allMatches(ch.body).length;
        if (c > 0) {
          total += c;
          chCount += 1;
          if (firstCh == 0) firstCh = ch.chapterNo;
          lastCh = ch.chapterNo;
          if (ch.chapterNo >= recentStart) recentHits += 1;
          (chapterEntitySets[ch.chapterNo] ??= <String>{}).add(name);
        }
      }

      if (total >= 2) {
        stats.add(
          EntityStat(
            name: name,
            mentions: total,
            chapterCount: chCount,
            firstChapter: firstCh,
            lastChapter: lastCh,
            recentChapterHits: recentHits,
            voiceSamples: _extractVoiceSamples(chapters, name, maxSamples: 3),
          ),
        );
      }
    }

    // 综合排序：兼顾总频次与近期活跃度
    stats.sort((a, b) {
      final scoreA = a.mentions + a.recentChapterHits * 15;
      final scoreB = b.mentions + b.recentChapterHits * 15;
      return scoreB.compareTo(scoreA);
    });
    final topEntities = stats.take(20).toList();

    // 3. Top 10 实体同章共现矩阵
    final coNames = topEntities.take(10).map((e) => e.name).toList();
    final cooccurrence = <String, Map<String, int>>{};
    for (final a in coNames) {
      final edges = <String, int>{};
      for (final b in coNames) {
        if (a == b) continue;
        var count = 0;
        for (final set in chapterEntitySets.values) {
          if (set.contains(a) && set.contains(b)) count++;
        }
        if (count > 0) edges[b] = count;
      }
      if (edges.isNotEmpty) cooccurrence[a] = edges;
    }

    // 4. 近期 5 章的真实文风计量基线（解决全书前期与后期文风漂移问题）
    final recentSlice = chapters
        .sublist(math.max(0, chapters.length - 5))
        .map((c) => c.body)
        .join('\n\n');
    final recentMetrics = StyleMetrics.compute(recentSlice);

    return NovelLocalIndexer._(
      chapters: chapters,
      headerSynopsis: headerSynopsis,
      topEntities: topEntities,
      cooccurrence: cooccurrence,
      recentMetrics: recentMetrics,
    );
  }

  /// 在全书内按关键词检索带章号和前后上下文的原文证据（支持精准短语 + 空格分词多词打分 + 章号过滤）
  List<GrepEvidence> grep(
    String keyword, {
    int maxHits = 3,
    bool fromEnd = true,
    int radiusBefore = 220,
    int radiusAfter = 280,
  }) {
    final kw = keyword.trim();
    if (kw.isEmpty || chapters.isEmpty) return const [];

    // 1) 优先精确子串命中
    final exactHits = <GrepEvidence>[];
    final ordered = fromEnd ? chapters.reversed : chapters;
    for (final ch in ordered) {
      final pos = ch.body.indexOf(kw);
      if (pos == -1) continue;
      exactHits.add(_makeEvidence(ch, pos, kw.length, radiusBefore, radiusAfter));
      if (exactHits.length >= maxHits) return exactHits;
    }
    if (exactHits.isNotEmpty) return exactHits;

    // 2) 多词/空格分隔查询智能回退（如 "爱丽丝 第1章 发色 衣服" / "罗娜 最后 形态"）
    final rawTokens = kw
        .split(RegExp(r'[\s,，、/|+]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (rawTokens.length <= 1) return const [];

    // 提取可选章号提示（如 "第1章" / "第250章"）
    int? targetChapterNo;
    final searchTokens = <String>[];
    for (final t in rawTokens) {
      final chNum = StyleChapterSampler.markerNumber(t);
      if (chNum != null) {
        targetChapterNo = chNum;
      } else if (t.length >= 2) {
        searchTokens.add(t);
      }
    }
    if (searchTokens.isEmpty) return const [];

    // 按命中词数量 + 锚点词稀有度打分（过滤出至少命中一个词的章节）
    final scored = <({IndexedChapter ch, int score, int anchorPos, int anchorLen})>[];
    final primaryToken = searchTokens.first;

    for (final ch in chapters) {
      var score = 0;
      var anchorPos = -1;
      var anchorLen = 0;

      if (targetChapterNo != null && ch.chapterNo == targetChapterNo) {
        score += 4;
      }
      for (var i = 0; i < searchTokens.length; i++) {
        final t = searchTokens[i];
        final p = ch.body.indexOf(t);
        if (p != -1) {
          // 首词（通常是人名/核心实体）权重最高
          score += (i == 0) ? 5 : 2;
          if (anchorPos == -1 || t == primaryToken) {
            anchorPos = p;
            anchorLen = t.length;
          }
        }
      }
      if (anchorPos != -1 && score >= 4) {
        scored.add((ch: ch, score: score, anchorPos: anchorPos, anchorLen: anchorLen));
      }
    }

    if (scored.isEmpty) return const [];
    scored.sort((a, b) {
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return fromEnd
          ? b.ch.chapterNo.compareTo(a.ch.chapterNo)
          : a.ch.chapterNo.compareTo(b.ch.chapterNo);
    });

    return scored
        .take(maxHits)
        .map(
          (e) => _makeEvidence(
            e.ch,
            e.anchorPos,
            e.anchorLen,
            radiusBefore,
            radiusAfter,
          ),
        )
        .toList();
  }

  static GrepEvidence _makeEvidence(
    IndexedChapter ch,
    int pos,
    int matchLen,
    int radiusBefore,
    int radiusAfter,
  ) {
    final start = (pos - radiusBefore).clamp(0, ch.body.length);
    final end = (pos + matchLen + radiusAfter).clamp(0, ch.body.length);
    final snippet = ch.body
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return GrepEvidence(
      chapterNo: ch.chapterNo,
      chapterTitle: ch.title,
      snippet: snippet,
    );
  }

  /// 首现 + 末现混合检索：既拿到设定起源，又拿到最新状态（最适合考证伏笔与角色演变）
  List<GrepEvidence> grepSpan(
    String keyword, {
    int earliestHits = 1,
    int latestHits = 2,
  }) {
    final first = grep(keyword, maxHits: earliestHits, fromEnd: false);
    final last = grep(keyword, maxHits: latestHits, fromEnd: true);
    final seen = <int>{};
    final merged = <GrepEvidence>[];
    for (final item in [...first, ...last]) {
      if (seen.add(item.chapterNo)) merged.add(item);
    }
    merged.sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
    return merged;
  }

  /// 构建「KV 前缀缓存友好」的静态证据前缀（供 Round 1 与 Round 2 字节级复用，实现 80%+ 缓存命中）
  String buildEvidenceStaticPrefix({
    required String title,
    required bool isContinuation,
    int tailChapterCount = 4,
    int openingChapterCount = 2,
    int maxTailChars = 11000,
    int maxOpeningChars = 4200,
  }) {
    final buf = StringBuffer()
      ..writeln('你是《$title》的专业长篇小说档案与续写架构师。')
      ..writeln(
        '以下是本地零耗时检索引擎对全书 ${chapters.length} 章做自动清洗、实体统计、共现分析后的真实原文基线（禁止违背原文事实或臆造核心设定）：',
      );

    if (headerSynopsis != null && headerSynopsis!.isNotEmpty) {
      final syn = headerSynopsis!.length > 600
          ? '${headerSynopsis!.substring(0, 600)}…'
          : headerSynopsis!;
      buf
        ..writeln('\n【原书简介】')
        ..writeln(syn);
    }

    if (topEntities.isNotEmpty) {
      buf
        ..writeln('\n【全书高频角色/实体出场热力图（总提及 / 跨章数 / 首尾章 / 近15章活跃）】')
        ..writeln(
          jsonEncode(topEntities.map((e) => e.toCompactJson()).toList()),
        );
    }

    if (cooccurrence.isNotEmpty) {
      buf
        ..writeln('\n【核心实体同章共现关系】')
        ..writeln(jsonEncode(cooccurrence));
    }

    final voices = topEntities
        .where((e) => e.voiceSamples.isNotEmpty)
        .take(8)
        .toList();
    if (voices.isNotEmpty) {
      buf.writeln('\n【核心角色原话声音样本（防 OOC 口癖锚点）】');
      for (final v in voices) {
        buf.writeln('- ${v.name}：${v.voiceSamples.join(' / ')}');
      }
    }

    // 近期目录（帮助感知当前剧情大弧）
    final tocStart = math.max(0, chapters.length - 25);
    buf.writeln('\n【近期章节目录（第${tocStart + 1}-${chapters.length}章）】');
    for (var i = tocStart; i < chapters.length; i++) {
      buf.writeln('${chapters[i].chapterNo}. ${chapters[i].title}');
    }

    // 开篇定调章（捕捉开局核心伏笔/金手指/宿敌）
    if (chapters.isNotEmpty) {
      buf.writeln('\n【开篇原文节选（捕捉开局核心设定与宿命伏笔）】');
      var used = 0;
      for (final ch in chapters.take(openingChapterCount)) {
        final piece = '〔第${ch.chapterNo}章 ${ch.title}〕\n${ch.body}';
        if (used + piece.length > maxOpeningChars) {
          final remain = maxOpeningChars - used;
          if (remain > 300) {
            buf.writeln('${piece.substring(0, remain)}…');
          }
          break;
        }
        buf.writeln(piece);
        used += piece.length;
      }
    }

    // 末尾完整章（已自动剥离《完》与作者感言，作为续写/收尾状态的直接锚点）
    if (chapters.length > openingChapterCount) {
      final tailStart = math.max(
        openingChapterCount,
        chapters.length - tailChapterCount,
      );
      final tailList = chapters.sublist(tailStart);
      final tailCombined = tailList
          .map((c) => '〔第${c.chapterNo}章 ${c.title}〕\n${c.body}')
          .join('\n\n');
      final trimmedTail = tailCombined.length <= maxTailChars
          ? tailCombined
          : tailCombined.substring(tailCombined.length - maxTailChars);
      buf
        ..writeln(
          isContinuation
              ? '\n【截断处最后 ${tailList.length} 章完整正文（已剔除完结感言，作为现状与文风直接锚点）】'
              : '\n【近期最后 ${tailList.length} 章完整正文】',
        )
        ..writeln(trimmedTail);
    }

    return buf.toString();
  }

  /// 提取某角色邻近的真实原话（Voice Bank）
  static List<String> _extractVoiceSamples(
    List<IndexedChapter> chapters,
    String name, {
    int maxSamples = 3,
  }) {
    final samples = <String>[];
    final seen = <String>{};
    final re = RegExp(
      '${RegExp.escape(name)}[^\\n“”]{0,16}[：:，,。\\s]*“([^”]{6,42})”',
    );
    // 从后往前取近期样本，更贴合当前性格
    for (final ch in chapters.reversed) {
      for (final m in re.allMatches(ch.body)) {
        final quote = '“${m.group(1)!.trim()}”';
        if (seen.add(quote)) {
          samples.add(quote);
          if (samples.length >= maxSamples) return samples;
        }
      }
    }
    return samples;
  }

  static String _trimLeadingParticle(String raw) {
    var s = raw;
    const leadTrim = ['对', '向', '把', '被', '让', '给', '和', '与', '跟', '在', '是', '见', '看', '望', '而', '但', '却', '连', '连同', '只见'];
    for (final p in leadTrim) {
      if (s.startsWith(p) && s.length - p.length >= 2) {
        s = s.substring(p.length);
      }
    }
    return s;
  }

  static bool _hasBadPrefixOrSuffix(String s) {
    const badChars = '的地得了着过是不有在和与把被让给对向从到要会能可很太最都也又再就才还真好坏大小多少上下左右前后里外高低长短';
    if (badChars.contains(s[0]) || badChars.contains(s[s.length - 1])) {
      return true;
    }
    return false;
  }
}
