import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' as db_lib;
import 'prompt_defaults.dart';
import 'prompt_limits.dart';

class R18ModuleRoute {
  const R18ModuleRoute({
    required this.file,
    required this.title,
    required this.keywords,
  });

  final String file;
  final String title;
  final List<String> keywords;
}

typedef SkillFileLoader = Future<String?> Function(String file, String lang);

class PromptLibraryState {
  const PromptLibraryState({
    this.overrides = const {},
    this.tagCategories = PromptDefaults.defaultTagCategories,
  });

  final Map<String, String> overrides;
  final List<PromptTagCategory> tagCategories;

  String resolvedText(String id) {
    final override = overrides[id];
    if (override != null) return override;
    for (final p in PromptDefaults.builtInPrompts) {
      if (p.id == id) return p.defaultText;
    }
    return '';
  }

  bool isCustomized(String id) => overrides.containsKey(id);

  /// 标签智能注入：仅当已启用且输入命中关键词时拼入，合计 8K 字符熔断。
  String? matchedSupplement(List<String> enabledIds, String input) {
    if (enabledIds.isEmpty || input.isEmpty) return null;
    final enabledSet = enabledIds.toSet();
    final lines = <String>[];
    var used = 0;
    var dropped = 0;

    for (final cat in tagCategories) {
      for (final tag in cat.tags) {
        if (!enabledSet.contains(tag.id)) continue;
        final hit =
            input.contains(tag.name) ||
            tag.keywords.any((k) => k.isNotEmpty && input.contains(k));
        if (!hit) continue;
        final line = '◆ ${tag.name}：${tag.presetText}';
        if (used + line.length > PromptLimits.matchedSupplementCap) {
          dropped += 1;
          continue;
        }
        lines.add(line);
        used += line.length;
      }
    }

    if (lines.isEmpty) return null;
    final buf = StringBuffer()
      ..writeln('【创作方向补充】')
      ..writeln('以下为作者启用的创作方向约束，规划蓝图（题材、人物、世界观、卷章节奏）时必须严格遵循：')
      ..write(lines.join('\n'));
    if (dropped > 0) {
      buf.write(
        '\n\n（另有 $dropped 条命中标签因合计注入量超过 ${PromptLimits.matchedSupplementCap} 字上限，本次未注入）',
      );
    }
    return buf.toString();
  }

  /// 按输入主语言组装 R18 规范（中英严格隔离，核心常驻 + 特化模块按 12K 预算小模块优先装填）。
  Future<String> r18Supplement(
    String input, {
    SkillFileLoader? skillLoader,
  }) async {
    final lang = detectLanguage(input);
    final id = lang == 'en' ? PromptID.r18en : PromptID.r18zh;
    final override = overrides[id];
    if (override != null && override.trim().isNotEmpty) {
      return override;
    }

    final loader = skillLoader ?? defaultAssetSkillLoader;
    var core = await loader('core', lang);
    if (core == null || core.isEmpty) {
      return resolvedText(id);
    }
    core += '\n\n> 以下按本次请求命中的关键词加载对应特化模块。';

    final lowered = input.toLowerCase();
    final hits = <({String file, String title, String text})>[];
    for (final route in r18ModuleRoutes) {
      final matched = route.keywords.any(
        (k) => lowered.contains(k.toLowerCase()),
      );
      if (!matched) continue;
      final text = await loader(route.file, lang);
      if (text == null || text.isEmpty) continue;
      hits.add((file: route.file, title: route.title, text: text));
    }

    hits.sort((a, b) => a.text.length.compareTo(b.text.length));

    var used = core.length;
    final chosen = <String, String>{};
    for (final hit in hits) {
      if (used + hit.text.length > PromptLimits.r18ModuleCharBudget) break;
      used += hit.text.length;
      chosen[hit.file] = hit.text;
    }

    final buf = StringBuffer(core);
    for (final route in r18ModuleRoutes) {
      final text = chosen[route.file];
      if (text == null) continue;
      buf.write('\n\n### § 特化模块：${route.title}\n\n$text');
    }
    return buf.toString();
  }

  static Future<String?> defaultAssetSkillLoader(
    String file,
    String lang,
  ) async {
    try {
      final text = await rootBundle.loadString(
        'assets/skill_packs/fictional-erotica/$lang/$file.md',
      );
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// 占位符渲染
  static String render(String template, Map<String, String> values) {
    var out = template;
    const known = [
      'mode',
      'title',
      'synopsis',
      'styleGuide',
      'styleSample',
      'styleMetrics',
    ];
    for (final key in known) {
      final token = '{$key}';
      if (!out.contains(token)) continue;
      out = out.replaceAll(token, values[key] ?? '');
    }
    return out;
  }

  /// 主语言检测：'zh' / 'en'，平局看最后一句，全无字母/汉字默认 'zh'。
  static String detectLanguage(String text) {
    var cjk = 0;
    var latin = 0;
    for (final rune in text.runes) {
      if (_isCjk(rune)) {
        cjk += 1;
      } else if (_isLatin(rune)) {
        latin += 1;
      }
    }
    if (cjk == 0 && latin == 0) return 'zh';
    if (cjk == latin) {
      final parts = text
          .split(RegExp(r'[.!?。！？；;\n]+'))
          .where((s) => s.trim().isNotEmpty)
          .toList();
      final last = parts.isEmpty ? text : parts.last;
      var c2 = 0;
      var l2 = 0;
      for (final rune in last.runes) {
        if (_isCjk(rune)) {
          c2 += 1;
        } else if (_isLatin(rune)) {
          l2 += 1;
        }
      }
      return c2 >= l2 ? 'zh' : 'en';
    }
    return cjk > latin ? 'zh' : 'en';
  }

  static bool _isCjk(int v) =>
      (v >= 0x4E00 && v <= 0x9FFF) ||
      (v >= 0x3400 && v <= 0x4DBF) ||
      (v >= 0xF900 && v <= 0xFAFF);

  static bool _isLatin(int v) =>
      (v >= 0x41 && v <= 0x5A) || (v >= 0x61 && v <= 0x7A);

  static const List<R18ModuleRoute> r18ModuleRoutes = [
    R18ModuleRoute(
      file: 'craft-controls',
      title: '技法控制台（高级场景构建/修订）',
      keywords: ['console', '控制台', '多阶段', '长镜头', '反复修改', '打磨', '修订', '节奏敏感'],
    ),
    R18ModuleRoute(
      file: 'persona-and-continuity',
      title: '人设与跨场景连续性',
      keywords: [
        '人设',
        '连续性',
        '跨场景',
        '可复用人物',
        'recurring',
        '多人',
        '三人',
        '群体',
        'poly',
        'threesome',
      ],
    ),
    R18ModuleRoute(
      file: 'sexual-roles',
      title: '攻受与行为角色',
      keywords: [
        '攻受',
        '总攻',
        '总受',
        'top',
        'bottom',
        'switch',
        'gong',
        'shou',
        '插入位',
        '行为角色',
        '角色分配',
      ],
    ),
    R18ModuleRoute(
      file: 'language-and-dialogue',
      title: '语言与对白校准',
      keywords: [
        '对白',
        '台词',
        'dirty talk',
        '情话',
        '语言风格',
        '语气',
        '声线',
        'dialogue',
      ],
    ),
    R18ModuleRoute(
      file: 'play-and-props',
      title: '玩法与道具',
      keywords: ['道具', '玩具', '捆绑', '绳缚', 'kink', 'sm', '调教', 'play', '玩法'],
    ),
    R18ModuleRoute(
      file: 'speculative-anatomy',
      title: '幻想身体结构（人外）',
      keywords: [
        '人外',
        '非人类',
        '非人',
        '兽人',
        '龙人',
        '蛇人',
        '触手',
        '异种',
        '怪物',
        'monster',
        'nonhuman',
        'tentacle',
      ],
    ),
    R18ModuleRoute(
      file: 'canon-grounding-and-fanfiction',
      title: '同人原作锚定',
      keywords: ['同人', '二创', '原作', 'canon', 'au', '漫改', '性转', 'ooc', 'fanfiction'],
    ),
    R18ModuleRoute(
      file: 'core-calibration',
      title: '输出校准诊断',
      keywords: ['模板化', '太平淡', '干瘪', '不够色', '诊断', '校准', 'generic', '水词'],
    ),
  ];

  PromptLibraryState copyWith({
    Map<String, String>? overrides,
    List<PromptTagCategory>? tagCategories,
  }) => PromptLibraryState(
    overrides: overrides ?? this.overrides,
    tagCategories: tagCategories ?? this.tagCategories,
  );
}

class PromptLibraryNotifier extends Notifier<PromptLibraryState> {
  @override
  PromptLibraryState build() {
    _loadFromDb();
    return const PromptLibraryState();
  }

  Future<void> _loadFromDb() async {
    final db = ref.read(db_lib.appDatabaseProvider);
    final overrides = await db.loadPromptOverrides();
    final rows = await db.loadPromptTagCategories();
    List<PromptTagCategory> categories = PromptDefaults.defaultTagCategories;
    if (rows.isNotEmpty) {
      categories = rows.map((r) {
        final rawList = (jsonDecode(r.tagsJson) as List?) ?? const [];
        final tags = rawList
            .whereType<Map<String, dynamic>>()
            .map(PromptTag.fromJson)
            .toList();
        return PromptTagCategory(id: r.id, name: r.name, tags: tags);
      }).toList();
    }
    state = PromptLibraryState(overrides: overrides, tagCategories: categories);
  }

  Future<void> setOverride(String id, String text) async {
    final db = ref.read(db_lib.appDatabaseProvider);
    final trimmed = text.trim();
    final defaultPrompt = PromptDefaults.builtInPrompts
        .where((p) => p.id == id)
        .firstOrNull;
    final next = Map<String, String>.from(state.overrides);
    if (defaultPrompt != null && trimmed == defaultPrompt.defaultText.trim()) {
      next.remove(id);
      await db.deletePromptOverride(id);
    } else {
      final capped = text.length > PromptLimits.maxOverrideChars
          ? text.substring(0, PromptLimits.maxOverrideChars)
          : text;
      next[id] = capped;
      await db.upsertPromptOverride(id, capped);
    }
    state = state.copyWith(overrides: next);
  }

  Future<void> resetOverride(String id) async {
    final db = ref.read(db_lib.appDatabaseProvider);
    final next = Map<String, String>.from(state.overrides)..remove(id);
    await db.deletePromptOverride(id);
    state = state.copyWith(overrides: next);
  }

  Future<void> upsertTag(PromptTag tag, {required String categoryId}) async {
    final capped = tag.presetText.length > PromptLimits.maxTagPresetChars
        ? tag.copyWith(
            presetText: tag.presetText.substring(
              0,
              PromptLimits.maxTagPresetChars,
            ),
          )
        : tag;
    final nextCats = [
      for (final cat in state.tagCategories)
        if (cat.id != categoryId)
          cat
        else
          cat.copyWith(
            tags: cat.tags.any((t) => t.id == capped.id)
                ? [for (final t in cat.tags) t.id == capped.id ? capped : t]
                : [...cat.tags, capped],
          ),
    ];
    state = state.copyWith(tagCategories: nextCats);
    await _persistCategories(nextCats);
  }

  Future<void> deleteTag(String tagId, {required String categoryId}) async {
    final nextCats = [
      for (final cat in state.tagCategories)
        if (cat.id != categoryId)
          cat
        else
          cat.copyWith(tags: cat.tags.where((t) => t.id != tagId).toList()),
    ];
    state = state.copyWith(tagCategories: nextCats);
    await _persistCategories(nextCats);
  }

  Future<void> _persistCategories(List<PromptTagCategory> cats) async {
    final db = ref.read(db_lib.appDatabaseProvider);
    final companions = <db_lib.PromptTagCategoriesCompanion>[];
    for (var i = 0; i < cats.length; i++) {
      final cat = cats[i];
      companions.add(
        db_lib.PromptTagCategoriesCompanion.insert(
          id: cat.id,
          name: cat.name,
          tagsJson: jsonEncode([for (final t in cat.tags) t.toJson()]),
          sortOrder: Value(i),
        ),
      );
    }
    await db.replacePromptTagCategories(companions);
  }
}

final promptLibraryProvider =
    NotifierProvider<PromptLibraryNotifier, PromptLibraryState>(
      PromptLibraryNotifier.new,
    );
