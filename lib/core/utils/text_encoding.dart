import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:fast_gbk/fast_gbk.dart';

/// 跨平台小说 txt 编码自动探测（UTF-8 / UTF-16 LE & BE / GBK·GB18030）+ BOM 剥离。
/// 大文件自动在后台 Isolate 解码，零主线程卡顿。
abstract final class TextEncoding {
  static Future<String> loadFile(String filePath) async {
    return Isolate.run(() {
      final bytes = File(filePath).readAsBytesSync();
      return decodeBytes(bytes);
    });
  }

  static String decodeBytes(Uint8List bytes) {
    if (bytes.isEmpty) return '';

    // 1) UTF-8 BOM
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }

    // 2) UTF-16 LE / BE BOM
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _decodeUtf16(bytes.sublist(2), littleEndian: false);
    }

    // 3) 严格 UTF-8
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      return _stripBom(text);
    } catch (_) {}

    // 4) 回退 GBK / GB18030
    try {
      final text = gbk.decode(bytes, allowMalformed: true);
      return _stripBom(text);
    } catch (_) {
      return _stripBom(utf8.decode(bytes, allowMalformed: true));
    }
  }

  static String _decodeUtf16(Uint8List bytes, {required bool littleEndian}) {
    final len = bytes.length ~/ 2;
    final units = Uint16List(len);
    for (var i = 0; i < len; i++) {
      final b0 = bytes[i * 2];
      final b1 = bytes[i * 2 + 1];
      units[i] = littleEndian ? (b0 | (b1 << 8)) : ((b0 << 8) | b1);
    }
    return _stripBom(String.fromCharCodes(units));
  }

  static String _stripBom(String s) =>
      s.startsWith('\uFEFF') ? s.substring(1) : s;
}
