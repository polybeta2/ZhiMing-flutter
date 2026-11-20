import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API 密钥安全仓库抽象：绝不写入 SQLite/日志/SharedPreferences。
abstract class ApiKeyVault {
  Future<void> save(String keyId, String apiKey);
  Future<String?> load(String keyId);
  Future<void> delete(String keyId);
}

class SecureApiKeyVault implements ApiKeyVault {
  SecureApiKeyVault({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _prefix = 'com.zhiming.apikey.';

  @override
  Future<void> save(String keyId, String apiKey) =>
      _storage.write(key: '$_prefix$keyId', value: apiKey);

  @override
  Future<String?> load(String keyId) => _storage.read(key: '$_prefix$keyId');

  @override
  Future<void> delete(String keyId) => _storage.delete(key: '$_prefix$keyId');
}

/// 内存实现（供单测使用）
class InMemoryApiKeyVault implements ApiKeyVault {
  final Map<String, String> _store = {};

  @override
  Future<void> save(String keyId, String apiKey) async {
    _store[keyId] = apiKey;
  }

  @override
  Future<String?> load(String keyId) async => _store[keyId];

  @override
  Future<void> delete(String keyId) async {
    _store.remove(keyId);
  }
}

final apiKeyVaultProvider = Provider<ApiKeyVault>(
  (ref) => SecureApiKeyVault(),
);
