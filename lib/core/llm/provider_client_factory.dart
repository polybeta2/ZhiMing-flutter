import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../security/api_key_vault.dart';
import 'llm_types.dart';
import 'openai_sse_client.dart';

enum ProviderRole { primary, fastTool }

/// 全局推理努力程度（Effort）默认偏好：
/// 覆盖 OFF / Low / Medium / High / Xhigh / Max / Ultra 全部 7 档及「跟随模型默认」，
/// 同时保留 `balanced` 存储键兼容历史配置（对应默认 OFF，兼顾速度、缓存命中与防截断）。
enum ReasoningPreference {
  balanced(
    storageKey: 'balanced',
    label: 'OFF（智能分级·推荐）',
    shortLabel: 'OFF',
    description: '默认关闭冗长思考，避免思考链耗尽字数，兼顾极速与高缓存命中',
  ),
  low(
    storageKey: 'low',
    label: 'Low（轻度思考）',
    shortLabel: 'Low',
    description: '开启轻度推理，并自动放宽输出上限至 32K tokens',
  ),
  medium(
    storageKey: 'medium',
    label: 'Medium（中度思考）',
    shortLabel: 'Medium',
    description: '开启中度推理（耗时增加），自动放宽输出上限至 32K tokens',
  ),
  high(
    storageKey: 'high',
    label: 'High（高度思考）',
    shortLabel: 'High',
    description: '开启高强度推理，适合复杂推演与深度规划，自动放宽至 32K tokens',
  ),
  xhigh(
    storageKey: 'xhigh',
    label: 'Xhigh（超高思考）',
    shortLabel: 'Xhigh',
    description: '超高努力程度（需目标 API 端点支持 xhigh），自动放宽至 32K tokens',
  ),
  max(
    storageKey: 'max',
    label: 'Max（最大思考）',
    shortLabel: 'Max',
    description: '最大努力程度（需目标 API 端点支持 max），自动放宽至 32K tokens',
  ),
  ultra(
    storageKey: 'ultra',
    label: 'Ultra（极致思考）',
    shortLabel: 'Ultra',
    description: '极致努力程度（需目标 API 端点支持 ultra），自动放宽至 32K tokens',
  ),
  providerDefault(
    storageKey: 'provider_default',
    label: '跟随模型默认',
    shortLabel: '模型默认',
    description: '不下发 reasoning_effort 参数，完全由上游模型自行决定',
  );

  const ReasoningPreference({
    required this.storageKey,
    required this.label,
    required this.shortLabel,
    required this.description,
  });

  final String storageKey;
  final String label;
  final String shortLabel;
  final String description;

  /// 该偏好对应的直发 Effort 档位（`providerDefault` 返回 null 表示不下发参数）
  ReasoningEffort? get directEffort => switch (this) {
    ReasoningPreference.balanced => ReasoningEffort.none,
    ReasoningPreference.low => ReasoningEffort.low,
    ReasoningPreference.medium => ReasoningEffort.medium,
    ReasoningPreference.high => ReasoningEffort.high,
    ReasoningPreference.xhigh => ReasoningEffort.xhigh,
    ReasoningPreference.max => ReasoningEffort.max,
    ReasoningPreference.ultra => ReasoningEffort.ultra,
    ReasoningPreference.providerDefault => null,
  };

  static ReasoningPreference fromEffort(ReasoningEffort? effort) =>
      switch (effort) {
        null => ReasoningPreference.providerDefault,
        ReasoningEffort.none => ReasoningPreference.balanced,
        ReasoningEffort.minimal => ReasoningPreference.low,
        ReasoningEffort.low => ReasoningPreference.low,
        ReasoningEffort.medium => ReasoningPreference.medium,
        ReasoningEffort.high => ReasoningPreference.high,
        ReasoningEffort.xhigh => ReasoningPreference.xhigh,
        ReasoningEffort.max => ReasoningPreference.max,
        ReasoningEffort.ultra => ReasoningPreference.ultra,
      };

  static ReasoningPreference fromStorageKey(String? raw) {
    if (raw == 'none' || raw == 'off') return ReasoningPreference.balanced;
    for (final p in values) {
      if (p.storageKey == raw) return p;
    }
    return ReasoningPreference.balanced;
  }
}

/// 根据全局推理偏好与任务性质解析默认下发的 `reasoning_effort`：
/// 结构化批扫（如 10 章 Map）在非显式覆写下保持关闭思考，兼顾速度与防截断。
ReasoningEffort? resolveReasoningEffort(
  ReasoningPreference pref, {
  bool isStructuredBatch = false,
}) => switch (pref) {
  ReasoningPreference.balanced => ReasoningEffort.none,
  ReasoningPreference.providerDefault => null,
  _ => isStructuredBatch ? ReasoningEffort.none : pref.directEffort,
};

class ReasoningPreferenceNotifier extends Notifier<ReasoningPreference> {
  static const prefKey = 'llm.reasoningPreference';

  bool _explicitlySet = false;
  bool _disposed = false;

  @override
  ReasoningPreference build() {
    _explicitlySet = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return ReasoningPreference.balanced;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || _explicitlySet) return;
      state = ReasoningPreference.fromStorageKey(prefs.getString(prefKey));
    } catch (_) {}
  }

  Future<void> setPreference(ReasoningPreference next) async {
    _explicitlySet = true;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, next.storageKey);
    } catch (_) {}
  }
}

final reasoningPreferenceProvider =
    NotifierProvider<ReasoningPreferenceNotifier, ReasoningPreference>(
      ReasoningPreferenceNotifier.new,
    );

/// 按提供商维度存储的可选默认 Effort 覆写（`providerId -> ReasoningEffort`），
/// 未配置时自动跟随全局 `reasoningPreferenceProvider`。
class ProviderEffortOverridesNotifier
    extends Notifier<Map<String, ReasoningEffort>> {
  static const prefKey = 'llm.providerEffortOverrides';

  bool _explicitlySet = false;
  bool _disposed = false;

  @override
  Map<String, ReasoningEffort> build() {
    _explicitlySet = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed || _explicitlySet) return;
      state = decodeOverrides(prefs.getString(prefKey));
    } catch (_) {}
  }

  static Map<String, ReasoningEffort> decodeOverrides(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final map = <String, ReasoningEffort>{};
      for (final entry in decoded.entries) {
        final effort = ReasoningEffort.tryParse(entry.value?.toString());
        if (effort != null) {
          map[entry.key.toString()] = effort;
        }
      }
      return Map.unmodifiable(map);
    } catch (_) {
      return const {};
    }
  }

  Future<void> setForProvider(String providerId, ReasoningEffort? effort) async {
    _explicitlySet = true;
    final next = Map<String, ReasoningEffort>.from(state);
    if (effort == null) {
      next.remove(providerId);
    } else {
      next[providerId] = effort;
    }
    state = Map.unmodifiable(next);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode({
        for (final e in next.entries) e.key: e.value.wireValue,
      });
      await prefs.setString(prefKey, encoded);
    } catch (_) {}
  }
}

final providerEffortOverridesProvider =
    NotifierProvider<
      ProviderEffortOverridesNotifier,
      Map<String, ReasoningEffort>
    >(ProviderEffortOverridesNotifier.new);

/// 解析指定提供商在无局部覆写时生效的默认 Effort 文案（用于 UI 展示「跟随默认 (xxx)」）
String effectiveDefaultEffortLabel({
  required ReasoningPreference globalPref,
  ReasoningEffort? providerOverride,
}) {
  if (providerOverride != null) return providerOverride.label;
  return globalPref.shortLabel;
}

/// 端点 Effort 能力探测状态与本地持久化缓存（按 `baseUrl|model` 索引）
class EffortDiscoveryState {
  const EffortDiscoveryState({
    this.cache = const {},
    this.probingKeys = const {},
  });

  final Map<String, EffortCapabilities> cache;
  final Set<String> probingKeys;

  static String cacheKey(String baseUrl, String model) =>
      '${baseUrl.trim()}|${model.trim()}';

  EffortCapabilities? lookup(String baseUrl, String model) =>
      cache[cacheKey(baseUrl, model)];

  bool isProbing(String baseUrl, String model) =>
      probingKeys.contains(cacheKey(baseUrl, model));

  EffortDiscoveryState copyWith({
    Map<String, EffortCapabilities>? cache,
    Set<String>? probingKeys,
  }) {
    return EffortDiscoveryState(
      cache: cache ?? this.cache,
      probingKeys: probingKeys ?? this.probingKeys,
    );
  }
}

class EffortDiscoveryNotifier extends Notifier<EffortDiscoveryState> {
  static const prefKey = 'llm.effortDiscoveryCache';

  bool _disposed = false;
  final Set<String> _inFlight = <String>{};

  @override
  EffortDiscoveryState build() {
    _disposed = false;
    _inFlight.clear();
    ref.onDispose(() => _disposed = true);
    unawaited(_loadCache());
    return const EffortDiscoveryState();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefKey);
      if (_disposed || raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final loaded = <String, EffortCapabilities>{};
      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          loaded[entry.key.toString()] = EffortCapabilities.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
      if (loaded.isNotEmpty && !_disposed) {
        state = state.copyWith(
          cache: Map.unmodifiable({...loaded, ...state.cache}),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveCache(Map<String, EffortCapabilities> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 限制最多缓存 120 条端点-模型组合
      final entries = cache.entries.toList();
      final trimmed = entries.length > 120
          ? entries.sublist(entries.length - 120)
          : entries;
      await prefs.setString(
        prefKey,
        jsonEncode({for (final e in trimmed) e.key: e.value.toJson()}),
      );
    } catch (_) {}
  }

  /// 将 `/models` 列表接口顺带解析出的模型 Effort 能力写入缓存
  Future<void> seedFromModelsFetch(
    String baseUrl,
    Map<String, EffortCapabilities> discoveredByModel,
  ) async {
    if (discoveredByModel.isEmpty || _disposed) return;
    final next = Map<String, EffortCapabilities>.from(state.cache);
    for (final entry in discoveredByModel.entries) {
      next[EffortDiscoveryState.cacheKey(baseUrl, entry.key)] = entry.value;
    }
    state = state.copyWith(cache: Map.unmodifiable(next));
    await _saveCache(next);
  }

  /// 探测指定提供商当前模型的端点可用 Effort 列表；失败或未声明时静默回退全部 7 档。
  Future<EffortCapabilities> probeProvider(
    ProviderRecord provider,
    ApiKeyVault vault, {
    bool force = false,
  }) async {
    final key = EffortDiscoveryState.cacheKey(
      provider.baseUrl,
      provider.modelName,
    );
    if (!force && state.cache.containsKey(key)) {
      return state.cache[key]!;
    }
    if (_inFlight.contains(key)) {
      return state.cache[key] ?? const EffortCapabilities.fallbackAll();
    }
    final apiKey = (await vault.load(provider.apiKeyId))?.trim() ?? '';
    return probeRaw(
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      model: provider.modelName,
      proxyUrl: provider.proxyUrl,
      force: force,
    );
  }

  /// 直接使用表单中的 URL/Key/Model 探测（适用于编辑提供商页尚未保存时）
  Future<EffortCapabilities> probeRaw({
    required String baseUrl,
    required String apiKey,
    required String model,
    String? proxyUrl,
    bool force = false,
  }) async {
    final trimmedUrl = baseUrl.trim();
    final trimmedModel = model.trim();
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        trimmedModel.isEmpty ||
        apiKey.trim().isEmpty) {
      return const EffortCapabilities.fallbackAll();
    }
    final key = EffortDiscoveryState.cacheKey(trimmedUrl, trimmedModel);
    if (!force && state.cache.containsKey(key)) {
      return state.cache[key]!;
    }
    if (_inFlight.contains(key)) {
      return state.cache[key] ?? const EffortCapabilities.fallbackAll();
    }
    _inFlight.add(key);
    if (!_disposed) {
      state = state.copyWith(probingKeys: {...state.probingKeys, key});
    }
    try {
      final client = OpenAiSseClient(
        baseUrl: trimmedUrl,
        apiKey: apiKey.trim(),
        model: trimmedModel,
        proxyUrl: proxyUrl,
      );
      final res = await client.probeModelEffortCapabilities();
      if (_disposed) return res.target;
      final nextCache = Map<String, EffortCapabilities>.from(state.cache);
      for (final entry in res.allDiscovered.entries) {
        nextCache[EffortDiscoveryState.cacheKey(trimmedUrl, entry.key)] =
            entry.value;
      }
      nextCache[key] = res.target;
      final nextProbing = Set<String>.from(state.probingKeys)..remove(key);
      state = state.copyWith(
        cache: Map.unmodifiable(nextCache),
        probingKeys: Set.unmodifiable(nextProbing),
      );
      await _saveCache(nextCache);
      return res.target;
    } catch (_) {
      const fallback = EffortCapabilities.fallbackAll();
      if (!_disposed) {
        final nextCache = Map<String, EffortCapabilities>.from(state.cache)
          ..[key] = fallback;
        final nextProbing = Set<String>.from(state.probingKeys)..remove(key);
        state = state.copyWith(
          cache: Map.unmodifiable(nextCache),
          probingKeys: Set.unmodifiable(nextProbing),
        );
      }
      return fallback;
    } finally {
      _inFlight.remove(key);
    }
  }
}

final effortDiscoveryProvider =
    NotifierProvider<EffortDiscoveryNotifier, EffortDiscoveryState>(
      EffortDiscoveryNotifier.new,
    );

/// 根据任务角色从提供商列表中解析实际使用的模型配置：
/// - `primary` 恒定返回默认主力模型；
/// - `fastTool` 若指定了有效 `fastToolId` 且存在于列表则优先使用，否则安全回退至默认主力模型。
ProviderRecord? resolveProviderForRole(
  List<ProviderRecord> providers,
  ProviderRecord? defaultProvider,
  String? fastToolId,
  ProviderRole role,
) {
  if (role == ProviderRole.fastTool &&
      fastToolId != null &&
      fastToolId.isNotEmpty) {
    for (final p in providers) {
      if (p.id == fastToolId) return p;
    }
  }
  return defaultProvider;
}

class FastToolProviderIdNotifier extends Notifier<String?> {
  static const _prefKey = 'provider.fastToolProviderId';

  bool _explicitlySet = false;
  bool _disposed = false;

  @override
  String? build() {
    _explicitlySet = false;
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || _explicitlySet) return;
    final saved = prefs.getString(_prefKey)?.trim();
    state = (saved == null || saved.isEmpty) ? null : saved;
  }

  Future<void> setProviderId(String? id) async {
    _explicitlySet = true;
    final normalized = (id == null || id.trim().isEmpty) ? null : id.trim();
    state = normalized;
    final prefs = await SharedPreferences.getInstance();
    if (normalized == null) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(_prefKey, normalized);
    }
  }
}

final fastToolProviderIdProvider =
    NotifierProvider<FastToolProviderIdNotifier, String?>(
      FastToolProviderIdNotifier.new,
    );

final providersStreamProvider = StreamProvider<List<ProviderRecord>>((ref) {
  return ref.watch(appDatabaseProvider).watchProviders();
});

final defaultProviderProvider = Provider<ProviderRecord?>((ref) {
  final list = ref.watch(providersStreamProvider).valueOrNull ?? const [];
  if (list.isEmpty) return null;
  for (final p in list) {
    if (p.isDefault) return p;
  }
  return list.first;
});

final fastToolProviderProvider = Provider<ProviderRecord?>((ref) {
  final list = ref.watch(providersStreamProvider).valueOrNull ?? const [];
  final defaultProvider = ref.watch(defaultProviderProvider);
  final fastToolId = ref.watch(fastToolProviderIdProvider);
  return resolveProviderForRole(
    list,
    defaultProvider,
    fastToolId,
    ProviderRole.fastTool,
  );
});

/// 安全构造 LLMClient（修复原版 B3 强解包 URL 崩溃风险），并按优先级注入默认 `reasoning_effort`：
/// 1) 显式传入的 [defaultReasoningEffort]（来自各功能面板的 Effort 选择条）；
/// 2) 该提供商单独配置的默认 Effort（`llm.providerEffortOverrides`）；
/// 3) 全局推理努力程度设置（`llm.reasoningPreference`）。
Future<LLMClient> createClientForProvider(
  ProviderRecord provider,
  ApiKeyVault vault, {
  ReasoningEffort? defaultReasoningEffort,
}) async {
  final trimmedUrl = provider.baseUrl.trim();
  final uri = Uri.tryParse(trimmedUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw LLMException.invalidUrl();
  }
  final apiKey = (await vault.load(provider.apiKeyId))?.trim() ?? '';
  if (apiKey.isEmpty) {
    throw const LLMException('未配置有效的 API Key，请前往「设置 → 模型提供商」补录');
  }
  ReasoningEffort? resolvedDefault = defaultReasoningEffort;
  if (resolvedDefault == null) {
    var pref = ReasoningPreference.balanced;
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerOverrides = ProviderEffortOverridesNotifier.decodeOverrides(
        prefs.getString(ProviderEffortOverridesNotifier.prefKey),
      );
      resolvedDefault = providerOverrides[provider.id];
      if (resolvedDefault == null) {
        pref = ReasoningPreference.fromStorageKey(
          prefs.getString(ReasoningPreferenceNotifier.prefKey),
        );
        resolvedDefault = resolveReasoningEffort(pref);
      }
    } catch (_) {
      resolvedDefault = resolveReasoningEffort(pref);
    }
  }
  return OpenAiSseClient(
    baseUrl: trimmedUrl,
    apiKey: apiKey,
    model: provider.modelName.trim(),
    proxyUrl: provider.proxyUrl,
    defaultReasoningEffort: resolvedDefault,
  );
}
