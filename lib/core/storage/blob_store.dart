import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 受控大文本边车存储（替代原版散落的 continuations/ 与 scan_tasks/ 目录）。
/// 多 MB 原作/续写正文不塞入主库，统一落盘在 `AppSupport/zhiming/blobs/<kind>/<id>.txt`，
/// 删除对应数据库记录时同步清理，杜绝孤儿文件泄漏。
class BlobStore {
  BlobStore({this.baseDirOverride});

  final Directory? baseDirOverride;

  Future<Directory> _dirFor(String kind) async {
    final base = baseDirOverride ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'zhiming', 'blobs', kind));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String kind, String id) async {
    final dir = await _dirFor(kind);
    return File(p.join(dir.path, '$id.txt'));
  }

  Future<void> saveText(String kind, String id, String text) async {
    final file = await _fileFor(kind, id);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename(file.path);
  }

  Future<String?> loadText(String kind, String id) async {
    final file = await _fileFor(kind, id);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  Future<bool> exists(String kind, String id) async {
    final file = await _fileFor(kind, id);
    return file.exists();
  }

  Future<void> delete(String kind, String id) async {
    final file = await _fileFor(kind, id);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// 读取大文本尾部 maxChars 字符并尝试对齐到章节标记行起点（续写文风锚点专用）。
  /// 只从文件末尾按字节读取，避免整本数 MB 原文载入内存。
  Future<String?> loadTailAligned(
    String kind,
    String id, {
    required int maxChars,
  }) async {
    final file = await _fileFor(kind, id);
    if (!await file.exists()) return null;
    final length = await file.length();
    final byteCap = maxChars * 4 + 64;

    String rawTail;
    if (length > byteCap) {
      final raf = await file.open();
      try {
        await raf.setPosition(length - byteCap);
        final bytes = await raf.read(byteCap);
        var decoded = utf8.decode(bytes, allowMalformed: true);
        while (decoded.startsWith('\uFFFD')) {
          decoded = decoded.substring(1);
        }
        rawTail = decoded.length > maxChars
            ? decoded.substring(decoded.length - maxChars)
            : decoded;
      } finally {
        await raf.close();
      }
    } else {
      final full = await file.readAsString();
      if (full.length <= maxChars) return full;
      rawTail = full.substring(full.length - maxChars);
    }

    final lines = const LineSplitter().convert(rawTail);
    for (var i = 0; i < lines.length; i++) {
      if (_looksLikeChapterMarker(lines[i])) {
        return '……（前文略）\n${lines.sublist(i).join('\n')}';
      }
    }
    return '……（前文略）\n$rawTail';
  }

  static bool _looksLikeChapterMarker(String line) {
    final t = line.trim();
    if (t.isEmpty) return false;
    return t.startsWith('第') ||
        t.startsWith('Chapter') ||
        t.startsWith('序章') ||
        t.startsWith('楔子') ||
        t.startsWith('尾声');
  }
}

abstract final class BlobKinds {
  static const String continuation = 'continuations';
  static const String scanTask = 'scan_tasks';
}

final blobStoreProvider = Provider<BlobStore>((ref) => BlobStore());
