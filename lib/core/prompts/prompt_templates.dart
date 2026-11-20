import '../llm/llm_types.dart';
import 'prompt_library.dart';
import 'prompt_limits.dart';

/// 系统提示词装配器：全部模板经 [PromptLibraryState] 解析（自动支持开发者覆写）。
abstract final class PromptTemplates {
  static List<LLMMessage> continueWriting({
    required PromptLibraryState library,
    required String renderedContext,
    required int wordTarget,
    String? extra,
  }) {
    final system = library.resolvedText(PromptID.continueWriting);
    final suffix = (extra != null && extra.trim().isNotEmpty)
        ? '附加要求：${extra.trim()}'
        : '';
    final user = '$renderedContext\n\n请续写约 $wordTarget 字。$suffix';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> writing({
    required PromptLibraryState library,
    required String renderedContext,
    required int wordTarget,
    String? extra,
  }) {
    final system = library.resolvedText(PromptID.writing);
    final suffix = (extra != null && extra.trim().isNotEmpty)
        ? '附加要求：${extra.trim()}'
        : '';
    final user = '$renderedContext\n\n请撰写约 $wordTarget 字的完整章节。$suffix';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> rewrite({
    required PromptLibraryState library,
    required String mode,
    required String selection,
    String? instruction,
    String? styleCard,
  }) {
    var system = mode == '去AI味'
        ? library.resolvedText(PromptID.antiAIFlavor)
        : PromptLibraryState.render(
            library.resolvedText(PromptID.rewrite),
            {'mode': mode},
          );
    if (styleCard != null && styleCard.isNotEmpty) {
      system = '$system\n\n$styleCard';
    }
    final req = (instruction != null && instruction.trim().isNotEmpty)
        ? instruction.trim()
        : '无额外要求';
    final user = '【原文】\n$selection\n\n【要求】\n$req';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> summarize({
    required PromptLibraryState library,
    required String content,
    required String title,
  }) {
    final system = library.resolvedText(PromptID.summarize);
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: '【$title】\n$content'),
    ];
  }

  static List<LLMMessage> creationClarify({
    required PromptLibraryState library,
    required String brief,
    required String qaHistory,
    String? supplement,
    String? sourceContext,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationClarify),
      supplement,
    );
    final user = StringBuffer('【创意】\n$brief');
    if (qaHistory.trim().isNotEmpty) {
      user.write('\n\n【此前问答】\n${qaHistory.trim()}');
    }
    _appendSourceContext(
      user,
      sourceContext: sourceContext,
      withAdherenceQuestion: true,
    );
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  static List<LLMMessage> creationStructure({
    required PromptLibraryState library,
    required String brief,
    required String qaHistory,
    String? feedback,
    String? supplement,
    String? sourceContext,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationStructure),
      supplement,
    );
    final user = StringBuffer('【创意】\n$brief');
    if (qaHistory.trim().isNotEmpty) {
      user.write('\n\n【问答记录】\n${qaHistory.trim()}');
    }
    if (feedback != null && feedback.trim().isNotEmpty) {
      user.write('\n\n【修改意见】\n${feedback.trim()}');
    }
    _appendSourceContext(
      user,
      sourceContext: sourceContext,
      withAdherenceQuestion: false,
    );
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  static List<LLMMessage> creationFoundation({
    required PromptLibraryState library,
    required String brief,
    required String qaHistory,
    required String structureJson,
    String? feedback,
    String? supplement,
    String? sourceContext,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationFoundation),
      supplement,
    );
    final user = StringBuffer('【创意】\n$brief');
    if (qaHistory.trim().isNotEmpty) {
      user.write('\n\n【问答记录】\n${qaHistory.trim()}');
    }
    user.write('\n\n【已确认的卷章结构】\n$structureJson');
    if (feedback != null && feedback.trim().isNotEmpty) {
      user.write('\n\n【修改意见】\n${feedback.trim()}');
    }
    _appendSourceContext(
      user,
      sourceContext: sourceContext,
      withAdherenceQuestion: false,
    );
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  static List<LLMMessage> creationVolumeBatch({
    required PromptLibraryState library,
    required String context,
    required List<String> targets,
    String? supplement,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationVolumeBatch),
      supplement,
    );
    final list = [
      for (var i = 0; i < targets.length; i++) '${i + 1}. ${targets[i]}',
    ].join('\n');
    final user = '【作品背景】\n$context\n\n【本批待生成卷】\n$list';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> creationChapterNames({
    required PromptLibraryState library,
    required String context,
    String? supplement,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationChapterNames),
      supplement,
    );
    final user = '【作品背景】\n$context\n\n请根据目标卷名与本章数，输出该卷全部章节标题。';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> creationChapterBatch({
    required PromptLibraryState library,
    required String context,
    required List<String> targets,
    String? supplement,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationChapterBatch),
      supplement,
    );
    final list = [
      for (var i = 0; i < targets.length; i++) '${i + 1}. ${targets[i]}',
    ].join('\n');
    final user = '【作品背景】\n$context\n\n【本批待生成章节】\n$list';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static List<LLMMessage> creationRevise({
    required PromptLibraryState library,
    required String blueprintJson,
    required String feedback,
    String? supplement,
  }) {
    final system = _appendSupplement(
      library.resolvedText(PromptID.creationRevise),
      supplement,
    );
    final user = '【当前蓝图】\n$blueprintJson\n\n【修改意见】\n$feedback';
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user),
    ];
  }

  static String writingAssistantSystem({
    required PromptLibraryState library,
    required String title,
    required String synopsis,
    String? styleGuide,
    String? styleCard,
  }) {
    final template = library.resolvedText(PromptID.writingAssistant);
    final buf = StringBuffer(
      PromptLibraryState.render(template, {'title': title}),
    );
    final cappedSynopsis = _tailCapped(synopsis);
    if (cappedSynopsis.isNotEmpty) {
      buf.write('\n作品梗概：$cappedSynopsis');
    }
    if (styleGuide != null && styleGuide.trim().isNotEmpty) {
      final cappedStyle = _tailCapped(styleGuide);
      if (cappedStyle.isNotEmpty) {
        buf.write('\n风格约束：$cappedStyle');
      }
    }
    if (styleCard != null && styleCard.isNotEmpty) {
      buf.write('\n$styleCard');
    }
    return buf.toString();
  }

  static List<LLMMessage> outline({
    required PromptLibraryState library,
    required String systemId,
    required String renderedContext,
    String? instruction,
  }) {
    final system = library.resolvedText(systemId);
    final user = StringBuffer(
      renderedContext.isEmpty ? '（暂无可用背景信息，请基于常识规划）' : renderedContext,
    );
    if (instruction != null && instruction.trim().isNotEmpty) {
      user.write('\n\n【附加要求】\n${instruction.trim()}');
    }
    return [
      LLMMessage(role: LLMRole.system, content: system),
      LLMMessage(role: LLMRole.user, content: user.toString()),
    ];
  }

  /// 动态注入（R18/风格卡/去AI味/读写协议/附加指令）先占用输入预算，剩余额度再交给上下文装配
  static int adjustedInputBudget(int base, List<String?> injections) {
    final used = injections.fold<int>(0, (sum, s) => sum + (s?.length ?? 0));
    return (base - used).clamp(0, base);
  }

  /// 把附加指令并入首条 system；无 system 则插入为首条；空白原样返回
  static List<LLMMessage> applyingExtra(
    String? extra,
    List<LLMMessage> messages,
  ) {
    final trimmed = extra?.trim();
    if (trimmed == null || trimmed.isEmpty) return messages;
    final result = List<LLMMessage>.from(messages);
    if (result.isNotEmpty && result.first.role == LLMRole.system) {
      result[0] = LLMMessage(
        role: LLMRole.system,
        content: '${result.first.content}\n\n$trimmed',
      );
    } else {
      result.insert(0, LLMMessage(role: LLMRole.system, content: trimmed));
    }
    return result;
  }

  static String _appendSupplement(String system, String? supplement) {
    final trimmed = supplement?.trim();
    if (trimmed == null || trimmed.isEmpty) return system;
    return '$system\n\n$trimmed';
  }

  static void _appendSourceContext(
    StringBuffer user, {
    required String? sourceContext,
    required bool withAdherenceQuestion,
  }) {
    final trimmed = sourceContext?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    if (withAdherenceQuestion) {
      user.write('''

【同人创作要求】
本作是基于下方原作档案创作的同人。请先向用户确认同人遵守度：严格原作线（情节/结局/人物状态遵循原作）/ IF 分歧线（自选分歧点改写原作走向）/ 仅借设定（只借世界观与人物，自由展开）。
写作时人物言行/能力/关系不得 OOC，原作已确立的事实不可改写，时间线必须合法。''');
    }
    user.write('\n\n【原作档案】\n$trimmed');
  }

  static String _tailCapped(
    String text, {
    int limit = PromptLimits.requiredFieldCap,
  }) {
    final trimmed = text.trim();
    if (trimmed.length <= limit) return trimmed;
    return '……${trimmed.substring(trimmed.length - limit)}';
  }
}
