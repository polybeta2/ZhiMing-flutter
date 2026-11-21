import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/storage/blob_store.dart';
import '../../domain/models/source_profile_models.dart';
import '../../domain/models/style_models.dart';
import '../../domain/source/continuation_context.dart';
import '../../domain/source/novel_text_cleaner.dart';
import '../../domain/source/source_time_window.dart';
import '../../domain/style/style_card_renderer.dart';
import '../../domain/style/style_chapter_sampler.dart';

/// 统一上下文注入助手：解析文风卡 + 原作时间窗 / 续写上下文，并提供一键同人立项与续写全量建书。
class SourceAndStyleBridge {
  SourceAndStyleBridge({required this.db, required this.blobs});

  final AppDatabase db;
  final BlobStore blobs;

  Future<StyleProfileData?> loadStyleProfile(String? id) async {
    if (id == null || id.isEmpty) return null;
    final rows = await db.watchStyleProfiles().first;
    final row = rows.where((r) => r.id == id).firstOrNull;
    if (row == null) return null;
    try {
      return StyleProfileData.fromJson(jsonDecode(row.payloadJson));
    } catch (_) {
      return null;
    }
  }

  Future<String?> resolveStyleCard(
    String? styleProfileId, {
    StyleCardVariant variant = StyleCardVariant.writing,
  }) async {
    final profile = await loadStyleProfile(styleProfileId);
    if (profile == null) return null;
    final rendered = StyleCardRenderer.render(profile, variant).trim();
    return rendered.isEmpty ? null : rendered;
  }

  Future<SourceNovelProfileData?> loadSourceProfile(String? id) async {
    if (id == null || id.isEmpty) return null;
    final rows = await db.watchSourceProfiles().first;
    final row = rows.where((r) => r.id == id).firstOrNull;
    if (row == null) return null;
    try {
      return SourceNovelProfileData.fromJsonString(row.payloadJson);
    } catch (_) {
      return null;
    }
  }

  /// 全书梗概 / 续写总上下文（供立项澄清 4000 / 结构蓝图 8000 / 助手使用）
  Future<String?> resolveSourceContext(
    String? sourceProfileId, {
    int maxChars = 4000,
  }) async {
    final profile = await loadSourceProfile(sourceProfileId);
    if (profile == null || !profile.scanState.isComplete) return null;
    final title = profile.title.trim();
    final header = title.isEmpty ? '' : '原作：《$title》';

    if (profile.continuationFromChapter != null) {
      final tailBudget = (maxChars ~/ 2).clamp(1200, 4000);
      final recent = profile.hasSourceText
          ? await blobs.loadTailAligned(
              BlobKinds.continuation,
              profile.id,
              maxChars: tailBudget,
            )
          : null;
      final body = ContinuationContext.rendered(
        profile: profile,
        recentText: recent,
        maxChars: maxChars,
      );
      return [header, body].where((e) => e.isNotEmpty).join('\n');
    }

    final slice = SourceTimeWindow.window(phase: null, profile: profile);
    final body = slice.rendered(maxChars: maxChars);
    return [header, body].where((e) => e.isNotEmpty).join('\n');
  }

  /// 按卷名/章标题定位原作阶段的时间窗（供续写 / AutoWrite 使用）
  Future<String?> resolveSourceWindow(
    String? sourceProfileId, {
    String? target,
    int maxChars = 3000,
  }) async {
    final profile = await loadSourceProfile(sourceProfileId);
    if (profile == null || !profile.scanState.isComplete) return null;
    if (profile.continuationFromChapter != null) {
      return resolveSourceContext(sourceProfileId, maxChars: maxChars);
    }
    final phase = (target != null && target.trim().isNotEmpty)
        ? nearestPhase(target, profile)
        : null;
    final slice = SourceTimeWindow.window(phase: phase, profile: profile);
    final body = slice.rendered(maxChars: maxChars).trim();
    return body.isEmpty ? null : body;
  }

  static String? nearestPhase(String target, SourceNovelProfileData profile) {
    final phases = profile.timeline
        .map((e) => (e.phase ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (phases.isEmpty) return null;
    final targetChars = target.split('').toSet();
    String? best;
    var bestScore = 0;
    for (final p in phases) {
      final score = p.split('').toSet().intersection(targetChars).length;
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return bestScore > 0 ? best : null;
  }

  /// 同人立项：绑定 sourceProfileId + 所选文风，建立立项澄清会话。
  Future<String> createFanficNovel({
    required SourceNovelProfileData profile,
    String? styleProfileId,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();
    final novelId = uuid.v4();

    await db.transaction(() async {
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: novelId,
          title: '《${profile.title}》同人',
          synopsis: const Value(''),
          accentColorHex: const Value('#2F6FED'),
          sourceProfileId: Value(profile.id),
          activeStyleProfileId: Value(styleProfileId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertVolume(
        VolumesCompanion.insert(
          id: uuid.v4(),
          novelId: novelId,
          name: '第一卷',
          sortOrder: 1,
        ),
      );
      await db.upsertChatThread(
        ChatThreadsCompanion.insert(
          id: uuid.v4(),
          novelId: novelId,
          purpose: 'creation',
          createdAt: now,
        ),
      );
    });
    return novelId;
  }

  /// 续写全量建书：导入原作 1~X 章只读卷 + 角色卡（含现状快照）+ 世界观 + 未回收伏笔台账 + 跳过澄清直达蓝图的立项会话。
  Future<String> createContinuationNovel({
    required SourceNovelProfileData profile,
  }) async {
    const uuid = Uuid();
    final now = DateTime.now();
    final novelId = uuid.v4();
    final upTo = profile.continuationFromChapter;

    String? sourceText;
    if (upTo != null && profile.hasSourceText) {
      sourceText = await blobs.loadText(BlobKinds.continuation, profile.id);
    }

    final synopsis = upTo != null
        ? '续写《${profile.title}》：已分析原作前 $upTo 章。请基于注入的原作上下文（人物现状、未回收伏笔、剧情弧、世界设定、近期原文）规划续写蓝图：'
            '1) 续写方向与分卷结构；2) 未回收伏笔的回收计划（各伏笔回收的大致位置）；'
            '3) 基调与文风衔接（延续近期原文笔感）；4) 从第 ${upTo + 1} 章开始续写。'
        : '续写《${profile.title}》（同人精度档案，基于全书时间窗）。请基于注入的原作上下文规划续写蓝图：'
            '1) 续写方向与分卷结构；2) 基调与文风衔接；3) 从原作结局之后继续。';

    await db.transaction(() async {
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: novelId,
          title: '《${profile.title}》续写',
          synopsis: Value(synopsis),
          accentColorHex: const Value('#2F6FED'),
          sourceProfileId: Value(profile.id),
          activeStyleProfileId: Value(profile.styleProfileId),
          createdAt: now,
          updatedAt: now,
        ),
      );

      var nextVolOrder = 1;
      final rawSource = sourceText;
      final origVolumeOutline = _buildOriginalVolumeOutline(profile);
      final chapterAnchors = _buildChapterOutlineAnchors(profile, upTo);
      final origChapterIdByOrder = <int, String>{};
      String? origVolId;

      if (upTo != null && rawSource != null && rawSource.isNotEmpty) {
        final chapters = StyleChapterSampler.split(rawSource).take(upTo).toList();
        final actualOrigCount = chapters.length;
        origVolId = uuid.v4();
        await db.upsertVolume(
          VolumesCompanion.insert(
            id: origVolId,
            novelId: novelId,
            name: '原作（$actualOrigCount 章）',
            outline: Value(origVolumeOutline.isEmpty ? null : origVolumeOutline),
            sortOrder: nextVolOrder++,
          ),
        );
        var order = 1;
        for (final ch in chapters) {
          final chId = uuid.v4();
          final chTitle = ch.marker.trim().isNotEmpty
              ? ch.marker.trim()
              : '第$order章';
          final cleanBody = NovelTextCleaner.cleanChapterBody(ch.body);
          final anchorLines = <String>[
            ...?chapterAnchors[order],
            if (order == actualOrigCount && profile.activeArcs.isNotEmpty)
              '【断更处正在推进的主线】\n${profile.activeArcs.map((a) => '- $a').join('\n')}',
          ];
          origChapterIdByOrder[order] = chId;
          await db.upsertChapter(
            ChaptersCompanion.insert(
              id: chId,
              volumeId: origVolId,
              title: chTitle,
              detailedOutline: Value(
                anchorLines.isEmpty ? null : anchorLines.join('\n\n'),
              ),
              content: Value(cleanBody),
              wordCount: Value(cleanBody.length),
              isOriginal: const Value(true),
              sortOrder: order++,
              updatedAt: now,
            ),
          );
        }
      }

      final nextVolOutline = profile.activeArcs.isEmpty
          ? null
          : '【续写衔接起点】承接原作末尾，当前待推进主线：\n${profile.activeArcs.map((a) => '- $a').join('\n')}';
      await db.upsertVolume(
        VolumesCompanion.insert(
          id: uuid.v4(),
          novelId: novelId,
          name: '第一卷',
          outline: Value(nextVolOutline),
          sortOrder: nextVolOrder,
        ),
      );

      // 1. 全量写入角色卡（保留 camp / role / arcJson），建立 名称/别名 -> characterId 映射
      final nameToCharId = <String, String>{};
      String normKey(String s) => s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

      for (var i = 0; i < profile.characters.length; i++) {
        final c = profile.characters[i];
        final charId = uuid.v4();
        final bg = [
          if (c.oneLine != null && c.oneLine!.isNotEmpty) c.oneLine!,
          if (c.abilities != null && c.abilities!.isNotEmpty)
            '能力：${c.abilities!}',
          if (c.relationships.isNotEmpty)
            '关系：${c.relationships.take(4).map((r) => '${r.target}(${r.relation})').join('、')}',
        ].join('；');
        final personality = [
          if (c.personality != null && c.personality!.isNotEmpty)
            c.personality!,
          if (c.voiceSamples.isNotEmpty)
            '口癖示例：${c.voiceSamples.take(2).map((s) => '「$s」').join(' ')}',
        ].join('\n');
        final isActive =
            c.importance == CanonImportance.major || i < 12;
        await db.upsertCharacter(
          CharactersCompanion.insert(
            id: charId,
            novelId: novelId,
            name: c.name,
            aliasesJson: Value(jsonEncode(c.aliases)),
            appearance: Value(c.appearance ?? ''),
            personality: Value(personality),
            background: Value(bg),
            physicalState: Value(c.currentState ?? ''),
            camp: Value(c.camp),
            role: Value(c.role),
            arcJson: Value(
              jsonEncode([for (final a in c.arc) a.toJson()]),
            ),
            isSceneRelevant: Value(isActive),
            sortOrder: Value(i),
          ),
        );
        nameToCharId[normKey(c.name)] = charId;
        for (final a in c.aliases) {
          final k = normKey(a);
          if (k.isNotEmpty) nameToCharId.putIfAbsent(k, () => charId);
        }
      }

      // 2. 无损写入结构化人物关系边（优先 profile.relations，兜底兼容旧 character.relationships）
      final insertedRelPairs = <String>{};
      for (final edge in profile.relations) {
        final srcId = nameToCharId[normKey(edge.from)];
        final dstId = nameToCharId[normKey(edge.to)];
        if (srcId == null || dstId == null || srcId == dstId) continue;
        final pairKey = srcId.compareTo(dstId) <= 0
            ? '$srcId||$dstId'
            : '$dstId||$srcId';
        if (!insertedRelPairs.add(pairKey)) continue;
        await db.upsertCharacterRelation(
          CharacterRelationsCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            sourceCharacterId: srcId,
            targetCharacterId: dstId,
            relationType: Value(edge.relationType),
            label: edge.label.isNotEmpty ? edge.label : edge.relationType,
            description: Value(edge.description),
            strength: Value(edge.strength.clamp(1, 5)),
            line: Value(edge.line),
            evolutionJson: Value(
              jsonEncode([for (final e in edge.evolution) e.toJson()]),
            ),
            firstChapterOrder: Value(edge.firstChapter),
            lastChapterOrder: Value(edge.lastChapter),
            updatedAt: now,
          ),
        );
      }
      for (final c in profile.characters) {
        final srcId = nameToCharId[normKey(c.name)];
        if (srcId == null) continue;
        for (final rel in c.relationships) {
          final dstId = nameToCharId[normKey(rel.target)];
          if (dstId == null || srcId == dstId) continue;
          final pairKey = srcId.compareTo(dstId) <= 0
              ? '$srcId||$dstId'
              : '$dstId||$srcId';
          if (!insertedRelPairs.add(pairKey)) continue;
          await db.upsertCharacterRelation(
            CharacterRelationsCompanion.insert(
              id: uuid.v4(),
              novelId: novelId,
              sourceCharacterId: srcId,
              targetCharacterId: dstId,
              relationType: Value(normalizeRelationType(rel.relation)),
              label: rel.relation.isNotEmpty ? rel.relation : '关联',
              updatedAt: now,
            ),
          );
        }
      }

      // 3. 写入世界观条目（优先使用精扫产出的 Lorebook keywords）
      for (var i = 0; i < profile.worldbuilding.length; i++) {
        final w = profile.worldbuilding[i];
        final keywords = w.keywords.isNotEmpty
            ? w.keywords
            : _extractWorldKeywords(w.name);
        await db.upsertWorldEntry(
          WorldEntriesCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            category: mappedWorldCategory(w.category),
            name: w.name,
            content: Value(w.content),
            keywordsJson: Value(jsonEncode(keywords)),
            isAlwaysOn: const Value(false),
            sortOrder: Value(i),
          ),
        );
      }

      // 4. 无损写入伏笔台账（含 status / resolvedChapterOrder / involvedCharactersJson / payoffDetail）
      final clueTitleToId = <String, String>{};
      for (final t in profile.openThreads) {
        final fsId = uuid.v4();
        await db.upsertForeshadowing(
          ForeshadowingsCompanion.insert(
            id: fsId,
            novelId: novelId,
            title: t.title,
            detail: Value(t.detail),
            plantedVolumeIndex: Value(t.plantedChapter != null ? 1 : null),
            plantedChapterOrder: Value(t.plantedChapter),
            status: Value(t.status),
            involvedCharactersJson: Value(jsonEncode(t.involvedCharacters)),
            resolvedChapterOrder: Value(t.resolvedChapter),
            payoffDetail: Value(t.payoffDetail),
            createdAt: now,
          ),
        );
        clueTitleToId[normKey(t.title)] = fsId;
      }

      // 5. 无损写入故事时间线表（自动关联原作章 ID 与伏笔 ID）
      final numRe = RegExp(r'\d+');
      for (var i = 0; i < profile.timeline.length; i++) {
        final ev = profile.timeline[i];
        final chNo =
            ev.chapterStart ??
            int.tryParse(numRe.firstMatch(ev.chapterRange ?? '')?.group(0) ?? '');
        final linkedChapterId =
            chNo != null ? origChapterIdByOrder[chNo] : null;
        final linkedFsIds = <String>[
          for (final title in ev.linkedClueTitles)
            if (clueTitleToId[normKey(title)] != null)
              clueTitleToId[normKey(title)]!,
        ];
        final shortTitle = ev.summary.length <= 22
            ? ev.summary
            : '${ev.summary.substring(0, 21)}…';
        await db.upsertTimelineEvent(
          TimelineEventsCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            volumeId: Value(linkedChapterId != null ? origVolId : null),
            chapterId: Value(linkedChapterId),
            chapterOrder: Value(chNo),
            chapterRange: Value(ev.chapterRange),
            inWorldTime: Value(ev.inWorldTime),
            phase: Value(ev.phase),
            title: shortTitle,
            summary: Value(ev.summary),
            participantsJson: Value(jsonEncode(ev.participants)),
            linkedForeshadowingIdsJson: Value(jsonEncode(linkedFsIds)),
            importance: Value(ev.importance.raw),
            sortOrder: Value(i),
            createdAt: now,
          ),
        );
      }

      await db.upsertChatThread(
        ChatThreadsCompanion.insert(
          id: uuid.v4(),
          novelId: novelId,
          purpose: 'creation',
          skipsClarification: const Value(true),
          createdAt: now,
        ),
      );
    });

    return novelId;
  }

  static String mappedWorldCategory(String raw) {
    if (raw.contains('地点') || raw.contains('场景') || raw.contains('地理')) {
      return '地点';
    }
    if (raw.contains('势力') || raw.contains('组织') || raw.contains('阵营')) {
      return '势力';
    }
    if (raw.contains('规则') || raw.contains('体系') || raw.contains('设定')) {
      return '规则';
    }
    if (raw.contains('物品') || raw.contains('道具') || raw.contains('器物')) {
      return '物品';
    }
    return '其他';
  }

  static String _buildOriginalVolumeOutline(SourceNovelProfileData profile) {
    final sections = <String>[];
    if (profile.timeline.isNotEmpty) {
      final lines = profile.timeline.map((ev) {
        final prefix = [
          if ((ev.phase ?? '').trim().isNotEmpty) ev.phase!.trim(),
          if ((ev.chapterRange ?? '').trim().isNotEmpty)
            ev.chapterRange!.trim(),
        ].join(' · ');
        return prefix.isEmpty ? '- ${ev.summary}' : '- [$prefix] ${ev.summary}';
      });
      sections.add('【原作剧情阶段时间线】\n${lines.join('\n')}');
    }
    if (profile.activeArcs.isNotEmpty) {
      sections.add(
        '【断更处进行中主线】\n${profile.activeArcs.map((a) => '- $a').join('\n')}',
      );
    }
    return sections.join('\n\n');
  }

  static Map<int, List<String>> _buildChapterOutlineAnchors(
    SourceNovelProfileData profile,
    int? upTo,
  ) {
    final map = <int, List<String>>{};
    if (upTo == null || upTo <= 0) return map;
    final numRe = RegExp(r'\d+');
    for (final ev in profile.timeline) {
      final range = ev.chapterRange ?? '';
      final m = numRe.firstMatch(range);
      if (m == null) continue;
      final chNo = int.tryParse(m.group(0)!);
      if (chNo == null || chNo < 1 || chNo > upTo) continue;
      final label = [
        if ((ev.phase ?? '').trim().isNotEmpty) ev.phase!.trim(),
        if (range.trim().isNotEmpty) range.trim(),
      ].join(' · ');
      final line = label.isEmpty ? ev.summary : '【$label】${ev.summary}';
      map.putIfAbsent(chNo, () => []).add(line);
    }
    return map;
  }

  static List<String> _extractWorldKeywords(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return const [];
    final tokens = <String>{clean};
    for (final part in clean.split(RegExp(r'[·・/／\s()（）\[\]【】「」《》:：\-—]+'))) {
      final t = part.trim();
      if (t.length >= 2) tokens.add(t);
    }
    return tokens.take(6).toList();
  }
}

final sourceAndStyleBridgeProvider = Provider<SourceAndStyleBridge>((ref) {
  return SourceAndStyleBridge(
    db: ref.watch(appDatabaseProvider),
    blobs: ref.watch(blobStoreProvider),
  );
});
