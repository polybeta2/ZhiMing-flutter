import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zhiming/core/storage/blob_store.dart';

void main() {
  group('BlobStore temporary removal', () {
    late Directory tempDir;
    late BlobStore blobs;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('zm_blob_transaction_');
      blobs = BlobStore(baseDirOverride: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('restores all staged files when the database action fails', () async {
      await blobs.saveText(BlobKinds.continuation, 'profile-1', '原作正文');
      await blobs.saveText(BlobKinds.scanTask, 'profile-1', '扫描输入');

      await expectLater(
        blobs.withTemporarilyRemoved([
          (BlobKinds.continuation, 'profile-1'),
          (BlobKinds.scanTask, 'profile-1'),
        ], () async => throw StateError('database transaction failed')),
        throwsA(isA<StateError>()),
      );

      expect(await blobs.loadText(BlobKinds.continuation, 'profile-1'), '原作正文');
      expect(await blobs.loadText(BlobKinds.scanTask, 'profile-1'), '扫描输入');
    });

    test('removes staged files after the database action succeeds', () async {
      await blobs.saveText(BlobKinds.continuation, 'profile-2', '原作正文');
      await blobs.saveText(BlobKinds.scanTask, 'profile-2', '扫描输入');

      await blobs.withTemporarilyRemoved([
        (BlobKinds.continuation, 'profile-2'),
        (BlobKinds.scanTask, 'profile-2'),
      ], () async {});

      expect(await blobs.exists(BlobKinds.continuation, 'profile-2'), isFalse);
      expect(await blobs.exists(BlobKinds.scanTask, 'profile-2'), isFalse);
    });
  });
}
