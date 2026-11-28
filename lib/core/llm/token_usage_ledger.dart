import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart' show ProviderRecord;
import 'llm_types.dart';

/// Token 用量功能分类
enum UsageCategory {
  writing('writing', '正文撰写/续写'),
  rewrite('rewrite', '划词精修'),
  factReview('fact_review', '事实审稿/勘误'),
  summary('summary', '活体建档摘要'),
  outline('outline', '卷章大纲/细纲'),
  assistant('assistant', '写作/立项助手'),
  sourceScan('source_scan', '原作扫描建档'),
  style('style', '文风蒸馏/体检');

  const UsageCategory(this.key, this.label);
  final String key;
  final String label;

  static UsageCategory fromKey(String? raw) {
    for (final c in values) {
      if (c.key == raw) return c;
    }
    return UsageCategory.writing;
  }
}

/// 单价配置（每百万 Token 价格，支持用户自定义或套用常用预设）
class TokenPricingConfig {
  const TokenPricingConfig({
    this.currencySymbol = '¥',
    this.inputPerMillion = 2.0,
    this.cachedInputPerMillion = 0.2,
    this.outputPerMillion = 8.0,
  });

  final String currencySymbol;
  final double inputPerMillion;
  final double cachedInputPerMillion;
  final double outputPerMillion;

  static const presets = <({String name, TokenPricingConfig config})>[
    (
      name: 'DeepSeek 参考 (¥2 / ¥0.2 / ¥8)',
      config: TokenPricingConfig(
        currencySymbol: '¥',
        inputPerMillion: 2.0,
        cachedInputPerMillion: 0.2,
        outputPerMillion: 8.0,
      ),
    ),
    (
      name: '平价快模参考 (¥0.5 / ¥0.05 / ¥2)',
      config: TokenPricingConfig(
        currencySymbol: '¥',
        inputPerMillion: 0.5,
        cachedInputPerMillion: 0.05,
        outputPerMillion: 2.0,
      ),
    ),
    (
      name: r'Claude Sonnet ($3 / $0.3 / $15)',
      config: TokenPricingConfig(
        currencySymbol: r'$',
        inputPerMillion: 3.0,
        cachedInputPerMillion: 0.3,
        outputPerMillion: 15.0,
      ),
    ),
    (
      name: r'GPT-5 / 旗舰 ($2.5 / $0.25 / $10)',
      config: TokenPricingConfig(
        currencySymbol: r'$',
        inputPerMillion: 2.5,
        cachedInputPerMillion: 0.25,
        outputPerMillion: 10.0,
      ),
    ),
    (
      name: '免费 / 自建 (¥0)',
      config: TokenPricingConfig(
        currencySymbol: '¥',
        inputPerMillion: 0,
        cachedInputPerMillion: 0,
        outputPerMillion: 0,
      ),
    ),
  ];

  double estimateActualCost({
    required int promptTokens,
    required int cachedTokens,
    required int completionTokens,
  }) {
    final safeCached = cachedTokens.clamp(0, promptTokens);
    final uncached = (promptTokens - safeCached).clamp(0, promptTokens);
    return (uncached * inputPerMillion +
            safeCached * cachedInputPerMillion +
            completionTokens * outputPerMillion) /
        1000000.0;
  }

  double estimateCostWithoutCache({
    required int promptTokens,
    required int completionTokens,
  }) {
    return (promptTokens * inputPerMillion +
            completionTokens * outputPerMillion) /
        1000000.0;
  }

  double estimateCacheSavings({
    required int promptTokens,
    required int cachedTokens,
    required int completionTokens,
  }) {
    final raw =
        estimateCostWithoutCache(
          promptTokens: promptTokens,
          completionTokens: completionTokens,
        ) -
        estimateActualCost(
          promptTokens: promptTokens,
          cachedTokens: cachedTokens,
          completionTokens: completionTokens,
        );
    return raw > 0 ? raw : 0.0;
  }

  String formatMoney(double amount) {
    if (amount <= 0) return '${currencySymbol}0.00';
    if (amount < 0.01) return '$currencySymbol${amount.toStringAsFixed(4)}';
    if (amount < 1.0) return '$currencySymbol${amount.toStringAsFixed(3)}';
    return '$currencySymbol${amount.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
    'currencySymbol': currencySymbol,
    'inputPerMillion': inputPerMillion,
    'cachedInputPerMillion': cachedInputPerMillion,
    'outputPerMillion': outputPerMillion,
  };

  factory TokenPricingConfig.fromJson(Map<String, dynamic> json) {
    return TokenPricingConfig(
      currencySymbol: (json['currencySymbol']?.toString().trim().isNotEmpty ?? false)
          ? json['currencySymbol'].toString().trim()
          : '¥',
      inputPerMillion: (json['inputPerMillion'] as num?)?.toDouble() ?? 2.0,
      cachedInputPerMillion:
          (json['cachedInputPerMillion'] as num?)?.toDouble() ?? 0.2,
      outputPerMillion: (json['outputPerMillion'] as num?)?.toDouble() ?? 8.0,
    );
  }
}

/// 单次 LLM 请求的 Token 账单记录
class TokenUsageRecord {
  const TokenUsageRecord({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.providerName,
    required this.modelName,
    required this.promptTokens,
    required this.completionTokens,
    this.cachedTokens = 0,
    this.cacheCreationTokens = 0,
    this.reasoningTokens = 0,
    this.novelId,
    this.chapterId,
    this.chapterTitle,
    this.effort,
  });

  final String id;
  final DateTime timestamp;
  final UsageCategory category;
  final String providerName;
  final String modelName;
  final int promptTokens;
  final int completionTokens;
  final int cachedTokens;
  final int cacheCreationTokens;
  final int reasoningTokens;
  final String? novelId;
  final String? chapterId;
  final String? chapterTitle;
  final String? effort;

  int get totalTokens => promptTokens + completionTokens;

  double get cacheHitRate =>
      promptTokens > 0 ? (cachedTokens / promptTokens).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ts': timestamp.millisecondsSinceEpoch,
    'cat': category.key,
    'prov': providerName,
    'model': modelName,
    'in': promptTokens,
    'out': completionTokens,
    if (cachedTokens > 0) 'cached': cachedTokens,
    if (cacheCreationTokens > 0) 'cacheWrite': cacheCreationTokens,
    if (reasoningTokens > 0) 'reason': reasoningTokens,
    if (novelId != null) 'novelId': novelId,
    if (chapterId != null) 'chId': chapterId,
    if (chapterTitle != null) 'chTitle': chapterTitle,
    if (effort != null) 'effort': effort,
  };

  factory TokenUsageRecord.fromJson(Map<String, dynamic> json) {
    return TokenUsageRecord(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (json['ts'] as num?)?.toInt() ?? 0,
      ),
      category: UsageCategory.fromKey(json['cat']?.toString()),
      providerName: json['prov']?.toString() ?? '',
      modelName: json['model']?.toString() ?? '',
      promptTokens: (json['in'] as num?)?.toInt() ?? 0,
      completionTokens: (json['out'] as num?)?.toInt() ?? 0,
      cachedTokens: (json['cached'] as num?)?.toInt() ?? 0,
      cacheCreationTokens: (json['cacheWrite'] as num?)?.toInt() ?? 0,
      reasoningTokens: (json['reason'] as num?)?.toInt() ?? 0,
      novelId: json['novelId']?.toString(),
      chapterId: json['chId']?.toString(),
      chapterTitle: json['chTitle']?.toString(),
      effort: json['effort']?.toString(),
    );
  }
}

class UsageBucketSummary {
  const UsageBucketSummary({
    required this.label,
    required this.requests,
    required this.promptTokens,
    required this.cachedTokens,
    required this.completionTokens,
    required this.reasoningTokens,
    required this.estimatedCost,
    required this.estimatedSavings,
  });

  final String label;
  final int requests;
  final int promptTokens;
  final int cachedTokens;
  final int completionTokens;
  final int reasoningTokens;
  final double estimatedCost;
  final double estimatedSavings;

  int get totalTokens => promptTokens + completionTokens;
  double get cacheHitRate =>
      promptTokens > 0 ? (cachedTokens / promptTokens).clamp(0.0, 1.0) : 0.0;
}

class TokenUsageSummary {
  const TokenUsageSummary({
    required this.requests,
    required this.promptTokens,
    required this.cachedTokens,
    required this.cacheCreationTokens,
    required this.completionTokens,
    required this.reasoningTokens,
    required this.estimatedCost,
    required this.estimatedSavings,
    required this.byCategory,
    required this.byChapter,
    required this.byModel,
    required this.recentRecords,
  });

  final int requests;
  final int promptTokens;
  final int cachedTokens;
  final int cacheCreationTokens;
  final int completionTokens;
  final int reasoningTokens;
  final double estimatedCost;
  final double estimatedSavings;
  final List<UsageBucketSummary> byCategory;
  final List<UsageBucketSummary> byChapter;
  final List<UsageBucketSummary> byModel;
  final List<TokenUsageRecord> recentRecords;

  int get totalTokens => promptTokens + completionTokens;

  double get cacheHitRate =>
      promptTokens > 0 ? (cachedTokens / promptTokens).clamp(0.0, 1.0) : 0.0;

  double get reasoningShare => completionTokens > 0
      ? (reasoningTokens / completionTokens).clamp(0.0, 1.0)
      : 0.0;

  static String formatTokenCount(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(2)}M';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return '$tokens';
  }
}

class TokenUsageLedgerState {
  const TokenUsageLedgerState({
    this.records = const [],
    this.pricing = const TokenPricingConfig(),
  });

  final List<TokenUsageRecord> records;
  final TokenPricingConfig pricing;

  TokenUsageSummary summarize({String? novelId}) {
    final filtered = novelId == null
        ? records
        : records.where((r) => r.novelId == novelId).toList();
    var prompt = 0;
    var cached = 0;
    var cacheWrite = 0;
    var completion = 0;
    var reasoning = 0;

    final catMap = <UsageCategory, List<TokenUsageRecord>>{};
    final chMap = <String, List<TokenUsageRecord>>{};
    final modelMap = <String, List<TokenUsageRecord>>{};

    for (final r in filtered) {
      prompt += r.promptTokens;
      cached += r.cachedTokens;
      cacheWrite += r.cacheCreationTokens;
      completion += r.completionTokens;
      reasoning += r.reasoningTokens;
      (catMap[r.category] ??= []).add(r);
      if (r.chapterTitle != null && r.chapterTitle!.trim().isNotEmpty) {
        (chMap[r.chapterTitle!.trim()] ??= []).add(r);
      }
      final modelKey = r.modelName.trim().isNotEmpty
          ? r.modelName.trim()
          : (r.providerName.trim().isNotEmpty ? r.providerName.trim() : '未知模型');
      (modelMap[modelKey] ??= []).add(r);
    }

    List<UsageBucketSummary> buildBuckets(
      Map<String, List<TokenUsageRecord>> groups,
    ) {
      final list = <UsageBucketSummary>[];
      for (final entry in groups.entries) {
        var bIn = 0;
        var bCached = 0;
        var bOut = 0;
        var bReason = 0;
        for (final r in entry.value) {
          bIn += r.promptTokens;
          bCached += r.cachedTokens;
          bOut += r.completionTokens;
          bReason += r.reasoningTokens;
        }
        list.add(
          UsageBucketSummary(
            label: entry.key,
            requests: entry.value.length,
            promptTokens: bIn,
            cachedTokens: bCached,
            completionTokens: bOut,
            reasoningTokens: bReason,
            estimatedCost: pricing.estimateActualCost(
              promptTokens: bIn,
              cachedTokens: bCached,
              completionTokens: bOut,
            ),
            estimatedSavings: pricing.estimateCacheSavings(
              promptTokens: bIn,
              cachedTokens: bCached,
              completionTokens: bOut,
            ),
          ),
        );
      }
      list.sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
      return list;
    }

    final catBuckets = buildBuckets({
      for (final e in catMap.entries) e.key.label: e.value,
    });
    final chBuckets = buildBuckets(chMap);
    final modelBuckets = buildBuckets(modelMap);

    final recent = List<TokenUsageRecord>.from(filtered)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return TokenUsageSummary(
      requests: filtered.length,
      promptTokens: prompt,
      cachedTokens: cached,
      cacheCreationTokens: cacheWrite,
      completionTokens: completion,
      reasoningTokens: reasoning,
      estimatedCost: pricing.estimateActualCost(
        promptTokens: prompt,
        cachedTokens: cached,
        completionTokens: completion,
      ),
      estimatedSavings: pricing.estimateCacheSavings(
        promptTokens: prompt,
        cachedTokens: cached,
        completionTokens: completion,
      ),
      byCategory: catBuckets,
      byChapter: chBuckets,
      byModel: modelBuckets,
      recentRecords: recent.take(30).toList(),
    );
  }
}

class TokenUsageLedgerNotifier extends Notifier<TokenUsageLedgerState> {
  static const recordsPrefKey = 'llm.tokenUsageRecords.v1';
  static const pricingPrefKey = 'llm.tokenPricing.v1';
  static const int maxStoredRecords = 500;
  static const _uuid = Uuid();

  bool _disposed = false;
  bool _loaded = false;

  @override
  TokenUsageLedgerState build() {
    _disposed = false;
    _loaded = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const TokenUsageLedgerState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || _loaded) return;
      final pricingRaw = prefs.getString(pricingPrefKey);
      var pricing = state.pricing;
      if (pricingRaw != null && pricingRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(pricingRaw);
        if (decoded is Map) {
          pricing = TokenPricingConfig.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
      final recordsRaw = prefs.getString(recordsPrefKey);
      final loadedRecords = <TokenUsageRecord>[];
      if (recordsRaw != null && recordsRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(recordsRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              loadedRecords.add(
                TokenUsageRecord.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
      }
      _loaded = true;
      if (!_disposed) {
        // 合并加载前已经记录的内存条目（去重）
        final existingIds = loadedRecords.map((e) => e.id).toSet();
        final merged = [
          ...loadedRecords,
          for (final r in state.records)
            if (!existingIds.contains(r.id)) r,
        ];
        state = TokenUsageLedgerState(
          records: List.unmodifiable(_trimRecords(merged)),
          pricing: pricing,
        );
      }
    } catch (_) {}
  }

  List<TokenUsageRecord> _trimRecords(List<TokenUsageRecord> list) {
    if (list.length <= maxStoredRecords) return list;
    return list.sublist(list.length - maxStoredRecords);
  }

  Future<void> _persistRecords(List<TokenUsageRecord> records) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        recordsPrefKey,
        jsonEncode([for (final r in records) r.toJson()]),
      );
    } catch (_) {}
  }

  Future<void> recordUsage({
    required UsageReport? usage,
    required UsageCategory category,
    required ProviderRecord provider,
    String? novelId,
    String? chapterId,
    String? chapterTitle,
    ReasoningEffort? effort,
  }) async {
    if (usage == null) return;
    if (usage.promptTokens <= 0 &&
        usage.completionTokens <= 0 &&
        usage.cachedTokens <= 0) {
      return;
    }
    await recordRaw(
      category: category,
      providerName: provider.name,
      modelName: provider.modelName,
      promptTokens: usage.promptTokens,
      completionTokens: usage.completionTokens,
      cachedTokens: usage.cachedTokens,
      cacheCreationTokens: usage.cacheCreationTokens,
      reasoningTokens: usage.reasoningTokens,
      novelId: novelId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      effort: effort?.label,
    );
  }

  Future<void> recordRaw({
    required UsageCategory category,
    required String providerName,
    required String modelName,
    required int promptTokens,
    required int completionTokens,
    int cachedTokens = 0,
    int cacheCreationTokens = 0,
    int reasoningTokens = 0,
    String? novelId,
    String? chapterId,
    String? chapterTitle,
    String? effort,
    DateTime? timestamp,
  }) async {
    if (promptTokens <= 0 && completionTokens <= 0 && cachedTokens <= 0) {
      return;
    }
    final rec = TokenUsageRecord(
      id: _uuid.v4(),
      timestamp: timestamp ?? DateTime.now(),
      category: category,
      providerName: providerName,
      modelName: modelName,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      cachedTokens: cachedTokens,
      cacheCreationTokens: cacheCreationTokens,
      reasoningTokens: reasoningTokens,
      novelId: novelId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      effort: effort,
    );
    final next = _trimRecords([...state.records, rec]);
    if (!_disposed) {
      state = TokenUsageLedgerState(
        records: List.unmodifiable(next),
        pricing: state.pricing,
      );
    }
    await _persistRecords(next);
  }

  Future<void> setPricing(TokenPricingConfig pricing) async {
    _loaded = true;
    if (!_disposed) {
      state = TokenUsageLedgerState(
        records: state.records,
        pricing: pricing,
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(pricingPrefKey, jsonEncode(pricing.toJson()));
    } catch (_) {}
  }

  Future<void> clearForNovel(String novelId) async {
    final next = state.records.where((r) => r.novelId != novelId).toList();
    if (!_disposed) {
      state = TokenUsageLedgerState(
        records: List.unmodifiable(next),
        pricing: state.pricing,
      );
    }
    await _persistRecords(next);
  }

  Future<void> clearAll() async {
    if (!_disposed) {
      state = TokenUsageLedgerState(
        records: const [],
        pricing: state.pricing,
      );
    }
    await _persistRecords(const []);
  }
}

final tokenUsageLedgerProvider =
    NotifierProvider<TokenUsageLedgerNotifier, TokenUsageLedgerState>(
      TokenUsageLedgerNotifier.new,
    );
