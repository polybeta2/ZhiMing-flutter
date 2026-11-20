import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../security/api_key_vault.dart';
import 'llm_types.dart';
import 'openai_sse_client.dart';

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
