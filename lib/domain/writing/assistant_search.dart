import '../../core/llm/llm_json_parser.dart';

/// 写作助手「按需查书」轻量协议（`zm-search`）：
/// 当 AI 需要考证前文/原作中的人物关系、道具来历、伏笔细节时，可输出：
/// ```zm-search
/// {"queries": ["爱丽丝", "银色怀表"]}
/// ```
/// 客户端在本地零耗时检索作品已有章节及关联原作全文，将原文片段回填给 AI，
/// 复用同一静态 Prefix（高 KV Cache 命中率）生成有据可查的最终回答。
abstract final class AssistantSearchProtocol {
  static const String systemInstruction = '''【本地查书工具协议（按需使用）】
当你需要核查本作前文或关联原作中某个人物、道具、设定、旧事件或伏笔的精确细节（且当前上下文未给出）时，**不要猜测或胡编**，直接输出如下代码块向本地全文检索发起查证（最多 4 个关键词，每个关键词请用 1 个精准实体名或原词如 "爱丽丝"、"罗娜"、"银色怀表"，不要把多个词拼在一条里；仅输出此代码块即可，系统会自动返回原文片段供你继续作答）：
```zm-search
{"queries": ["爱丽丝", "罗娜"]}
```
若当前上下文已足够作答，直接正常回答，无需调用查书。''';

  static final RegExp _fenceRe = RegExp(
    r'```zm-search\s*([\s\S]*?)```',
    caseSensitive: false,
  );

  /// 从模型输出中提取检索关键词（无检索请求返回空列表）
  static List<String> extractQueries(String raw) {
    final m = _fenceRe.firstMatch(raw);
    if (m == null) return const [];
    final jsonPart = m.group(1)?.trim() ?? '';
    final decoded = LLMJSONParser.decodeObject(jsonPart, (map) => map);
    if (decoded == null) return const [];
    final q = decoded['queries'];
    if (q is! List) return const [];
    return q
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .take(4)
        .toList();
  }

  /// 剥离回复中的 `zm-search` 代码块
  static String stripSearchBlock(String raw) =>
      raw.replaceAll(_fenceRe, '').trim();
}
