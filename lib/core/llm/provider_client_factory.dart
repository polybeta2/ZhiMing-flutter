import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../security/api_key_vault.dart';
import 'llm_types.dart';
import 'openai_sse_client.dart';

enum ProviderRole { primary, fastTool }

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

/// 安全构造 LLMClient（修复原版 B3 强解包 URL 崩溃风险）
Future<LLMClient> createClientForProvider(
  ProviderRecord provider,
  ApiKeyVault vault,
) async {
  final trimmedUrl = provider.baseUrl.trim();
  final uri = Uri.tryParse(trimmedUrl);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw LLMException.invalidUrl();
  }
  final apiKey = (await vault.load(provider.apiKeyId))?.trim() ?? '';
  if (apiKey.isEmpty) {
    throw const LLMException('未配置有效的 API Key，请前往「设置 → 模型提供商」补录');
  }
  return OpenAiSseClient(
    baseUrl: trimmedUrl,
    apiKey: apiKey,
    model: provider.modelName.trim(),
    proxyUrl: provider.proxyUrl,
  );
}
