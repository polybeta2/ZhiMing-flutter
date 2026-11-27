import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhiming/core/database/app_database.dart';
import 'package:zhiming/core/database/novel_repository.dart';
import 'package:zhiming/core/llm/provider_client_factory.dart';
import 'package:zhiming/features/editor/chapter_editor_widget.dart';

class _DelayedChapterDatabase extends AppDatabase {
  _DelayedChapterDatabase() : super(NativeDatabase.memory());

  final Map<String, Completer<Chapter?>> _pending = {};

  @override
  Future<Chapter?> getChapter(String chapterId) =>
      (_pending[chapterId] ??= Completer<Chapter?>()).future;

  void completeChapter(Chapter chapter) =>
      _pending[chapter.id]!.complete(chapter);
}

class _FailOnceSaveRepository extends NovelRepository {
  _FailOnceSaveRepository(super.db);

  final attemptedChapterIds = <String>[];
  var failNextSave = true;

  @override
  Future<void> saveChapterContent({
    required String novelId,
    required String chapterId,
    required String content,
  }) async {
    attemptedChapterIds.add(chapterId);
    if (failNextSave) {
      failNextSave = false;
      throw StateError('simulated storage failure');
    }
    await super.saveChapterContent(
      novelId: novelId,
      chapterId: chapterId,
      content: content,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'late chapter load cannot replace the currently selected chapter',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = _DelayedChapterDatabase();
      addTearDown(db.close);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });
      final now = DateTime(2026, 1, 1);
      final first = Chapter(
        id: 'c1',
        volumeId: 'v1',
        title: '第一章',
        content: '第一章正文',
        sortOrder: 0,
        wordCount: 5,
        isOriginal: false,
        updatedAt: now,
      );
      final second = Chapter(
        id: 'c2',
        volumeId: 'v1',
        title: '第二章',
        content: '第二章正文',
        sortOrder: 1,
        wordCount: 5,
        isOriginal: false,
        updatedAt: now,
      );

      var chapterId = 'c1';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              novelRepositoryProvider.overrideWithValue(NovelRepository(db)),
              defaultProviderProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChapterEditorWidget(novelId: 'n1', chapterId: chapterId),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      chapterId = 'c2';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              novelRepositoryProvider.overrideWithValue(NovelRepository(db)),
              defaultProviderProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChapterEditorWidget(novelId: 'n1', chapterId: chapterId),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      db.completeChapter(second);
      await tester.pump();
      db.completeChapter(first);
      await tester.pump();

      final bodyEditor = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((field) => field.expands);
      expect(bodyEditor.controller!.text, '第二章正文');
    },
  );

  testWidgets(
    'failed autosave stays dirty and retries before switching chapters',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 50));
      });
      final now = DateTime(2026, 1, 1);
      await db.upsertNovel(
        NovelsCompanion.insert(
          id: 'n1',
          title: '测试作品',
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
      for (final (id, order) in [('c1', 0), ('c2', 1)]) {
        await db.upsertChapter(
          ChaptersCompanion.insert(
            id: id,
            volumeId: 'v1',
            title: id,
            content: const Value('原始正文'),
            sortOrder: order,
            updatedAt: now,
          ),
        );
      }
      final repo = _FailOnceSaveRepository(db);
      var chapterId = 'c1';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              novelRepositoryProvider.overrideWithValue(repo),
              defaultProviderProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChapterEditorWidget(novelId: 'n1', chapterId: chapterId),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final bodyEditor = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((field) => field.expands);
      await tester.enterText(find.byWidget(bodyEditor), '修改后的正文');
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      chapterId = 'c2';
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              novelRepositoryProvider.overrideWithValue(repo),
              defaultProviderProvider.overrideWithValue(null),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ChapterEditorWidget(novelId: 'n1', chapterId: chapterId),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();

      expect(repo.attemptedChapterIds, ['c1', 'c1']);
      expect((await db.getChapter('c1'))!.content, '修改后的正文');
      expect((await db.getChapter('c2'))!.content, '原始正文');
    },
  );
}
