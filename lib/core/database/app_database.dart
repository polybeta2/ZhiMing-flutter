import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/api_key_vault.dart';
import '../storage/blob_store.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Novels,
    Volumes,
    Chapters,
    ChapterSummaries,
    ChapterSnapshots,
    Characters,
    WorldEntries,
    Foreshadowings,
    ChatThreads,
    ChatMessages,
    Providers,
    StyleProfiles,
    SourceProfiles,
    PromptOverrides,
    PromptTagCategories,
    CreationSessionCaches,
    StyleDistillCaches,
    ScanTasks,
    ScanChunks,
    ScanReduces,
    ScanMetas,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(worldEntries, worldEntries.keywordsJson);
        await m.addColumn(worldEntries, worldEntries.isAlwaysOn);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final support = await getApplicationSupportDirectory();
      final dir = Directory(p.join(support.path, 'zhiming'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, 'zhiming.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // ---- Novels ----

  Stream<List<Novel>> watchNovels() {
    return (select(
      novels,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Stream<Novel?> watchNovel(String id) {
    return (select(novels)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<Novel?> getNovel(String id) {
    return (select(novels)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertNovel(NovelsCompanion data) {
    return into(novels).insertOnConflictUpdate(data);
  }

  Future<void> deleteNovelCascade(String novelId) {
    return (delete(novels)..where((t) => t.id.equals(novelId))).go();
  }

  // ---- Volumes & Chapters ----

  Stream<List<Volume>> watchVolumes(String novelId) {
    return (select(volumes)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<List<Volume>> getVolumes(String novelId) {
    return (select(volumes)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> upsertVolume(VolumesCompanion data) {
    return into(volumes).insertOnConflictUpdate(data);
  }

  Future<void> deleteVolume(String volumeId) {
    return (delete(volumes)..where((t) => t.id.equals(volumeId))).go();
  }

  Stream<List<Chapter>> watchChaptersByVolume(String volumeId) {
    return (select(chapters)
          ..where((t) => t.volumeId.equals(volumeId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<List<Chapter>> getChaptersByVolume(String volumeId) {
    return (select(chapters)
          ..where((t) => t.volumeId.equals(volumeId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Stream<Chapter?> watchChapter(String chapterId) {
    return (select(
      chapters,
    )..where((t) => t.id.equals(chapterId))).watchSingleOrNull();
  }

  Future<Chapter?> getChapter(String chapterId) {
    return (select(
      chapters,
    )..where((t) => t.id.equals(chapterId))).getSingleOrNull();
  }

  Future<void> upsertChapter(ChaptersCompanion data) {
    return into(chapters).insertOnConflictUpdate(data);
  }

  Future<void> updateChapterContent(
    String chapterId, {
    required String content,
    required DateTime updatedAt,
  }) async {
    await (update(chapters)..where((t) => t.id.equals(chapterId))).write(
      ChaptersCompanion(
        content: Value(content),
        wordCount: Value(content.length),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> deleteChapter(String chapterId) {
    return (delete(chapters)..where((t) => t.id.equals(chapterId))).go();
  }

  // ---- Summaries & Snapshots ----

  Stream<ChapterSummary?> watchSummary(String chapterId) {
    return (select(
      chapterSummaries,
    )..where((t) => t.chapterId.equals(chapterId))).watchSingleOrNull();
  }

  Future<ChapterSummary?> getSummary(String chapterId) {
    return (select(
      chapterSummaries,
    )..where((t) => t.chapterId.equals(chapterId))).getSingleOrNull();
  }

  Future<void> upsertSummary(ChapterSummariesCompanion data) {
    return into(chapterSummaries).insertOnConflictUpdate(data);
  }

  Stream<List<ChapterSnapshot>> watchSnapshots(String chapterId) {
    return (select(chapterSnapshots)
          ..where((t) => t.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)]))
        .watch();
  }

  Future<List<ChapterSnapshot>> getSnapshots(String chapterId) {
    return (select(chapterSnapshots)
          ..where((t) => t.chapterId.equals(chapterId))
          ..orderBy([(t) => OrderingTerm.desc(t.versionNumber)]))
        .get();
  }

  Future<void> insertSnapshot(ChapterSnapshotsCompanion data) {
    return into(chapterSnapshots).insert(data);
  }

  // ---- Characters, World, Foreshadowing ----

  Stream<List<Character>> watchCharacters(String novelId) {
    return (select(characters)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<List<Character>> getCharacters(String novelId) {
    return (select(characters)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> upsertCharacter(CharactersCompanion data) {
    return into(characters).insertOnConflictUpdate(data);
  }

  Future<void> deleteCharacter(String id) {
    return (delete(characters)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<WorldEntry>> watchWorldEntries(String novelId) {
    return (select(worldEntries)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch();
  }

  Future<List<WorldEntry>> getWorldEntries(String novelId) {
    return (select(worldEntries)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<void> upsertWorldEntry(WorldEntriesCompanion data) {
    return into(worldEntries).insertOnConflictUpdate(data);
  }

  Future<void> deleteWorldEntry(String id) {
    return (delete(worldEntries)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Foreshadowing>> watchForeshadowings(String novelId) {
    return (select(foreshadowings)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Foreshadowing>> getForeshadowings(String novelId) {
    return (select(foreshadowings)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> upsertForeshadowing(ForeshadowingsCompanion data) {
    return into(foreshadowings).insertOnConflictUpdate(data);
  }

  Future<void> deleteForeshadowing(String id) {
    return (delete(foreshadowings)..where((t) => t.id.equals(id))).go();
  }

  // ---- Chat Threads & Messages ----

  Stream<List<ChatThread>> watchChatThreads(String novelId) {
    return (select(chatThreads)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<ChatThread>> getChatThreads(String novelId) {
    return (select(chatThreads)
          ..where((t) => t.novelId.equals(novelId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> upsertChatThread(ChatThreadsCompanion data) {
    return into(chatThreads).insertOnConflictUpdate(data);
  }

  Stream<List<ChatMessage>> watchChatMessages(String threadId) {
    return (select(chatMessages)
          ..where((t) => t.threadId.equals(threadId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<ChatMessage>> getChatMessages(String threadId) {
    return (select(chatMessages)
          ..where((t) => t.threadId.equals(threadId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> insertChatMessage(ChatMessagesCompanion data) {
    return into(chatMessages).insertOnConflictUpdate(data);
  }

  Future<void> deleteChatMessage(String id) {
    return (delete(chatMessages)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearChatMessages(String threadId) {
    return (delete(chatMessages)..where((t) => t.threadId.equals(threadId))).go();
  }

  // ---- Providers ----

  Stream<List<ProviderRecord>> watchProviders() {
    return (select(
      providers,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  Future<List<ProviderRecord>> getProviders() {
    return (select(
      providers,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
  }

  Future<void> upsertProvider(ProvidersCompanion data) {
    return into(providers).insertOnConflictUpdate(data);
  }

  Future<void> makeDefaultProvider(String providerId) async {
    await transaction(() async {
      await update(providers).write(const ProvidersCompanion(isDefault: Value(false)));
      await (update(providers)..where((t) => t.id.equals(providerId)))
          .write(const ProvidersCompanion(isDefault: Value(true)));
    });
  }

  /// 删除提供商并同步清理密钥；若删掉的是默认项则自动顺延下一个为默认。
  Future<void> deleteProviderWithKey(
    String providerId,
    ApiKeyVault vault,
  ) async {
    final target = await (select(
      providers,
    )..where((t) => t.id.equals(providerId))).getSingleOrNull();
    if (target == null) return;
    await transaction(() async {
      await (delete(providers)..where((t) => t.id.equals(providerId))).go();
      final rest = await getProviders();
      if (rest.isNotEmpty && !rest.any((e) => e.isDefault)) {
        await (update(providers)..where((t) => t.id.equals(rest.first.id)))
            .write(const ProvidersCompanion(isDefault: Value(true)));
      }
    });
    await vault.delete(target.apiKeyId);
  }

  // ---- Style Profiles ----

  Stream<List<StyleProfile>> watchStyleProfiles() {
    return (select(
      styleProfiles,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();
  }

  Future<List<StyleProfile>> getStyleProfiles() {
    return (select(
      styleProfiles,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Future<void> upsertStyleProfile(StyleProfilesCompanion data) {
    return into(styleProfiles).insertOnConflictUpdate(data);
  }

  /// 删除文风档案并解绑引用作品，避免悬挂 UUID。
  Future<void> deleteStyleProfileUnbinding(String profileId) async {
    await transaction(() async {
      await (delete(
        styleProfiles,
      )..where((t) => t.id.equals(profileId))).go();
      await (update(novels)
            ..where((t) => t.activeStyleProfileId.equals(profileId)))
          .write(const NovelsCompanion(activeStyleProfileId: Value(null)));
    });
  }

  // ---- Source Profiles & Scan Checkpoints ----

  Stream<List<SourceProfile>> watchSourceProfiles() {
    return (select(
      sourceProfiles,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<List<SourceProfile>> getSourceProfiles() {
    return (select(
      sourceProfiles,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  Future<void> upsertSourceProfile(SourceProfilesCompanion data) {
    return into(sourceProfiles).insertOnConflictUpdate(data);
  }

  /// 修复原版 B2 孤儿泄漏：删除原作档案时同步解绑作品 + 清理扫描表 + 删除大文本边车。
  Future<void> deleteSourceProfileCompletely(
    String profileId,
    BlobStore blobs,
  ) async {
    await transaction(() async {
      await (delete(
        sourceProfiles,
      )..where((t) => t.id.equals(profileId))).go();
      await (update(novels)..where((t) => t.sourceProfileId.equals(profileId)))
          .write(const NovelsCompanion(sourceProfileId: Value(null)));
      await clearScanCheckpoints(profileId);
    });
    await blobs.delete(BlobKinds.continuation, profileId);
    await blobs.delete(BlobKinds.scanTask, profileId);
  }

  Stream<List<ScanTask>> watchScanTasks() {
    return (select(
      scanTasks,
    )..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();
  }

  Future<void> upsertScanTask(ScanTasksCompanion data) {
    return into(scanTasks).insertOnConflictUpdate(data);
  }

  Future<void> clearScanCheckpoints(String profileId) async {
    await (delete(scanTasks)..where((t) => t.profileId.equals(profileId))).go();
    await (delete(
      scanChunks,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (delete(
      scanReduces,
    )..where((t) => t.profileId.equals(profileId))).go();
    await (delete(scanMetas)..where((t) => t.profileId.equals(profileId))).go();
  }

  Future<void> markScanChunk(ScanChunksCompanion data) {
    return into(scanChunks).insertOnConflictUpdate(data);
  }

  Future<Set<int>> getDoneScanChunkIndexes(String profileId) async {
    final rows =
        await (select(scanChunks)..where(
              (t) => t.profileId.equals(profileId) & t.status.equals('done'),
            ))
            .get();
    return rows.map((e) => e.idx).toSet();
  }

  Future<List<ScanChunk>> getDoneScanChunks(String profileId) {
    return (select(scanChunks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.status.equals('done') &
                t.payloadJson.isNotNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.idx)]))
        .get();
  }

  Future<void> saveScanReduce(String profileId, int seq, String summaryText) {
    return into(scanReduces).insertOnConflictUpdate(
      ScanReducesCompanion.insert(
        profileId: profileId,
        seq: seq,
        summaryText: summaryText,
      ),
    );
  }

  Future<List<String>> loadScanReduces(String profileId) async {
    final rows =
        await (select(scanReduces)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
            .get();
    return rows.map((e) => e.summaryText).toList();
  }

  Future<Map<int, String>> loadScanReduceMap(String profileId) async {
    final rows =
        await (select(scanReduces)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
            .get();
    return {for (final r in rows) r.seq: r.summaryText};
  }

  Future<int> getMaxReduceSeq(String profileId) async {
    final rows =
        await (select(scanReduces)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([(t) => OrderingTerm.desc(t.seq)])
              ..limit(1))
            .get();
    return rows.isEmpty ? -1 : rows.first.seq;
  }

  Future<int> getReducedUpto(String profileId) async {
    final row =
        await (select(scanMetas)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.metaKey.equals('reduced_upto'),
            ))
            .getSingleOrNull();
    return row?.metaValue ?? -1;
  }

  /// 单调递增推进归并水位
  Future<void> advanceReducedUpto(String profileId, int pos) async {
    final current = await getReducedUpto(profileId);
    if (pos <= current) return;
    await into(scanMetas).insertOnConflictUpdate(
      ScanMetasCompanion.insert(
        profileId: profileId,
        metaKey: 'reduced_upto',
        metaValue: pos,
      ),
    );
  }

  // ---- Prompt Overrides, Tags & Session Caches ----

  Future<Map<String, String>> loadPromptOverrides() async {
    final rows = await select(promptOverrides).get();
    return {for (final r in rows) r.promptId: r.content};
  }

  Future<void> upsertPromptOverride(String promptId, String content) {
    return into(promptOverrides).insertOnConflictUpdate(
      PromptOverridesCompanion.insert(
        promptId: promptId,
        content: content,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deletePromptOverride(String promptId) {
    return (delete(
      promptOverrides,
    )..where((t) => t.promptId.equals(promptId))).go();
  }

  Future<List<PromptTagCategory>> loadPromptTagCategories() {
    return (select(
      promptTagCategories,
    )..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
  }

  Future<void> replacePromptTagCategories(
    List<PromptTagCategoriesCompanion> items,
  ) async {
    await transaction(() async {
      await delete(promptTagCategories).go();
      for (final item in items) {
        await into(promptTagCategories).insert(item);
      }
    });
  }

  Future<void> saveCreationCache(String threadId, String payloadJson) {
    return into(creationSessionCaches).insertOnConflictUpdate(
      CreationSessionCachesCompanion.insert(
        threadId: threadId,
        payloadJson: payloadJson,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> loadCreationCache(String threadId) async {
    final row = await (select(
      creationSessionCaches,
    )..where((t) => t.threadId.equals(threadId))).getSingleOrNull();
    return row?.payloadJson;
  }

  Future<void> deleteCreationCache(String threadId) {
    return (delete(
      creationSessionCaches,
    )..where((t) => t.threadId.equals(threadId))).go();
  }

  Future<void> saveStyleDistillCache(String payloadJson, {String slot = 'latest'}) {
    return into(styleDistillCaches).insertOnConflictUpdate(
      StyleDistillCachesCompanion.insert(
        slot: slot,
        payloadJson: payloadJson,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<String?> loadStyleDistillCache({String slot = 'latest'}) async {
    final row = await (select(
      styleDistillCaches,
    )..where((t) => t.slot.equals(slot))).getSingleOrNull();
    return row?.payloadJson;
  }

  Future<void> deleteStyleDistillCache({String slot = 'latest'}) {
    return (delete(
      styleDistillCaches,
    )..where((t) => t.slot.equals(slot))).go();
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
