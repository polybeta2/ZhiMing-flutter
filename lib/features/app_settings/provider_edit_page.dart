import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/llm/llm_types.dart';
import '../../core/llm/openai_sse_client.dart';
import '../../core/llm/provider_client_factory.dart';
import '../../core/prompts/prompt_limits.dart';
import '../../core/security/api_key_vault.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/effort_selector_bar.dart';
import '../../core/widgets/zm_widgets.dart';

class _ProviderPreset {
  const _ProviderPreset(this.name, this.baseUrl, this.model);
  final String name;
  final String baseUrl;
  final String model;
}

const _presets = [
  _ProviderPreset('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  _ProviderPreset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o'),
  _ProviderPreset(
    '通义千问',
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'qwen-max',
  ),
  _ProviderPreset('OpenRouter', 'https://openrouter.ai/api/v1', 'anthropic/claude-sonnet-4'),
];

class ProviderEditPage extends ConsumerStatefulWidget {
  const ProviderEditPage({super.key, this.providerId});

  final String? providerId;

  @override
  ConsumerState<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends ConsumerState<ProviderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _maxTokensCtrl = TextEditingController(text: '16384');
  final _budgetCtrl = TextEditingController(text: '60000');
  final _extraCtrl = TextEditingController();
  final _proxyCtrl = TextEditingController();

  double _temperature = 0.8;
  ReasoningEffort? _defaultEffort;
  bool _isDefault = false;
  bool _obscureKey = true;
  bool _loading = false;
  bool _testing = false;
  bool _fetchingModels = false;
  String? _testFeedback;
  bool _testOk = false;

  ProviderRecord? _editing;

  @override
  void initState() {
    super.initState();
    if (widget.providerId != null) {
      _loadExisting(widget.providerId!);
    }
  }

  Future<void> _loadExisting(String id) async {
    setState(() => _loading = true);
    final db = ref.read(appDatabaseProvider);
    final list = await db.getProviders();
    final found = list.where((e) => e.id == id).firstOrNull;
    if (found != null) {
      _editing = found;
      _nameCtrl.text = found.name;
      _baseUrlCtrl.text = found.baseUrl;
      _modelCtrl.text = found.modelName;
      _maxTokensCtrl.text = '${found.maxTokens}';
      _budgetCtrl.text = '${found.contextBudgetChars}';
      _extraCtrl.text = found.systemPromptExtra ?? '';
      _proxyCtrl.text = found.proxyUrl ?? '';
      _temperature = found.temperature;
      _isDefault = found.isDefault;
      _defaultEffort = ref.read(providerEffortOverridesProvider)[found.id];
      final key = await ref.read(apiKeyVaultProvider).load(found.apiKeyId);
      if (key != null) _apiKeyCtrl.text = key;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    _maxTokensCtrl.dispose();
    _budgetCtrl.dispose();
    _extraCtrl.dispose();
    _proxyCtrl.dispose();
    super.dispose();
  }

  OpenAiSseClient _buildPreviewClient() {
    return OpenAiSseClient(
      baseUrl: _baseUrlCtrl.text.trim(),
      apiKey: _apiKeyCtrl.text.trim(),
      model: _modelCtrl.text.trim(),
      proxyUrl: _proxyCtrl.text.trim().isEmpty ? null : _proxyCtrl.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testFeedback = null;
    });
    try {
      final reply = await _buildPreviewClient().testConnection();
      if (!mounted) return;
      setState(() {
        _testOk = true;
        _testFeedback = '连接成功：${reply.trim().isEmpty ? '(空响应)' : reply.trim()}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testFeedback = '$e';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _fetchModels() async {
    setState(() => _fetchingModels = true);
    try {
      final res = await _buildPreviewClient().fetchModelsWithCapabilities();
      await ref
          .read(effortDiscoveryProvider.notifier)
          .seedFromModelsFetch(_baseUrlCtrl.text.trim(), res.capabilities);
      if (!mounted) return;
      final ids = res.modelIds;
      if (ids.isEmpty) {
        showZmSnackBar(context, '接口返回了空的模型列表');
        return;
      }
      final picked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => _ModelPickerModal(modelIds: ids),
      );
      if (picked != null) {
        setState(() => _modelCtrl.text = picked);
      }
    } catch (e) {
      if (mounted) showZmSnackBar(context, '拉取模型失败：$e', isError: true);
    } finally {
      if (mounted) setState(() => _fetchingModels = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(appDatabaseProvider);
    final vault = ref.read(apiKeyVaultProvider);
    final existingList = await db.getProviders();

    final id = _editing?.id ?? const Uuid().v4();
    final keyId = _editing?.apiKeyId ?? const Uuid().v4();
    final shouldBeDefault = _isDefault || existingList.isEmpty;

    final maxTokens = (int.tryParse(_maxTokensCtrl.text.trim()) ?? 16384)
        .clamp(256, 200000);
    final budget = (int.tryParse(_budgetCtrl.text.trim()) ?? 60000).clamp(
      2000,
      500000,
    );
    var extra = _extraCtrl.text.trim();
    if (extra.length > PromptLimits.maxOverrideChars) {
      extra = extra.substring(0, PromptLimits.maxOverrideChars);
    }
    final proxy = _proxyCtrl.text.trim();

    await vault.save(keyId, _apiKeyCtrl.text.trim());
    await db.upsertProvider(
      ProvidersCompanion.insert(
        id: id,
        name: _nameCtrl.text.trim(),
        baseUrl: _baseUrlCtrl.text.trim(),
        apiKeyId: keyId,
        modelName: _modelCtrl.text.trim(),
        temperature: Value(_temperature),
        maxTokens: Value(maxTokens),
        contextBudgetChars: Value(budget),
        systemPromptExtra: Value(extra.isEmpty ? null : extra),
        proxyUrl: Value(proxy.isEmpty ? null : proxy),
        isDefault: Value(shouldBeDefault),
        createdAt: _editing?.createdAt ?? DateTime.now(),
      ),
    );
    if (shouldBeDefault) {
      await db.makeDefaultProvider(id);
    }
    await ref
        .read(providerEffortOverridesProvider.notifier)
        .setForProvider(id, _defaultEffort);
    if (mounted) {
      showZmSnackBar(context, '模型提供商已保存');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? '新增模型提供商' : '编辑模型提供商'),
        actions: [
          FilledButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: AppTokens.s3),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(AppTokens.s4),
                    children: [
                      if (_editing == null) ...[
                        Text(
                          '快速填充常用服务商',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final preset in _presets)
                              ActionChip(
                                label: Text(preset.name),
                                onPressed: () {
                                  _nameCtrl.text = preset.name;
                                  _baseUrlCtrl.text = preset.baseUrl;
                                  _modelCtrl.text = preset.model;
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.s4),
                      ],
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: '名称',
                                  hintText: '例如：DeepSeek 官方',
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? '请输入名称'
                                    : null,
                              ),
                              const SizedBox(height: AppTokens.s3),
                              TextFormField(
                                controller: _baseUrlCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Base URL（OpenAI 兼容）',
                                  hintText: 'https://api.deepseek.com/v1',
                                ),
                                validator: (v) {
                                  final uri = Uri.tryParse(v?.trim() ?? '');
                                  if (uri == null ||
                                      !uri.hasScheme ||
                                      uri.host.isEmpty) {
                                    return '请输入合法的 http(s):// 地址';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppTokens.s3),
                              TextFormField(
                                controller: _apiKeyCtrl,
                                obscureText: _obscureKey,
                                decoration: InputDecoration(
                                  labelText: 'API Key（仅存系统安全密钥库）',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureKey
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureKey = !_obscureKey,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? '请输入 API Key'
                                    : null,
                              ),
                              const SizedBox(height: AppTokens.s3),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _modelCtrl,
                                      decoration: const InputDecoration(
                                        labelText: '模型名称',
                                        hintText: 'deepseek-chat',
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                          ? '请输入模型名'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 52,
                                    child: OutlinedButton.icon(
                                      onPressed: _fetchingModels
                                          ? null
                                          : _fetchModels,
                                      icon: _fetchingModels
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.search, size: 18),
                                      label: const Text('拉取列表'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTokens.s3),
                              Row(
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: _testing
                                        ? null
                                        : _testConnection,
                                    icon: _testing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.wifi_tethering_rounded,
                                            size: 18,
                                          ),
                                    label: const Text('测试连接'),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_testFeedback != null)
                                    Expanded(
                                      child: Text(
                                        _testFeedback!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _testOk
                                              ? Colors.green
                                              : cs.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s4),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('采样温度 Temperature'),
                                  Text(
                                    _temperature.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: _temperature,
                                min: 0,
                                max: 1.5,
                                divisions: 30,
                                onChanged: (v) =>
                                    setState(() => _temperature = v),
                              ),
                              const SizedBox(height: AppTokens.s2),
                              EffortSelectorBar(
                                title: '默认 Effort（努力程度）',
                                value: _defaultEffort,
                                rawBaseUrl: _baseUrlCtrl.text,
                                rawApiKey: _apiKeyCtrl.text,
                                rawModel: _modelCtrl.text,
                                rawProxyUrl: _proxyCtrl.text.trim().isEmpty
                                    ? null
                                    : _proxyCtrl.text.trim(),
                                followDefaultLabel: '跟随全局默认',
                                onChanged: (v) =>
                                    setState(() => _defaultEffort = v),
                              ),
                              const SizedBox(height: AppTokens.s3),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _maxTokensCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Max Tokens（输出上限）',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTokens.s3),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _budgetCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: '上下文字符预算',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTokens.s3),
                              TextFormField(
                                controller: _proxyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'HTTP 代理（可选）',
                                  hintText: '例如：127.0.0.1:7890（留空则直连）',
                                ),
                              ),
                              const SizedBox(height: AppTokens.s3),
                              TextFormField(
                                controller: _extraCtrl,
                                minLines: 2,
                                maxLines: 5,
                                maxLength: PromptLimits.maxOverrideChars,
                                decoration: const InputDecoration(
                                  labelText: '附加系统指令（可选）',
                                  hintText: '所有经由本提供商发出的请求都会自动拼接此指令',
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('设为默认提供商'),
                                value: _isDefault,
                                onChanged: (v) =>
                                    setState(() => _isDefault = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ModelPickerModal extends StatefulWidget {
  const _ModelPickerModal({required this.modelIds});
  final List<String> modelIds;

  @override
  State<_ModelPickerModal> createState() => _ModelPickerModalState();
}

class _ModelPickerModalState extends State<_ModelPickerModal> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.modelIds
        .where((id) => id.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索模型 ID…',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(filtered[i]),
                onTap: () => Navigator.of(context).pop(filtered[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
