import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../security/api_key_vault.dart';
import 'llm_types.dart';
import 'openai_sse_client.dart';

enum ProviderRole { primary, fastTool }

/// 全局推理思考模式偏好：
/// 用于规避推理型模型（如 DeepSeek V4.1 Flash）在常规任务上输出过长思考链耗尽 `max_tokens`。
enum ReasoningPreference {
  balanced(
    storageKey: 'balanced',
    label: '智能分级（推荐）',
    description: '扫描/账本/审稿/正文默认关闭冗长思考，避免思考链耗尽字数，兼顾极速与高缓存命中',
  ),
  low(
    storageKey: 'low',
    label: '轻度思考',
    description: '全任务开启轻度推理，并自动放宽思考输出上限至 32K tokens',
  ),
  medium(
    storageKey: 'medium',
    label: '深度思考',
    description: '全任务开启中度推理（耗时显著增加），自动放宽上限至 32K tokens',
  ),
  providerDefault(
    storageKey: 'provider_default',
    label: '跟随模型默认',
    description: '不下发 reasoning_effort 参数，完全由上游模型自行决定',
  );

  const ReasoningPreference({
    required this.storageKey,
    required this.label,
    required this.description,
  });

  final String storageKey;
  final String label;
  final String description;

  static ReasoningPreference fromStorageKey(String? raw) {
    for (final p in values) {
      if (p.storageKey == raw) return p;
    }
    return ReasoningPreference.balanced;
  }
}

/// 根据全局推理偏好与任务性质解析默认下发的 `reasoning_effort`：
/// 结构化批扫（如 10 章 Map）在轻/中度思考下也保持关闭思考，兼顾速度与防截断。
ReasoningEffort? resolveReasoningEffort(
  ReasoningPreference pref, {
  bool isStructuredBatch = false,
}) => switch (pref) {
  ReasoningPreference.balanced => ReasoningEffort.none,
  ReasoningPreference.low =>
    isStructuredBatch ? ReasoningEffort.none : ReasoningEffort.low,
  ReasoningPreference.medium =>
    isStructuredBatch ? ReasoningEffort.none : ReasoningEffort.medium,
  ReasoningPreference.providerDefault => null,
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

/// 安全构造 LLMClient（修复原版 B3 强解包 URL 崩溃风险），并按全局推理偏好注入默认 `reasoning_effort`。
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
      pref = ReasoningPreference.fromStorageKey(
        prefs.getString(ReasoningPreferenceNotifier.prefKey),
      );
    } catch (_) {}
    resolvedDefault = resolveReasoningEffort(pref);
  }
  return OpenAiSseClient(
    baseUrl: trimmedUrl,
    apiKey: apiKey,
    model: provider.modelName.trim(),
    proxyUrl: provider.proxyUrl,
    defaultReasoningEffort: resolvedDefault,
  );
}
