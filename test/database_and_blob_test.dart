import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/security/api_key_vault.dart';
import 'package:zhiming/core/storage/blob_store.dart';

void main() {
  group('AppDatabase schema & cascading deletes', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('deleting a novel cascades volumes, chapters, snapshots, chats & cache', () async {
      final now = DateTime.now();
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '雾港来信',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertVolume(
        VolumesCompanion.insert(
          id: 'v1',
          novelId: 'n1',
          name: '第一卷',
          sortOrder: 0,
        ),
      );
      await db.upsertChapter(
        ChaptersCompanion.insert(
          id: 'c1',
          volumeId: 'v1',
          title: '第一章',
          sortOrder: 0,
          updatedAt: now,
        ),
      );
      await db.upsertSummary(
        ChapterSummariesCompanion.insert(
          chapterId: 'c1',
          summaryText: '摘要',
          updatedAt: now,
        ),
      );
      await db.insertSnapshot(
        ChapterSnapshotsCompanion.insert(
          id: 'snap1',
          chapterId: 'c1',
          versionNumber: 1,
          content: '初稿',
          triggerType: 'manual_save',
          createdAt: now,
        ),
      );
      await db.upsertCharacter(
        CharactersCompanion.insert(id: 'ch1', novelId: 'n1', name: '沈屿'),
      );
      await db.upsertWorldEntry(
        WorldEntriesCompanion.insert(
          id: 'w1',
          novelId: 'n1',
          category: '地点',
          name: '雾港',
        ),
      );
      await db.upsertForeshadowing(
        ForeshadowingsCompanion.insert(
          id: 'f1',
          novelId: 'n1',
          title: '旧灯塔钥匙',
          createdAt: now,
        ),
      );
      await db.upsertChatThread(
        ChatThreadsCompanion.insert(
          id: 't1',
          novelId: 'n1',
          purpose: 'creation',
          createdAt: now,
        ),
      );
      await db.insertChatMessage(
        ChatMessagesCompanion.insert(
          id: 'm1',
          threadId: 't1',
          role: 'user',
          content: '创意',
          createdAt: now,
        ),
      );
      await db.saveCreationCache('t1', '{"phase":"collecting"}');

      await db.deleteNovelCascade('n1');

      expect(await db.getNovel('n1'), isNull);
      expect(await db.getVolumes('n1'), isEmpty);
      expect(await db.getChaptersByVolume('v1'), isEmpty);
      expect(await db.getSummary('c1'), isNull);
      expect(await db.getSnapshots('c1'), isEmpty);
      expect(await db.getCharacters('n1'), isEmpty);
      expect(await db.getWorldEntries('n1'), isEmpty);
      expect(await db.getForeshadowings('n1'), isEmpty);
      expect(await db.getChatThreads('n1'), isEmpty);
      expect(await db.getChatMessages('t1'), isEmpty);
      expect(await db.loadCreationCache('t1'), isNull);
    });

    test('deleteProviderWithKey promotes fallback default and cleans vault', () async {
      final vault = InMemoryApiKeyVault();
      final now = DateTime.now();
      await vault.save('k1', 'secret-1');
      await vault.save('k2', 'secret-2');
      await db.upsertProvider(
        ProvidersCompanion.insert(
          id: 'p1',
          name: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com/v1',
          apiKeyId: 'k1',
          modelName: 'deepseek-chat',
          isDefault: const Value(true),
          createdAt: now,
        ),
      );
      await db.upsertProvider(
        ProvidersCompanion.insert(
          id: 'p2',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKeyId: 'k2',
          modelName: 'gpt-4o',
          createdAt: now.add(const Duration(seconds: 1)),
        ),
      );

      await db.deleteProviderWithKey('p1', vault);

      expect(await vault.load('k1'), isNull);
      expect(await vault.load('k2'), 'secret-2');
      final rest = await db.getProviders();
      expect(rest.length, 1);
      expect(rest.first.id, 'p2');
      expect(rest.first.isDefault, isTrue);
    });

    test('deleteSourceProfileCompletely unbinds novels, clears scan tables and deletes blobs', () async {
      final tempDir = await Directory.systemTemp.createTemp('zm_blob_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final blobs = BlobStore(baseDirOverride: tempDir);
      final now = DateTime.now();

      await db.upsertSourceProfile(
        SourceProfilesCompanion.insert(
          id: 'sp1',
          title: '斗罗大陆',
          payloadJson: '{}',
          createdAt: now,
        ),
      );
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '同人作品',
          sourceProfileId: const Value('sp1'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.upsertScanTask(
        ScanTasksCompanion.insert(
          profileId: 'sp1',
          title: '斗罗大陆',
          mode: 'fast',
          batchSize: 1,
          totalChunks: 10,
          providerName: 'DS',
          providerBaseUrl: 'https://example.com',
          providerModel: 'm',
          providerKeyId: 'k',
          startedAt: now,
        ),
      );
      await db.markScanChunk(
        ScanChunksCompanion.insert(
          profileId: 'sp1',
          idx: 0,
          status: 'done',
          payloadJson: const Value('{"ok":true}'),
          updatedAt: now,
        ),
      );
      await db.saveScanReduce('sp1', 0, 'stage 0');
      await db.advanceReducedUpto('sp1', 5);
      await db.advanceReducedUpto('sp1', 3); // monotonic: must stay 5
      expect(await db.getReducedUpto('sp1'), 5);

      await blobs.saveText(BlobKinds.continuation, 'sp1', '原文正文');
      await blobs.saveText(BlobKinds.scanTask, 'sp1', '扫描原文');
      expect(await blobs.exists(BlobKinds.continuation, 'sp1'), isTrue);

      await db.deleteSourceProfileCompletely('sp1', blobs);

      expect((await db.getNovel('n1'))!.sourceProfileId, isNull);
      expect(await db.getDoneScanChunkIndexes('sp1'), isEmpty);
      expect(await db.loadScanReduces('sp1'), isEmpty);
      expect(await db.getReducedUpto('sp1'), -1);
      expect(await blobs.exists(BlobKinds.continuation, 'sp1'), isFalse);
      expect(await blobs.exists(BlobKinds.scanTask, 'sp1'), isFalse);
    });
  });

  group('BlobStore tail reader', () {
    test('aligns tail read to chapter marker without loading whole file', () async {
      final tempDir = await Directory.systemTemp.createTemp('zm_tail_test_');
      addTearDown(() => tempDir.delete(recursive: true));
      final blobs = BlobStore(baseDirOverride: tempDir);

      final content = '${'前文填充' * 400}\n第10章 雨夜\n门外传来脚步声。';
      await blobs.saveText(BlobKinds.continuation, 'p1', content);

      final tail = await blobs.loadTailAligned(
        BlobKinds.continuation,
        'p1',
        maxChars: 120,
      );
      expect(tail, isNotNull);
      expect(tail, startsWith('……（前文略）\n第10章 雨夜'));
      expect(tail, contains('门外传来脚步声。'));
    });
  });
}
