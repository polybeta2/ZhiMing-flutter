import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/llm_json_parser.dart';
import '../../core/prompts/prompt_limits.dart';
import '../models/blueprint_models.dart';
import '../models/novel_domain.dart';

class OutlineProgress {
  const OutlineProgress({
    required this.volumeTotal,
    required this.volumeDone,
    required this.outlineTotal,
    required this.outlineDone,
  });

  final int volumeTotal;
  final int volumeDone;
  final int outlineTotal;
  final int outlineDone;
}

enum CreationNextStep { requestStructure }

class CreationSettleOutcome {
  const CreationSettleOutcome({
    required this.state,
    this.message,
    this.error,
    this.autoNext = false,
    this.nextStep,
  });

  final CreationSessionState state;
  final String? message;
  final String? error;
  final bool autoNext;
  final CreationNextStep? nextStep;
}

/// 立项五阶段纯状态机（完整保留宽容名称匹配、同名章消费防死循环、伏笔揭晓提醒与安全落库映射）
class CreationSessionEngine {
  CreationSessionEngine(this.state);

  final CreationSessionState state;

  static final RegExp _decorationRe = RegExp(
    r'[\s\u3000：:·、，,。.\-–—…「」『』《》""' "'" r'（）()【】\[\]!！?？]',
  );

  static String stripNameDecoration(String name) =>
      name.toLowerCase().replaceAll(_decorationRe, '');

  /// 归一化精确匹配优先，退化为唯一包含匹配（多命中视为歧义跳过，宁缺勿错）
  static int? fuzzyMatchIndex(List<String> names, String target) {
    final norm = stripNameDecoration(target);
    if (norm.isEmpty) return null;
    final normNames = [for (final n in names) stripNameDecoration(n)];
    final exact = normNames.indexOf(norm);
    if (exact >= 0) return exact;
    final hits = <int>[];
    for (var i = 0; i < normNames.length; i++) {
      final n = normNames[i];
      if (n.isEmpty) continue;
      if (n.contains(norm) || norm.contains(n)) hits.add(i);
    }
    return hits.length == 1 ? hits.first : null;
  }

  CreationSettleOutcome settle({
    required CreationStreamKind kind,
    required String raw,
    int chapterNameTargetIndex = -1,
  }) {
    if (state.phase == CreationPhase.confirmed) {
      return CreationSettleOutcome(state: state, error: '作品已创建，生成结果已忽略');
    }
    if ((kind == CreationStreamKind.chapterBatch ||
            kind == CreationStreamKind.volumeBatch ||
            kind == CreationStreamKind.chapterNames) &&
        state.blueprint == null) {
      return CreationSettleOutcome(state: state, error: '尚无蓝图，批量生成结果已忽略');
    }

    return switch (kind) {
      CreationStreamKind.clarify => _settleClarify(raw),
      CreationStreamKind.structure => _settleStructure(raw),
      CreationStreamKind.foundation => _settleFoundation(raw),
      CreationStreamKind.revise => _settleRevise(raw),
      CreationStreamKind.volumeBatch => _settleVolumeBatch(raw),
      CreationStreamKind.chapterNames => _settleChapterNames(
        raw,
        chapterNameTargetIndex,
      ),
      CreationStreamKind.chapterBatch => _settleChapterBatch(raw),
    };
  }

  CreationSettleOutcome _settleClarify(String raw) {
    final parsed = LLMJSONParser.decodeObject(raw, ClarifyResult.fromJson);
    if (parsed == null) {
      return CreationSettleOutcome(state: state, error: '澄清结果解析失败，请重试');
    }
    final qs = (parsed.questions ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parsed.enough == true || qs.isEmpty) {
      return CreationSettleOutcome(
        state: state,
        message: '思路已经理清，正在规划卷章结构…',
        nextStep: CreationNextStep.requestStructure,
      );
    }
    final numbered = [
      for (var i = 0; i < qs.length; i++) '${i + 1}. ${qs[i]}',
    ].join('\n');
    state.qaText += '【问题】\n$numbered\n';
    return CreationSettleOutcome(
      state: state,
      message: '有几个地方想先确认一下：\n\n$numbered',
    );
  }

  CreationSettleOutcome _settleStructure(String raw) {
    final parsed = LLMJSONParser.decodeObject(raw, StructureProposal.fromJson);
    if (parsed == null) {
      return CreationSettleOutcome(
        state: state,
        error: '结构提案解析失败，可发送「重新规划」或修改意见重试',
      );
    }
    state.proposal = parsed;
    state.phase = CreationPhase.proposing;
    return CreationSettleOutcome(
      state: state,
      message: '已按思路规划出卷章结构，请审阅下方提案卡片：确认结构开始生成蓝图，或直接告诉我调整意见。',
    );
  }

  CreationSettleOutcome _settleFoundation(String raw) {
    final parsed = LLMJSONParser.decodeObject(raw, NovelBlueprint.fromJson);
    if (parsed == null) {
      state.phase = CreationPhase.proposing;
      return CreationSettleOutcome(
        state: state,
        error: '蓝图 JSON 解析失败，可发送「重新生成」重试',
      );
    }
    state.blueprint = parsed;
    state.phase = CreationPhase.blueprintReady;
    return CreationSettleOutcome(
      state: state,
      message: '基础蓝图已生成（角色、世界观与卷章结构），可在卡片中就地编辑、对话修订，或开始分批生成卷纲与细纲。',
    );
  }

  CreationSettleOutcome _settleRevise(String raw) {
    final parsed = LLMJSONParser.decodeObject(raw, NovelBlueprint.fromJson);
    if (parsed == null) {
      return CreationSettleOutcome(
        state: state,
        error: '蓝图修订 JSON 解析失败，请重试',
      );
    }
    state.blueprint = parsed;
    return CreationSettleOutcome(
      state: state,
      message: '已按你的意见修订蓝图，可继续调整或生成卷纲/细纲。',
    );
  }

  CreationSettleOutcome _settleVolumeBatch(String raw) {
    final batch = LLMJSONParser.decodeList(raw, VolumeOutlinePatch.fromJson);
    if (batch == null) {
      return CreationSettleOutcome(
        state: state,
        error: '卷纲批次解析失败，可重新生成本批',
      );
    }
    applyVolumeBatch(batch);
    state.phase = CreationPhase.outlining;
    final p = outlineProgress;
    final msg = p.volumeDone >= p.volumeTotal
        ? '卷纲已全部生成（${p.volumeDone}/${p.volumeTotal}），接下来可以分批生成章节细纲。'
        : '已生成本批卷纲（进度 ${p.volumeDone}/${p.volumeTotal}）。';
    return CreationSettleOutcome(
      state: state,
      message: msg,
      autoNext: state.autoContinue && p.volumeDone < p.volumeTotal,
    );
  }

  CreationSettleOutcome _settleChapterNames(String raw, int targetIndex) {
    final bp = state.blueprint;
    final batch = LLMJSONParser.decodeList(raw, BlueprintChapter.fromJson);
    if (bp == null || batch == null) {
      return CreationSettleOutcome(state: state, error: '章节标题解析失败，可重新生成');
    }
    if (targetIndex < 0 || targetIndex >= bp.volumes.length) {
      return CreationSettleOutcome(state: state, message: '章节标题已生成完毕');
    }
    final titles = batch
        .map((c) => c.title?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (titles.isEmpty) {
      return CreationSettleOutcome(state: state, error: '解析到空章节标题，请重试');
    }
    final vol = bp.volumes[targetIndex];
    for (var i = 0; i < vol.chapters.length && i < titles.length; i++) {
      vol.chapters[i].title = titles[i];
    }
    final written = titles.length < vol.chapters.length
        ? titles.length
        : vol.chapters.length;
    return CreationSettleOutcome(
      state: state,
      message: '已生成《${vol.name ?? '本卷'}》$written 个章节标题。',
    );
  }

  CreationSettleOutcome _settleChapterBatch(String raw) {
    final batch = LLMJSONParser.decodeList(raw, BlueprintChapter.fromJson);
    if (batch == null) {
      return CreationSettleOutcome(
        state: state,
        error: '细纲批次解析失败，可重新生成本批',
      );
    }
    applyChapterBatch(batch);
    state.phase = CreationPhase.outlining;
    final p = outlineProgress;
    final msg = p.outlineDone >= p.outlineTotal
        ? '细纲已全部生成（${p.outlineDone}/${p.outlineTotal}）。点击「创建作品落库」开始写作吧！'
        : '已生成本批细纲（进度 ${p.outlineDone}/${p.outlineTotal}）。';
    return CreationSettleOutcome(
      state: state,
      message: msg,
      autoNext: state.autoContinue && p.outlineDone < p.outlineTotal,
    );
  }

  void applyVolumeBatch(List<VolumeOutlinePatch> batch) {
    final bp = state.blueprint;
    if (bp == null) return;
    final names = [for (final v in bp.volumes) v.name ?? ''];
    for (final item in batch) {
      final name = item.name?.trim() ?? '';
      final outline = item.outline?.trim() ?? '';
      if (name.isEmpty || outline.isEmpty) continue;
      final vIdx = fuzzyMatchIndex(names, name);
      if (vIdx == null) continue;
      final target = bp.volumes[vIdx];
      target.outline = item.outline;
      final arc = item.emotionArc
          ?.map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (arc != null && arc.isNotEmpty) target.emotionArc = arc;
      if (item.conflictLadder != null && item.conflictLadder!.isNotEmpty) {
        target.conflictLadder = item.conflictLadder;
      }
      if (item.infoGap != null && !item.infoGap!.isEmpty) {
        target.infoGap = item.infoGap;
      }
    }
  }

  void applyChapterBatch(List<BlueprintChapter> batch) {
    final bp = state.blueprint;
    if (bp == null) return;
    final flat = <({int v, int c, String title})>[];
    for (var v = 0; v < bp.volumes.length; v++) {
      for (var c = 0; c < bp.volumes[v].chapters.length; c++) {
        flat.add((v: v, c: c, title: bp.volumes[v].chapters[c].title ?? ''));
      }
    }
    final available = [
      for (var i = 0; i < flat.length; i++) (offset: i, title: flat[i].title),
    ];

    for (final item in batch) {
      final title = item.title?.trim() ?? '';
      final outline = item.detailedOutline?.trim() ?? '';
      if (title.isEmpty || outline.isEmpty) continue;
      final hitIdx = fuzzyMatchIndex(
        [for (final a in available) a.title],
        title,
      );
      if (hitIdx == null) continue;
      final entry = available.removeAt(hitIdx);
      final target = flat[entry.offset];
      final ch = bp.volumes[target.v].chapters[target.c];
      ch.detailedOutline = item.detailedOutline;
      if (item.sceneCards != null && item.sceneCards!.isNotEmpty) {
        ch.sceneCards = item.sceneCards!.where((c) => !c.isEmpty).toList();
      }
      final fs = (item.foreshadowings ?? const [])
          .where((f) => (f.title ?? '').trim().isNotEmpty)
          .toList();
      if (fs.isNotEmpty) ch.foreshadowings = fs;
    }
  }

  OutlineProgress get outlineProgress {
    final bp = state.blueprint;
    if (bp == null) {
      return const OutlineProgress(
        volumeTotal: 0,
        volumeDone: 0,
        outlineTotal: 0,
        outlineDone: 0,
      );
    }
    final volDone = bp.volumes
        .where((v) => (v.outline ?? '').trim().isNotEmpty)
        .length;
    final allChs = [for (final v in bp.volumes) ...v.chapters];
    final chDone = allChs
        .where((c) => (c.detailedOutline ?? '').trim().isNotEmpty)
        .length;
    return OutlineProgress(
      volumeTotal: bp.volumes.length,
      volumeDone: volDone,
      outlineTotal: allChs.length,
      outlineDone: chDone,
    );
  }

  List<String> pendingVolumes(int limit) {
    final bp = state.blueprint;
    if (bp == null) return const [];
    final out = <String>[];
    for (var i = 0; i < bp.volumes.length; i++) {
      final v = bp.volumes[i];
      if ((v.outline ?? '').trim().isEmpty) {
        out.add((v.name ?? '').isNotEmpty ? v.name! : '第${i + 1}卷');
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  List<String> pendingChapters(int limit) {
    final bp = state.blueprint;
    if (bp == null) return const [];
    final out = <String>[];
    for (final v in bp.volumes) {
      for (final c in v.chapters) {
        if ((c.detailedOutline ?? '').trim().isEmpty) {
          final title = c.title?.trim() ?? '';
          if (title.isNotEmpty) out.add(title);
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  String volumeBatchContext(List<String> targets, {String? sourceWindow}) {
    final bp = state.blueprint;
    if (bp == null) return '';
    final lines = <String>[];
    if ((bp.titleSuggestion ?? '').isNotEmpty) {
      lines.add('【书名】${bp.titleSuggestion}');
    }
    if ((bp.synopsis ?? '').isNotEmpty) lines.add('【梗概】${bp.synopsis}');
    if ((bp.styleGuide ?? '').isNotEmpty) lines.add('【文风约束】${bp.styleGuide}');
    final concept = state.proposal?.concept ?? '';
    if (concept.isNotEmpty) {
      final capped = concept.length > PromptLimits.requiredFieldCap
          ? concept.substring(0, PromptLimits.requiredFieldCap)
          : concept;
      lines.add('【已确认的故事思路】\n$capped');
    }
    final chars = bp.characters
        .where((c) => (c.name ?? '').trim().isNotEmpty)
        .map((c) => '${c.name!.trim()}（${c.role ?? '角色'}）')
        .toList();
    if (chars.isNotEmpty) lines.add('【角色】${chars.join('、')}');
    if (sourceWindow != null && sourceWindow.trim().isNotEmpty) {
      lines.add('【原作时间窗（本批目标阶段）】\n${sourceWindow.trim()}');
    }

    final structure = <String>[];
    for (var i = 0; i < bp.volumes.length; i++) {
      final v = bp.volumes[i];
      final name = (v.name ?? '').isNotEmpty ? v.name! : '第${i + 1}卷';
      final isTarget = targets.contains(name);
      final titles = v.chapters
          .map((c) => c.title ?? '')
          .where((s) => s.isNotEmpty)
          .join('、');
      var line = '◇ $name（${v.chapters.length} 章）${isTarget ? '▶（本批）' : ''}';
      if (isTarget && titles.isNotEmpty) line += '：$titles';
      structure.add(line);
    }
    lines.add('【全书结构】\n${structure.join('\n')}');

    for (final v in bp.volumes) {
      if ((v.outline ?? '').trim().isNotEmpty) {
        lines.add('【${v.name ?? '卷'}·已生成卷纲】${v.outline}');
      }
    }
    return lines.join('\n\n');
  }

  String chapterBatchContext(List<String> targets, {String? sourceWindow}) {
    final bp = state.blueprint;
    if (bp == null) return '';
    final lines = <String>[];
    if ((bp.titleSuggestion ?? '').isNotEmpty) {
      lines.add('【书名】${bp.titleSuggestion}');
    }
    if ((bp.synopsis ?? '').isNotEmpty) lines.add('【梗概】${bp.synopsis}');
    if ((bp.styleGuide ?? '').isNotEmpty) lines.add('【文风约束】${bp.styleGuide}');
    final concept = state.proposal?.concept ?? '';
    if (concept.isNotEmpty) {
      final capped = concept.length > PromptLimits.requiredFieldCap
          ? concept.substring(0, PromptLimits.requiredFieldCap)
          : concept;
      lines.add('【已确认的故事思路】\n$capped');
    }
    final chars = bp.characters
        .where((c) => (c.name ?? '').trim().isNotEmpty)
        .map((c) => '${c.name!.trim()}（${c.role ?? '角色'}）')
        .toList();
    if (chars.isNotEmpty) lines.add('【角色】${chars.join('、')}');
    if (sourceWindow != null && sourceWindow.trim().isNotEmpty) {
      lines.add('【原作时间窗（本批目标阶段）】\n${sourceWindow.trim()}');
    }

    for (var i = 0; i < bp.volumes.length; i++) {
      final v = bp.volumes[i];
      if ((v.outline ?? '').isEmpty) continue;
      final hit = v.chapters.any(
        (c) => targets.contains(c.title?.trim() ?? ''),
      );
      if (hit) {
        lines.add('【${v.name ?? '第${i + 1}卷'}·卷纲】${v.outline}');
      } else {
        final short = v.outline!.length > 80
            ? v.outline!.substring(0, 80)
            : v.outline!;
        lines.add('【${v.name ?? '第${i + 1}卷'}】$short');
      }
    }

    final flat = [for (final v in bp.volumes) ...v.chapters];
    final done = flat
        .where((c) => (c.detailedOutline ?? '').trim().isNotEmpty)
        .map((c) => '${c.title ?? ''}：${c.detailedOutline}')
        .toList();
    if (done.isNotEmpty) {
      final recent = done.length > 5 ? done.sublist(done.length - 5) : done;
      lines.add('【最近已生成细纲】\n${recent.join('\n')}');
    }

    final lastIdx = flat.lastIndexWhere(
      (c) => targets.contains(c.title?.trim() ?? ''),
    );
    if (lastIdx >= 0 && lastIdx + 1 < flat.length) {
      final upcoming = flat
          .sublist(lastIdx + 1)
          .map((c) => c.title ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (upcoming.isNotEmpty) {
        lines.add('【后续章节】\n${upcoming.join('\n')}');
      }
    }

    final reveals = pendingForeshadows(targets);
    if (reveals.isNotEmpty) {
      lines.add('【需在本批揭晓的伏笔】\n${reveals.join('\n')}');
    }
    return lines.join('\n\n');
  }

  List<String> pendingForeshadows(List<String> targetTitles) {
    final bp = state.blueprint;
    if (bp == null) return const [];
    final targetSet = targetTitles.toSet();
    final out = <String>[];
    for (final v in bp.volumes) {
      for (final c in v.chapters) {
        final planted = c.title;
        if (planted == null) continue;
        for (final fs in c.foreshadowings ?? const <BlueprintForeshadow>[]) {
          final rev = fs.revealIn?.trim() ?? '';
          final title = fs.title?.trim() ?? '';
          if (!targetSet.contains(rev) || title.isEmpty) continue;
          final detail = (fs.detail ?? '').isNotEmpty ? '：${fs.detail}' : '';
          out.add('「$title」→ 应在《$rev》揭晓（埋设于《$planted》）$detail');
        }
      }
    }
    return out;
  }

  /// 将确认的蓝图落库到 Drift 数据库（世界观合并保留用户手输项）
  static Future<void> persistBlueprintToDb({
    required AppDatabase db,
    required String novelId,
    required NovelBlueprint blueprint,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();

    await db.transaction(() async {
      final existingNovel = await db.getNovel(novelId);
      if (existingNovel == null) return;

      await (db.update(db.novels)..where((t) => t.id.equals(novelId))).write(
        NovelsCompanion(
          title: Value(
            (blueprint.titleSuggestion ?? '').trim().isNotEmpty
                ? blueprint.titleSuggestion!.trim()
                : existingNovel.title,
          ),
          synopsis: Value(
            (blueprint.synopsis ?? '').trim().isNotEmpty
                ? blueprint.synopsis!.trim()
                : existingNovel.synopsis,
          ),
          genre: Value(
            (blueprint.theme ?? '').trim().isNotEmpty
                ? blueprint.theme!.trim()
                : existingNovel.genre,
          ),
          perspective: Value(
            (blueprint.perspective ?? '').trim().isNotEmpty
                ? blueprint.perspective!.trim()
                : existingNovel.perspective,
          ),
          styleGuide: Value(
            (blueprint.styleGuide ?? '').trim().isNotEmpty
                ? blueprint.styleGuide!.trim()
                : existingNovel.styleGuide,
          ),
          updatedAt: Value(now),
        ),
      );

      // 角色：替换蓝图生成角色（不抹除已有角色可改合并，这里对齐原版清空重写）
      await (db.delete(
        db.characters,
      )..where((t) => t.novelId.equals(novelId))).go();
      for (var i = 0; i < blueprint.characters.length; i++) {
        final item = blueprint.characters[i];
        final name = item.name?.trim() ?? '';
        if (name.isEmpty) continue;
        await db.upsertCharacter(
          CharactersCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            name: name,
            appearance: Value(item.appearance),
            personality: Value(item.personality),
            background: Value(
              (item.role ?? '').isNotEmpty ? '书中定位：${item.role}' : null,
            ),
            currentGoal: Value(item.goal),
            isSceneRelevant: const Value(true),
            sortOrder: Value(i),
          ),
        );
      }

      // 世界观：合并而非清空（同名保留用户手输版本）
      final existingWorlds = await db.getWorldEntries(novelId);
      final existingNames = existingWorlds.map((w) => w.name).toSet();
      var wOrder = existingWorlds.length;
      for (final item in blueprint.worldbuilding) {
        final name = item.name?.trim() ?? '';
        if (name.isEmpty || existingNames.contains(name)) continue;
        final cat = WorldCategories.all.contains(item.category)
            ? item.category!
            : '其他';
        await db.upsertWorldEntry(
          WorldEntriesCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            category: cat,
            name: name,
            content: Value(item.content ?? ''),
            sortOrder: Value(wOrder++),
          ),
        );
        existingNames.add(name);
      }

      // 卷与章（保留续写原作卷与已写有内容的卷；自动清理空白占位卷，避免落库后残留空「第一卷」）
      final existingVols = await db.getVolumes(novelId);
      var keptVolCount = 0;
      for (final vol in existingVols) {
        final chs = await db.getChaptersByVolume(vol.id);
        final hasMeaningfulContent = chs.any(
          (c) =>
              c.isOriginal ||
              c.content.trim().isNotEmpty ||
              (c.detailedOutline ?? '').trim().isNotEmpty,
        );
        if (!hasMeaningfulContent && (vol.outline ?? '').trim().isEmpty) {
          await db.deleteVolume(vol.id);
        } else {
          keptVolCount += 1;
        }
      }
      final baseVolOrder = keptVolCount;

      for (var v = 0; v < blueprint.volumes.length; v++) {
        final vItem = blueprint.volumes[v];
        final volId = uuid.v4();
        final volOrder = baseVolOrder + v + 1;
        await db.upsertVolume(
          VolumesCompanion.insert(
            id: volId,
            novelId: novelId,
            name: (vItem.name ?? '').trim().isNotEmpty
                ? vItem.name!.trim()
                : '第$volOrder卷',
            outline: Value(vItem.outline),
            emotionArcJson: Value(
              (vItem.emotionArc ?? const []).isEmpty
                  ? null
                  : encodeStringList(vItem.emotionArc!),
            ),
            conflictLadderJson: Value(
              ConflictRung.encodeList(vItem.conflictLadder ?? const []),
            ),
            infoGapJson: Value(InfoGap.encode(vItem.infoGap)),
            sortOrder: volOrder,
          ),
        );

        for (var c = 0; c < vItem.chapters.length; c++) {
          final cItem = vItem.chapters[c];
          final chId = uuid.v4();
          await db.upsertChapter(
            ChaptersCompanion.insert(
              id: chId,
              volumeId: volId,
              title: (cItem.title ?? '').trim().isNotEmpty
                  ? cItem.title!.trim()
                  : '第${c + 1}章',
              detailedOutline: Value(
                (cItem.detailedOutline ?? '').trim().isEmpty
                    ? null
                    : cItem.detailedOutline!.trim(),
              ),
              sceneCardsJson: Value(
                SceneCard.encodeList(cItem.sceneCards ?? const []),
              ),
              sortOrder: c + 1,
              updatedAt: now,
            ),
          );

          // 若细纲阶段登记了伏笔，同步落入伏笔台账
          for (final fs in cItem.foreshadowings ?? const <BlueprintForeshadow>[]) {
            final fsTitle = fs.title?.trim() ?? '';
            if (fsTitle.isEmpty) continue;
            await db.upsertForeshadowing(
              ForeshadowingsCompanion.insert(
                id: uuid.v4(),
                novelId: novelId,
                title: fsTitle,
                detail: Value(fs.detail),
                plantedVolumeIndex: Value(volOrder),
                plantedChapterOrder: Value(c + 1),
                plannedResolve: Value(fs.revealIn),
                createdAt: now,
              ),
            );
          }
        }
      }
    });
  }
}
