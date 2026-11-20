import '../../core/database/app_database.dart' as db;
import '../../core/prompts/prompt_limits.dart';
import '../models/novel_domain.dart';

class BuiltContext {
  const BuiltContext({
    required this.rendered,
    required this.truncatedSections,
    this.staticPrefix = '',
    this.dynamicSuffix = '',
  });

  /// 完整拼接上下文（兼容旧调用方）
  final String rendered;
  final List<String> truncatedSections;

  /// KV 前缀缓存友好：全书/单卷级相对静态上下文（适合置于 system 消息，80%+ 缓存命中）
  final String staticPrefix;

  /// 单章/单次动态上下文（细纲、邻章衔接、当前正文末尾，适合置于 user 消息）
  final String dynamicSuffix;
}

sealed class OutlineTarget {
  const OutlineTarget();
}

final class VolumeOutlineTarget extends OutlineTarget {
  const VolumeOutlineTarget(this.volume);
  final VolumeBundle volume;
}

final class ChapterOutlineTarget extends OutlineTarget {
  const ChapterOutlineTarget(this.chapter);
  final ChapterBundle chapter;
}

/// 三级上下文装配器（必需层 / 高优先层 / 可选层 + 章间衔接锚点 + 伏笔提醒 + 预算裁剪上报）
abstract final class ContextBuilder {
  static const int tailLength = 800;
  static const int neighborTailLength = 600;
  static const int nextOutlineHeadLength = 160;
  static const int maxSceneCharacters = 12;
  static const int maxWorldEntries = 8;

  static BuiltContext buildContinueContext({
    required ChapterBundle chapter,
    required NovelBundle bundle,
    required int budgetChars,
    String? styleCard,
    String? sourceWindow,
  }) {
    final staticRequired = <String>[];
    final dynamicRequired = <String>[];
    final staticOptional = <(String, String)>[];
    final dynamicHigh = <(String, String)>[];
    final dynamicOptional = <(String, String)>[];
    final truncated = <String>[];

    final styleGuide = bundle.novel.styleGuide;
    if (styleGuide != null && styleGuide.trim().isNotEmpty) {
      staticRequired.add(
        '【风格约束】\n${_cappedRequired(styleGuide, '风格约束', truncated)}',
      );
    }
    if (styleCard != null && styleCard.isNotEmpty) {
      staticRequired.add(styleCard);
    }
    if (sourceWindow != null && sourceWindow.isNotEmpty) {
      staticRequired.add('【原作该阶段人物与事件】\n$sourceWindow');
    }

    _appendPrevProseTail(chapter, bundle, dynamicRequired);

    final detailedOutline = chapter.chapter.detailedOutline;
    if (detailedOutline != null && detailedOutline.trim().isNotEmpty) {
      dynamicRequired.add(
        '【本章细纲】\n${_cappedRequired(detailedOutline, '本章细纲', truncated)}',
      );
    }
    final cards = chapter.sceneCards;
    if (cards.isNotEmpty) {
      dynamicRequired.add(
        '【场景卡】\n${_cappedRequired(renderSceneCards(cards), '场景卡', truncated)}',
      );
    }
    _appendNextOutlineHead(chapter, bundle, dynamicRequired);

    final positions = bundle.globalIndexMap();
    final currentGlobal = positions[chapter.chapter.id] ?? 0;

    final prevSums = _summariesBefore(currentGlobal, bundle, positions, limit: 3);
    if (prevSums.isNotEmpty) {
      final text = prevSums.map((e) => '第${e.$1}章：${e.$2}').join('\n');
      dynamicHigh.add(('前文摘要', '【前文摘要（最近 ${prevSums.length} 章）】\n$text'));
    }

    final facts = _keyFactsBefore(currentGlobal, bundle, positions, limit: 3);
    if (facts.isNotEmpty) {
      dynamicHigh.add(('关键事实', '【关键事实】\n${facts.map((f) => '- $f').join('\n')}'));
    }

    final sceneChars = bundle.characters
        .where((c) => c.isSceneRelevant)
        .take(maxSceneCharacters)
        .map(_renderCharacter)
        .toList();
    if (sceneChars.isNotEmpty) {
      staticOptional.add(('角色状态', '【角色当前状态】\n${sceneChars.join('\n\n')}'));
    }

    final world = bundle.worldEntries
        .take(maxWorldEntries)
        .map((w) => '- [${w.category}] ${w.name}：${w.content}')
        .toList();
    if (world.isNotEmpty) {
      staticOptional.add(('世界观', '【世界观条目】\n${world.join('\n')}'));
    }

    final volIdx = _volumeIndexOf(bundle, chapter.volumeId);
    final reminders = renderForeshadowReminders(
      bundle: bundle,
      currentVolumeIndex: volIdx,
      currentChapterOrder: chapter.chapter.sortOrder,
    );
    if (reminders != null) {
      dynamicOptional.add(('未回收伏笔', reminders));
    }

    var used = [...staticRequired, ...dynamicRequired].join('\n\n').length;
    final acceptedStatic = <String>[];
    final acceptedDynamic = <String>[];
    for (final (name, text) in dynamicHigh) {
      if (used + text.length <= budgetChars) {
        acceptedDynamic.add(text);
        used += text.length;
      } else {
        truncated.add(name);
      }
    }
    for (final (name, text) in staticOptional) {
      if (used + text.length <= budgetChars) {
        acceptedStatic.add(text);
        used += text.length;
      } else {
        truncated.add(name);
      }
    }
    for (final (name, text) in dynamicOptional) {
      if (used + text.length <= budgetChars) {
        acceptedDynamic.add(text);
        used += text.length;
      } else {
        truncated.add(name);
      }
    }

    var tail = chapter.chapter.content;
    if (tail.length > tailLength) {
      tail = tail.substring(tail.length - tailLength);
    }
    final tailBlock =
        '【正文末尾】\n${tail.isEmpty ? '（本章尚无正文，请从开头写起）' : tail}';

    final staticParts = [...staticRequired, ...acceptedStatic];
    final dynamicParts = [...dynamicRequired, ...acceptedDynamic, tailBlock];
    final staticPrefix = staticParts.join('\n\n');
    final dynamicSuffix = dynamicParts.join('\n\n');
    final rendered = [
      if (staticPrefix.isNotEmpty) staticPrefix,
      dynamicSuffix,
    ].join('\n\n');

    return BuiltContext(
      rendered: rendered,
      truncatedSections: truncated,
      staticPrefix: staticPrefix,
      dynamicSuffix: dynamicSuffix,
    );
  }

  static BuiltContext buildOutlineContext({
    required OutlineTarget target,
    required NovelBundle bundle,
    required int budgetChars,
    String? styleCard,
  }) {
    final required = <String>[];
    final high = <(String, String)>[];
    final optional = <(String, String)>[];
    final truncated = <String>[];

    final positions = bundle.globalIndexMap();
    final int anchorIndex;
    final String? excludingChapterId;
    switch (target) {
      case VolumeOutlineTarget(:final volume):
        final indices = volume.chapters
            .map((c) => positions[c.chapter.id] ?? 0)
            .where((i) => i > 0)
            .toList();
        anchorIndex = indices.isEmpty
            ? bundle.allChaptersInOrder.length + 1
            : indices.reduce((a, b) => a < b ? a : b);
        excludingChapterId = null;
      case ChapterOutlineTarget(:final chapter):
        anchorIndex = positions[chapter.chapter.id] ?? 0;
        excludingChapterId = chapter.chapter.id;
    }

    if (bundle.novel.synopsis.trim().isNotEmpty) {
      required.add(
        '【作品梗概】\n${_cappedRequired(bundle.novel.synopsis, '作品梗概', truncated)}',
      );
    }
    final styleGuide = bundle.novel.styleGuide;
    if (styleGuide != null && styleGuide.trim().isNotEmpty) {
      required.add(
        '【风格约束】\n${_cappedRequired(styleGuide, '风格约束', truncated)}',
      );
    }
    if (styleCard != null && styleCard.isNotEmpty) {
      required.add(styleCard);
    }

    final prevSums = _summariesBefore(anchorIndex, bundle, positions, limit: 3);
    if (prevSums.isNotEmpty) {
      high.add((
        '前文摘要',
        '【前文摘要（最近 ${prevSums.length} 章）】\n${prevSums.map((e) => '第${e.$1}章：${e.$2}').join('\n')}',
      ));
    }
    final facts = _keyFactsBefore(anchorIndex, bundle, positions, limit: 3);
    if (facts.isNotEmpty) {
      high.add(('关键事实', '【关键事实】\n${facts.map((f) => '- $f').join('\n')}'));
    }
    final prose = _recentProseTail(
      bundle,
      excludingId: excludingChapterId,
      limit: 600,
    );
    if (prose != null) {
      high.add(('最近正文节选', '【最近正文节选】\n$prose'));
    }

    switch (target) {
      case VolumeOutlineTarget(:final volume):
        required.add(_volumeBrief(volume, truncated));
        optional.add(('全书结构', '【全书结构】\n${_structureText(bundle, highlightId: volume.volume.id)}'));
      case ChapterOutlineTarget(:final chapter):
        required.addAll(_chapterBrief(chapter, bundle, truncated));
        final sceneChars = bundle.characters
            .where((c) => c.isSceneRelevant)
            .take(maxSceneCharacters)
            .map(_renderCharacter)
            .toList();
        if (sceneChars.isNotEmpty) {
          optional.add(('角色状态', '【角色当前状态】\n${sceneChars.join('\n\n')}'));
        }
    }

    var used = required.join('\n\n').length;
    final accepted = <String>[];
    for (final (name, text) in [...high, ...optional]) {
      if (used + text.length <= budgetChars) {
        accepted.add(text);
        used += text.length;
      } else {
        truncated.add(name);
      }
    }
    return BuiltContext(
      rendered: [...required, ...accepted].join('\n\n'),
      truncatedSections: truncated,
    );
  }

  static BuiltContext buildAssistantContext({
    required NovelBundle bundle,
    required int budgetChars,
  }) {
    final high = <(String, String)>[];
    final optional = <(String, String)>[];
    final positions = bundle.globalIndexMap();
    final anchorIndex = bundle.allChaptersInOrder.length + 1;

    final prevSums = _summariesBefore(anchorIndex, bundle, positions, limit: 3);
    if (prevSums.isNotEmpty) {
      high.add((
        '前文摘要',
        '【前文摘要（最近 ${prevSums.length} 章）】\n${prevSums.map((e) => '第${e.$1}章：${e.$2}').join('\n')}',
      ));
    }
    final facts = _keyFactsBefore(anchorIndex, bundle, positions, limit: 3);
    if (facts.isNotEmpty) {
      high.add(('关键事实', '【关键事实】\n${facts.map((f) => '- $f').join('\n')}'));
    }
    final prose = _recentProseTail(bundle, limit: 600);
    if (prose != null) {
      high.add(('最近正文节选', '【最近正文节选】\n$prose'));
    }

    final sceneChars = bundle.characters
        .where((c) => c.isSceneRelevant)
        .take(maxSceneCharacters)
        .map(_renderCharacter)
        .toList();
    if (sceneChars.isNotEmpty) {
      optional.add(('角色状态', '【角色当前状态】\n${sceneChars.join('\n\n')}'));
    }
    final world = bundle.worldEntries
        .take(maxWorldEntries)
        .map((w) => '- [${w.category}] ${w.name}：${w.content}')
        .toList();
    if (world.isNotEmpty) {
      optional.add(('世界观', '【世界观条目】\n${world.join('\n')}'));
    }
    if (bundle.volumes.isNotEmpty) {
      optional.add(('全书结构', '【全书结构】\n${_structureText(bundle)}'));
    }

    final truncated = <String>[];
    var used = 0;
    final accepted = <String>[];
    for (final (name, text) in [...high, ...optional]) {
      if (used + text.length <= budgetChars) {
        accepted.add(text);
        used += text.length;
      } else {
        truncated.add(name);
      }
    }
    return BuiltContext(
      rendered: accepted.join('\n\n'),
      truncatedSections: truncated,
    );
  }

  static String renderSceneCards(List<SceneCard> cards) {
    final lines = <String>[];
    for (var i = 0; i < cards.length; i++) {
      final c = cards[i];
      final parts = <String>[];
      if (c.goal.isNotEmpty) parts.add('目标：${c.goal}');
      if (c.obstacle.isNotEmpty) parts.add('阻力：${c.obstacle}');
      if (c.hook.isNotEmpty) parts.add('钩子：${c.hook}');
      lines.add('卡${i + 1}：${parts.isEmpty ? '（空）' : parts.join('；')}');
    }
    return lines.join('\n');
  }

  static String? renderForeshadowReminders({
    required NovelBundle bundle,
    int? currentVolumeIndex,
    int? currentChapterOrder,
  }) {
    const threshold = PromptLimits.foreshadowReminderChapterThreshold;
    final positions = bundle.globalIndexMap();
    final placementGlobal = <int, int>{};
    for (var v = 0; v < bundle.volumes.length; v++) {
      for (final c in bundle.volumes[v].chapters) {
        placementGlobal[(v + 1) * 1000000 + c.chapter.sortOrder] =
            positions[c.chapter.id] ?? 0;
      }
    }
    final currentGlobalFixed =
        (currentVolumeIndex != null && currentChapterOrder != null)
        ? (placementGlobal[currentVolumeIndex * 1000000 + currentChapterOrder] ??
              0)
        : null;

    final eligible = <({int planted, String text})>[];
    for (final fs in bundle.foreshadowings) {
      if (fs.status != 'open') continue;
      final planned =
          fs.plannedResolve != null && fs.plannedResolve!.trim().isNotEmpty;
      final suggested = fs.suggestedResolved;
      var age = 0;
      if (fs.plantedVolumeIndex != null && fs.plantedChapterOrder != null) {
        final plantedGlobal =
            placementGlobal[fs.plantedVolumeIndex! * 1000000 +
                fs.plantedChapterOrder!] ??
            0;
        final curGlobal =
            currentGlobalFixed ?? (bundle.allChaptersInOrder.length + 1);
        age = plantedGlobal > 0
            ? (curGlobal - plantedGlobal).clamp(0, 1 << 30)
            : 1 << 30;
      }
      final overdue = age >= threshold;
      if (!planned && !suggested && !overdue) continue;

      final line = StringBuffer();
      if (fs.plantedVolumeIndex != null && fs.plantedChapterOrder != null) {
        line.write('第${fs.plantedVolumeIndex}卷第${fs.plantedChapterOrder}章：');
      }
      line.write(fs.title);
      final marks = <String>[];
      if (planned) marks.add('计划回收：${fs.plannedResolve}');
      if (overdue && age < (1 << 29)) marks.add('已逾$age章未回收');
      if (suggested) marks.add('摘要提及可能已回收，待确认');
      if (marks.isNotEmpty) line.write('（${marks.join('；')}）');

      eligible.add((
        planted: fs.plantedVolumeIndex ?? fs.plantedChapterOrder ?? 1 << 30,
        text: line.toString(),
      ));
    }

    if (eligible.isEmpty) return null;
    eligible.sort((a, b) {
      final c = a.planted.compareTo(b.planted);
      return c != 0 ? c : a.text.compareTo(b.text);
    });
    var body = '【未回收伏笔提醒】\n${eligible.map((e) => e.text).join('\n')}';
    if (body.length > PromptLimits.foreshadowReminderCap) {
      body = body.substring(0, PromptLimits.foreshadowReminderCap);
    }
    return body;
  }

  static String _cappedRequired(
    String text,
    String label,
    List<String> truncated,
  ) {
    const limit = PromptLimits.requiredFieldCap;
    if (text.length <= limit) return text;
    truncated.add('$label（超过 $limit 字，已截断保留末尾）');
    return '……${text.substring(text.length - limit)}';
  }

  static void _appendPrevProseTail(
    ChapterBundle chapter,
    NovelBundle bundle,
    List<String> required,
  ) {
    final all = bundle.allChaptersInOrder;
    final idx = all.indexWhere((c) => c.chapter.id == chapter.chapter.id);
    if (idx <= 0) return;
    final prev = all[idx - 1];
    var tail = prev.chapter.content.trim();
    if (tail.isEmpty) return;
    if (tail.length > neighborTailLength) {
      tail = tail.substring(tail.length - neighborTailLength);
    }
    required.add('【上一章正文末尾】\n……$tail');
  }

  static void _appendNextOutlineHead(
    ChapterBundle chapter,
    NovelBundle bundle,
    List<String> required,
  ) {
    final all = bundle.allChaptersInOrder;
    final idx = all.indexWhere((c) => c.chapter.id == chapter.chapter.id);
    if (idx < 0 || idx + 1 >= all.length) return;
    final next = all[idx + 1];
    final outline = next.chapter.detailedOutline?.trim();
    if (outline == null || outline.isEmpty) return;
    final head = outline.length > nextOutlineHeadLength
        ? '${outline.substring(0, nextOutlineHeadLength)}……'
        : outline;
    required.add('【下一章细纲（开头走向）】\n$head');
  }

  static List<(int, String)> _summariesBefore(
    int globalIndex,
    NovelBundle bundle,
    Map<String, int> positions, {
    required int limit,
  }) {
    final matched = bundle.allChaptersInOrder
        .where(
          (c) =>
              c.summary != null &&
              (positions[c.chapter.id] ?? 0) < globalIndex,
        )
        .toList();
    final tail = matched.length > limit
        ? matched.sublist(matched.length - limit)
        : matched;
    return [
      for (final c in tail) (positions[c.chapter.id] ?? 0, c.summary!.summaryText),
    ];
  }

  static List<String> _keyFactsBefore(
    int globalIndex,
    NovelBundle bundle,
    Map<String, int> positions, {
    required int limit,
  }) {
    final matched = bundle.allChaptersInOrder
        .where(
          (c) =>
              c.summary != null &&
              (positions[c.chapter.id] ?? 0) < globalIndex,
        )
        .toList();
    final tail = matched.length > limit
        ? matched.sublist(matched.length - limit)
        : matched;
    return [for (final c in tail) ...c.keyFacts];
  }

  static String _renderCharacter(db.Character c) {
    final aliases = decodeStringList(c.aliasesJson);
    final lines = <String>[
      '◆ ${c.name}${aliases.isEmpty ? '' : '（${aliases.join('/')}）'}',
    ];
    if (c.personality != null && c.personality!.isNotEmpty) {
      lines.add('性格：${c.personality}');
    }
    if (c.currentGoal != null && c.currentGoal!.isNotEmpty) {
      lines.add('当前目标：${c.currentGoal}');
    }
    if (c.currentLocation != null && c.currentLocation!.isNotEmpty) {
      lines.add('当前位置：${c.currentLocation}');
    }
    if (c.physicalState != null && c.physicalState!.isNotEmpty) {
      lines.add('身体状态：${c.physicalState}');
    }
    if (c.mentalState != null && c.mentalState!.isNotEmpty) {
      lines.add('心理状态：${c.mentalState}');
    }
    if (c.lastSeenChapterTitle != null && c.lastSeenChapterTitle!.isNotEmpty) {
      lines.add('最近出场：${c.lastSeenChapterTitle}');
    }
    return lines.join('\n');
  }

  static int? _volumeIndexOf(NovelBundle bundle, String volumeId) {
    final idx = bundle.volumes.indexWhere((v) => v.volume.id == volumeId);
    return idx < 0 ? null : idx + 1;
  }

  static String _volumeBrief(VolumeBundle vol, List<String> truncated) {
    final lines = <String>['【本卷信息】', '卷名：${vol.volume.name}'];
    final outline = vol.volume.outline;
    if (outline != null && outline.trim().isNotEmpty) {
      lines.add(
        '当前卷纲（在其基础上修订，而非推倒重来）：\n${_cappedRequired(outline, '当前卷纲', truncated)}',
      );
    }
    final arc = vol.emotionArc;
    if (arc.isNotEmpty) lines.add('情绪走向：${arc.join(' → ')}');
    final ladder = vol.conflictLadder;
    if (ladder.isNotEmpty) {
      lines.add('冲突阶梯：');
      for (final rung in ladder) {
        final tp = rung.turningPoint;
        lines.add(
          '  L${rung.level} 阻力：${rung.obstacle}${(tp != null && tp.isNotEmpty) ? '（转折：$tp）' : ''}',
        );
      }
    }
    final gap = vol.infoGap;
    if (gap != null && !gap.isEmpty) {
      lines.add('信息差：起点=${gap.start}；终点=${gap.end}');
    }
    if (vol.chapters.isNotEmpty) {
      lines.add(
        '本卷已有章节：${vol.chapters.map((c) => c.chapter.title).join('、')}',
      );
    }
    return lines.join('\n');
  }

  static String _structureText(NovelBundle bundle, {String? highlightId}) {
    return bundle.volumes
        .map((v) {
          final mark = v.volume.id == highlightId ? '▶（本卷）' : '';
          final titles = v.chapters.map((c) => c.chapter.title).join('、');
          return titles.isEmpty
              ? '◇ ${v.volume.name}$mark'
              : '◇ ${v.volume.name}$mark：$titles';
        })
        .join('\n');
  }

  static List<String> _chapterBrief(
    ChapterBundle chapter,
    NovelBundle bundle,
    List<String> truncated,
  ) {
    final blocks = <String>[];
    final vol = bundle.volumes
        .where((v) => v.volume.id == chapter.volumeId)
        .firstOrNull;
    if (vol != null) {
      final lines = <String>['【所在卷】', '卷名：${vol.volume.name}'];
      final vo = vol.volume.outline;
      if (vo != null && vo.trim().isNotEmpty) {
        lines.add('卷纲：\n${_cappedRequired(vo, '所在卷卷纲', truncated)}');
      }
      blocks.add(lines.join('\n'));
    }

    final all = bundle.allChaptersInOrder;
    final idx = all.indexWhere((c) => c.chapter.id == chapter.chapter.id);
    if (idx > 0) {
      blocks.add('【上一章】\n${_neighborLine(all[idx - 1])}');
    }
    if (idx >= 0 && idx + 1 < all.length) {
      blocks.add('【下一章】\n${_neighborLine(all[idx + 1])}');
    }

    final current = <String>['【本章现状】', '章题：${chapter.chapter.title}'];
    final co = chapter.chapter.detailedOutline;
    if (co != null && co.trim().isNotEmpty) {
      current.add(
        '当前细纲（在其基础上修订，而非推倒重来）：\n${_cappedRequired(co, '当前细纲', truncated)}',
      );
    }
    final cards = chapter.sceneCards;
    if (cards.isNotEmpty) {
      current.add('场景卡：\n${renderSceneCards(cards)}');
    }
    if (chapter.chapter.content.isNotEmpty) {
      var tail = chapter.chapter.content;
      if (tail.length > tailLength) {
        tail = tail.substring(tail.length - tailLength);
      }
      current.add('本章已写正文末尾：\n$tail');
    }
    blocks.add(current.join('\n'));
    return blocks;
  }

  static String _neighborLine(ChapterBundle ch) {
    final outline = ch.chapter.detailedOutline?.trim();
    if (outline != null && outline.isNotEmpty) {
      return '${ch.chapter.title}：${outline.length > 120 ? '${outline.substring(0, 120)}……' : outline}';
    }
    if (ch.chapter.content.isNotEmpty) {
      return '${ch.chapter.title}：（已开写，暂无细纲）';
    }
    return '${ch.chapter.title}：（未填写）';
  }

  static String? _recentProseTail(
    NovelBundle bundle, {
    String? excludingId,
    required int limit,
  }) {
    final written = bundle.allChaptersInOrder
        .where(
          (c) =>
              c.chapter.content.isNotEmpty && c.chapter.id != excludingId,
        )
        .toList();
    if (written.isEmpty) return null;
    written.sort((a, b) => a.chapter.updatedAt.compareTo(b.chapter.updatedAt));
    final latest = written.last;
    var tail = latest.chapter.content;
    if (tail.length > limit) tail = tail.substring(tail.length - limit);
    return '《${latest.chapter.title}》末尾：\n$tail';
  }
}
