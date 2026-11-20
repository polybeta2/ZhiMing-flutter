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
      if (upTo != null && rawSource != null && rawSource.isNotEmpty) {
        final origVolId = uuid.v4();
        await db.upsertVolume(
          VolumesCompanion.insert(
            id: origVolId,
            novelId: novelId,
            name: '原作（$upTo 章）',
            sortOrder: nextVolOrder++,
          ),
        );
        final chapters = StyleChapterSampler.split(rawSource).take(upTo);
        var order = 1;
        for (final ch in chapters) {
          final chTitle = ch.marker.trim().isNotEmpty
              ? ch.marker.trim()
              : '第$order章';
          final cleanBody = NovelTextCleaner.cleanChapterBody(ch.body);
          await db.upsertChapter(
            ChaptersCompanion.insert(
              id: uuid.v4(),
              volumeId: origVolId,
              title: chTitle,
              content: Value(cleanBody),
              wordCount: Value(cleanBody.length),
              isOriginal: const Value(true),
              sortOrder: order++,
              updatedAt: now,
            ),
          );
        }
      }

      await db.upsertVolume(
        VolumesCompanion.insert(
          id: uuid.v4(),
          novelId: novelId,
          name: '第一卷',
          sortOrder: nextVolOrder,
        ),
      );

      for (var i = 0; i < profile.characters.length; i++) {
        final c = profile.characters[i];
        final bg = [
          if (c.oneLine != null && c.oneLine!.isNotEmpty) c.oneLine!,
          if (c.abilities != null && c.abilities!.isNotEmpty) c.abilities!,
        ].join('；');
        await db.upsertCharacter(
          CharactersCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            name: c.name,
            aliasesJson: Value(jsonEncode(c.aliases)),
            appearance: Value(c.appearance ?? ''),
            personality: Value(c.personality ?? ''),
            background: Value(bg),
            physicalState: Value(c.currentState ?? ''),
            sortOrder: Value(i),
          ),
        );
      }

      for (var i = 0; i < profile.worldbuilding.length; i++) {
        final w = profile.worldbuilding[i];
        await db.upsertWorldEntry(
          WorldEntriesCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            category: mappedWorldCategory(w.category),
            name: w.name,
            content: Value(w.content),
            sortOrder: Value(i),
          ),
        );
      }

      for (final t in profile.openThreads) {
        await db.upsertForeshadowing(
          ForeshadowingsCompanion.insert(
            id: uuid.v4(),
            novelId: novelId,
            title: t.title,
            detail: Value(t.detail),
            plantedVolumeIndex: Value(t.plantedChapter != null ? 1 : null),
            plantedChapterOrder: Value(t.plantedChapter),
            status: const Value('open'),
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
}

final sourceAndStyleBridgeProvider = Provider<SourceAndStyleBridge>((ref) {
  return SourceAndStyleBridge(
    db: ref.watch(appDatabaseProvider),
    blobs: ref.watch(blobStoreProvider),
  );
});
