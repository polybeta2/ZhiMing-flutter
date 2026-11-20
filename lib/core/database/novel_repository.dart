import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/novel_domain.dart';
import '../../domain/tools/statistics_service.dart';
import '../llm/llm_json_parser.dart';
import '../prompts/prompt_limits.dart';
import '../theme/design_tokens.dart';
import 'app_database.dart';

/// 作品领域仓库：封装增量 SQLite 读写、快照 50 版滚动上限、摘要伏笔提取与序号归一化。
class NovelRepository {
  NovelRepository(this.db);

  final AppDatabase db;
  static const int maxSnapshotsPerChapter = 50;
  static const _uuid = Uuid();

  Future<NovelBundle?> loadBundle(String novelId) async {
    final novel = await db.getNovel(novelId);
    if (novel == null) return null;

    final volumes = await db.getVolumes(novelId);
    final volBundles = <VolumeBundle>[];
    for (final v in volumes) {
      final chs = await db.getChaptersByVolume(v.id);
      final chBundles = <ChapterBundle>[];
      for (final c in chs) {
        final sum = await db.getSummary(c.id);
        chBundles.add(
          ChapterBundle(
            chapter: c,
            volumeId: v.id,
            volumeName: v.name,
            summary: sum,
          ),
        );
      }
      volBundles.add(VolumeBundle(volume: v, chapters: chBundles));
    }

    final chars = await db.getCharacters(novelId);
    final worlds = await db.getWorldEntries(novelId);
    final fs = await db.getForeshadowings(novelId);
    return NovelBundle(
      novel: novel,
      volumes: volBundles,
      characters: chars,
      worldEntries: worlds,
      foreshadowings: fs,
    );
  }

  /// 创建空白作品（默认带第一卷与第一章，开箱即可写作）
  Future<String> createBlankNovel({
    required String title,
    String synopsis = '',
    String? genre,
    String? perspective,
    String? styleGuide,
    String? accentColorHex,
    bool r18Enabled = false,
  }) async {
    final now = DateTime.now();
    final novelId = _uuid.v4();
    final volId = _uuid.v4();
    final chId = _uuid.v4();

    await db.transaction(() async {
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: novelId,
          title: title.trim().isEmpty ? '未命名作品' : title.trim(),
          synopsis: Value(synopsis.trim()),
          genre: Value(_emptyToNull(genre)),
          perspective: Value(_emptyToNull(perspective)),
          styleGuide: Value(_emptyToNull(styleGuide)),
          accentColorHex: Value(
            r18Enabled ? AppTokens.r18AccentHex : accentColorHex,
          ),
          r18Enabled: Value(r18Enabled),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertVolume(
        VolumesCompanion.insert(
          id: volId,
          novelId: novelId,
          name: '第一卷',
          sortOrder: 1,
        ),
      );
      await db.upsertChapter(
        ChaptersCompanion.insert(
          id: chId,
          volumeId: volId,
          title: '第一章',
          sortOrder: 1,
          updatedAt: now,
        ),
      );
    });
    return novelId;
  }

  /// 创建立项对话作品（一句话立项 / 完整思路立项 / 同人立项共用）
  Future<String> createCreationNovel({
    required String title,
    required String brief,
    List<String> enabledTagIds = const [],
    bool r18Enabled = false,
    bool skipsClarification = false,
    String? activeStyleProfileId,
    String? sourceProfileId,
  }) async {
    final now = DateTime.now();
    final novelId = _uuid.v4();
    final threadId = _uuid.v4();

    await db.transaction(() async {
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: novelId,
          title: title.trim().isEmpty ? '新作品立项中' : title.trim(),
          synopsis: Value(brief.trim()),
          enabledTagIdsJson: Value(encodeStringList(enabledTagIds)),
          r18Enabled: Value(r18Enabled),
          accentColorHex: Value(r18Enabled ? AppTokens.r18AccentHex : null),
          activeStyleProfileId: Value(activeStyleProfileId),
          sourceProfileId: Value(sourceProfileId),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertChatThread(
        ChatThreadsCompanion.insert(
          id: threadId,
          novelId: novelId,
          purpose: 'creation',
          skipsClarification: Value(skipsClarification),
          createdAt: now,
        ),
      );
    });
    return novelId;
  }

  Future<bool> hasPendingCreationThread(String novelId) async {
    final threads = await db.getChatThreads(novelId);
    if (!threads.any((t) => t.purpose == 'creation')) return false;
    final vols = await db.getVolumes(novelId);
    final chars = await db.getCharacters(novelId);
    return vols.isEmpty && chars.isEmpty;
  }

  Future<void> touchNovel(String novelId) async {
    await (db.update(db.novels)..where((t) => t.id.equals(novelId))).write(
      NovelsCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> updateNovelMeta(
    String novelId, {
    String? title,
    String? synopsis,
    String? genre,
    String? perspective,
    String? styleGuide,
    String? accentColorHex,
    bool? r18Enabled,
    Value<String?>? activeStyleProfileId,
    Value<String?>? sourceProfileId,
  }) async {
    await (db.update(db.novels)..where((t) => t.id.equals(novelId))).write(
      NovelsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        synopsis: synopsis != null ? Value(synopsis) : const Value.absent(),
        genre: genre != null ? Value(_emptyToNull(genre)) : const Value.absent(),
        perspective: perspective != null
            ? Value(_emptyToNull(perspective))
            : const Value.absent(),
        styleGuide: styleGuide != null
            ? Value(_emptyToNull(styleGuide))
            : const Value.absent(),
        accentColorHex: accentColorHex != null
            ? Value(accentColorHex)
            : const Value.absent(),
        r18Enabled:
            r18Enabled != null ? Value(r18Enabled) : const Value.absent(),
        activeStyleProfileId: activeStyleProfileId ?? const Value.absent(),
        sourceProfileId: sourceProfileId ?? const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // ---- Volumes & Chapters ----

  Future<String> addVolume(String novelId, {String? name}) async {
    final existing = await db.getVolumes(novelId);
    final nextOrder = existing.isEmpty
        ? 1
        : existing.map((v) => v.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final id = _uuid.v4();
    await db.upsertVolume(
      VolumesCompanion.insert(
        id: id,
        novelId: novelId,
        name: (name == null || name.trim().isEmpty)
            ? '第$nextOrder卷'
            : name.trim(),
        sortOrder: nextOrder,
      ),
    );
    await touchNovel(novelId);
    return id;
  }

  Future<void> deleteVolumeAndNormalize(String novelId, String volumeId) async {
    await db.transaction(() async {
      await db.deleteVolume(volumeId);
      final rest = await db.getVolumes(novelId);
      for (var i = 0; i < rest.length; i++) {
        await (db.update(db.volumes)..where((t) => t.id.equals(rest[i].id)))
            .write(VolumesCompanion(sortOrder: Value(i + 1)));
      }
    });
    await touchNovel(novelId);
  }

  Future<void> updateVolumeOutline({
    required String novelId,
    required String volumeId,
    String? name,
    String? outline,
    List<String>? emotionArc,
    List<ConflictRung>? conflictLadder,
    InfoGap? infoGap,
  }) async {
    await (db.update(db.volumes)..where((t) => t.id.equals(volumeId))).write(
      VolumesCompanion(
        name: name != null ? Value(name.trim()) : const Value.absent(),
        outline:
            outline != null ? Value(_emptyToNull(outline)) : const Value.absent(),
        emotionArcJson: emotionArc != null
            ? Value(
                emotionArc.isEmpty ? null : encodeStringList(emotionArc),
              )
            : const Value.absent(),
        conflictLadderJson: conflictLadder != null
            ? Value(ConflictRung.encodeList(conflictLadder))
            : const Value.absent(),
        infoGapJson: infoGap != null
            ? Value(InfoGap.encode(infoGap))
            : const Value.absent(),
      ),
    );
    await touchNovel(novelId);
  }

  Future<String> addChapter(
    String novelId,
    String volumeId, {
    String? title,
    String? detailedOutline,
    List<SceneCard>? sceneCards,
    String content = '',
    bool isOriginal = false,
  }) async {
    final existing = await db.getChaptersByVolume(volumeId);
    final nextOrder = existing.isEmpty
        ? 1
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final id = _uuid.v4();
    await db.upsertChapter(
      ChaptersCompanion.insert(
        id: id,
        volumeId: volumeId,
        title: (title == null || title.trim().isEmpty)
            ? '第$nextOrder章'
            : title.trim(),
        detailedOutline: Value(_emptyToNull(detailedOutline)),
        sceneCardsJson: Value(
          sceneCards == null ? null : SceneCard.encodeList(sceneCards),
        ),
        content: Value(content),
        sortOrder: nextOrder,
        wordCount: Value(content.length),
        isOriginal: Value(isOriginal),
        updatedAt: DateTime.now(),
      ),
    );
    await touchNovel(novelId);
    return id;
  }

  Future<void> deleteChapterAndNormalize(
    String novelId,
    String volumeId,
    String chapterId,
  ) async {
    await db.transaction(() async {
      await db.deleteChapter(chapterId);
      final rest = await db.getChaptersByVolume(volumeId);
      for (var i = 0; i < rest.length; i++) {
        await (db.update(db.chapters)..where((t) => t.id.equals(rest[i].id)))
            .write(ChaptersCompanion(sortOrder: Value(i + 1)));
      }
    });
    await touchNovel(novelId);
  }

  Future<void> updateChapterOutline({
    required String novelId,
    required String chapterId,
    String? title,
    String? detailedOutline,
    List<SceneCard>? sceneCards,
  }) async {
    await (db.update(db.chapters)..where((t) => t.id.equals(chapterId))).write(
      ChaptersCompanion(
        title: title != null ? Value(title.trim()) : const Value.absent(),
        detailedOutline: detailedOutline != null
            ? Value(_emptyToNull(detailedOutline))
            : const Value.absent(),
        sceneCardsJson: sceneCards != null
            ? Value(SceneCard.encodeList(sceneCards))
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await touchNovel(novelId);
  }

  /// 增量更新单章正文（修复 B1：绝不整库重写）+ 自动维护今日字数统计基线
  Future<void> saveChapterContent({
    required String novelId,
    required String chapterId,
    required String content,
  }) async {
    final now = DateTime.now();
    await ensureDailyStatsBaseline(novelId);
    await db.updateChapterContent(chapterId, content: content, updatedAt: now);
    await touchNovel(novelId);
  }

  Future<void> ensureDailyStatsBaseline(String novelId) async {
    final novel = await db.getNovel(novelId);
    if (novel == null) return;
    if (!StatisticsService.needsBaselineUpdate(novel.lastStatsDate)) return;
    final bundle = await loadBundle(novelId);
    if (bundle == null) return;
    final total = bundle.allChaptersInOrder.fold<int>(
      0,
      (sum, c) => sum + c.chapter.content.length,
    );
    await (db.update(db.novels)..where((t) => t.id.equals(novelId))).write(
      NovelsCompanion(
        lastStatsDate: Value(StatisticsService.startOfDay(DateTime.now())),
        lastTotalWordCount: Value(total),
      ),
    );
  }

  // ---- Snapshots ----

  Future<void> takeSnapshot({
    required String chapterId,
    required String content,
    required String triggerType,
  }) async {
    await db.transaction(() async {
      final existing = await db.getSnapshots(chapterId);
      final maxVer = existing.isEmpty
          ? 0
          : existing
                .map((s) => s.versionNumber)
                .reduce((a, b) => a > b ? a : b);
      await db.insertSnapshot(
        ChapterSnapshotsCompanion.insert(
          id: _uuid.v4(),
          chapterId: chapterId,
          versionNumber: maxVer + 1,
          content: content,
          triggerType: triggerType,
          createdAt: DateTime.now(),
        ),
      );
      // 保留最近 50 版
      if (existing.length + 1 > maxSnapshotsPerChapter) {
        final orderedAsc = [...existing]
          ..sort((a, b) => a.versionNumber.compareTo(b.versionNumber));
        final overflow = existing.length + 1 - maxSnapshotsPerChapter;
        for (final old in orderedAsc.take(overflow)) {
          await (db.delete(
            db.chapterSnapshots,
          )..where((t) => t.id.equals(old.id))).go();
        }
      }
    });
  }

  /// 回退前先把当前正文存为 'restore' 快照，历史永不丢失
  Future<void> restoreSnapshot({
    required String novelId,
    required String chapterId,
    required ChapterSnapshot snapshot,
  }) async {
    final current = await db.getChapter(chapterId);
    if (current == null) return;
    await takeSnapshot(
      chapterId: chapterId,
      content: current.content,
      triggerType: 'restore',
    );
    await saveChapterContent(
      novelId: novelId,
      chapterId: chapterId,
      content: snapshot.content,
    );
  }

  // ---- Summary & Foreshadowing Extraction ----

  Future<void> applySummaryResult({
    required String novelId,
    required Chapter chapter,
    required SummaryResult result,
  }) async {
    final now = DateTime.now();
    await db.upsertSummary(
      ChapterSummariesCompanion.insert(
        chapterId: chapter.id,
        summaryText: result.summary.trim(),
        keyFactsJson: Value(encodeStringList(result.keyFacts)),
        updatedAt: now,
      ),
    );

    final volumes = await db.getVolumes(novelId);
    final volIdx = volumes.indexWhere((v) => v.id == chapter.volumeId);
    final plantedVol = volIdx >= 0 ? volIdx + 1 : null;

    // 1) 新埋伏笔（单次至多 10 条）
    for (final ext in result.newForeshadowings.take(10)) {
      final title = (ext.title ?? '').trim();
      if (title.isEmpty) continue;
      await db.upsertForeshadowing(
        ForeshadowingsCompanion.insert(
          id: _uuid.v4(),
          novelId: novelId,
          title: _cap(title, PromptLimits.foreshadowTextFieldCap),
          detail: Value(
            _capNullable(ext.detail, PromptLimits.foreshadowTextFieldCap),
          ),
          plantedVolumeIndex: Value(plantedVol),
          plantedChapterOrder: Value(chapter.sortOrder),
          plannedResolve: Value(
            _capNullable(
              ext.plannedResolve,
              PromptLimits.foreshadowTextFieldCap,
            ),
          ),
          createdAt: now,
        ),
      );
    }

    // 2) 疑似回收伏笔标记 suggestedResolved=true（至多 5 条，不自动改 status）
    if (result.resolvedForeshadowingTitles.isNotEmpty) {
      final existing = await db.getForeshadowings(novelId);
      var matched = 0;
      for (final candidate in result.resolvedForeshadowingTitles) {
        if (matched >= 5) break;
        final target = candidate.trim();
        if (target.isEmpty) continue;
        final hit = existing.where((f) {
          return f.status == 'open' &&
              (f.title.contains(target) || target.contains(f.title));
        }).firstOrNull;
        if (hit != null) {
          await (db.update(db.foreshadowings)
                ..where((t) => t.id.equals(hit.id)))
              .write(const ForeshadowingsCompanion(suggestedResolved: Value(true)));
          matched += 1;
        }
      }
    }
    await touchNovel(novelId);
  }

  static String? _emptyToNull(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static String _cap(String text, int max) =>
      text.length > max ? text.substring(0, max) : text;

  static String? _capNullable(String? text, int max) {
    final t = _emptyToNull(text);
    if (t == null) return null;
    return _cap(t, max);
  }
}

final novelRepositoryProvider = Provider<NovelRepository>(
  (ref) => NovelRepository(ref.watch(appDatabaseProvider)),
);

final novelsStreamProvider = StreamProvider<List<Novel>>((ref) {
  return ref.watch(appDatabaseProvider).watchNovels();
});

final novelStreamProvider = StreamProvider.family<Novel?, String>((ref, id) {
  return ref.watch(appDatabaseProvider).watchNovel(id);
});
