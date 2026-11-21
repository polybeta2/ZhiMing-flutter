import '../../core/prompts/prompt_library.dart';
import '../../core/prompts/prompt_limits.dart';
import 'writing_director_config.dart';

/// 单条动态写前思考步骤（按 [order] 从小到大排序拼装，类似可插拔导演清单）。
class DirectorThinkingStep {
  const DirectorThinkingStep({required this.order, required this.instruction});

  final int order;
  final String instruction;
}

/// 写作导演指令拼装器：
/// - 全部未启用时严格返回空字符串（0 Token 消耗）；
/// - 开启模块后按职责拼装为 KV-Cache 友好的静态规则块，并按权重动态生成静默写前推演清单；
/// - 核心镜头与 R18 档位文案走 [PromptLibraryState]，支持在「开发者工坊」实时覆写与恢复默认。
abstract final class WritingDirectorComposer {
  /// 拼装写作/续写阶段的静态导演指令块（置于 System 消息 staticPrefix）。
  static String composeStaticBlock(
    WritingDirectorConfig cfg, {
    required bool r18Enabled,
    PromptLibraryState library = const PromptLibraryState(),
  }) {
    if (!cfg.hasActiveRules(r18Enabled: r18Enabled)) return '';

    final sections = <String>[];

    final craftRules = <String>[];
    switch (cfg.cameraMode) {
      case ProseCameraMode.none:
        break;
      case ProseCameraMode.cinematic:
        craftRules.add(library.resolvedText(PromptID.directorCinematic));
      case ProseCameraMode.pureSensory:
        craftRules.add(library.resolvedText(PromptID.directorPureSensory));
    }

    if (cfg.livingHumanFeel) {
      craftRules.add(
        '【活人感加强】角色由即时情感、惯性与当下利益驱动而非机械推理；对白生活化、直白贴近日常，允许停顿、改口、废话与不完美反应，不要为了强调人设标签硬拗台词。',
      );
    }
    if (cfg.calmDailyPacing) {
      craftRules.add(
        '【日常克制 / 去狗血】非核心高潮段保持平实克制的情绪水位，不强行制造剑拔弩张的戏剧冲突，让日常交互自然流动。',
      );
    }
    if (cfg.antiClicheOpenClose) {
      craftRules.add(
        '【防公式化开头与硬收尾】\n'
        '- 禁止「像一颗石子投入平静的湖面，激起层层涟漪」式陈腐比喻开头。\n'
        '- 若整段大剧情节点尚未完结，本段结尾直接在最后一个具体动作或台词处利落切断，严禁补写「夜晚才刚刚开始」「命运悄然转动」类总结收束；大场景完整切换时才可使用 `---` 分隔。',
      );
    }
    if (cfg.strictAntiOmniscience) {
      craftRules.add(
        '【严守信息壁垒（防全知）】每位角色仅能基于自己亲眼所见、亲耳所闻或前文明确获知的信息做出推断与反应，严禁未卜先知或透视离场人物的秘密行动。',
      );
    }
    if (cfg.trackOffscreenBeats) {
      craftRules.add(
        '【场外暗线意识】参考【场外暗线演化】保持世界在主角视线之外持续运转的真实感，仅在剧情自然交汇时顺势引入，切勿生硬强塞进当前场景。',
      );
    }

    if (craftRules.isNotEmpty) {
      sections.add('【写作导演微调】\n${craftRules.join('\n')}');
    }

    if (r18Enabled) {
      final r18Lines = <String>[];
      switch (cfg.r18StylePreset) {
        case R18StylePreset.gentleDetail:
          r18Lines.add(library.resolvedText(PromptID.directorR18Gentle));
        case R18StylePreset.soothingRestrained:
          r18Lines.add(library.resolvedText(PromptID.directorR18Soothing));
        case R18StylePreset.explicitIntense:
          r18Lines.add(library.resolvedText(PromptID.directorR18Intense));
      }
      if (cfg.r18StrictOutlineGate) {
        r18Lines.add(library.resolvedText(PromptID.directorR18Gate));
      }
      if (cfg.r18IntimateDialogue) {
        r18Lines.add(
          '- 【亲密台词声感】：亲密互动时的对白可自然融入气息、停顿、低语与即时体感反馈，严格忠于该角色一贯的说话方式，禁止为了讨好硬凹 OOC 温柔或滥用符号。',
        );
      }
      sections.add('【R18 细分尺度与门控】\n${r18Lines.join('\n')}');
    }

    final steps = composeThinkingSteps(cfg, r18Enabled: r18Enabled);
    if (steps.isNotEmpty) {
      final numbered = [
        for (var i = 0; i < steps.length; i++)
          '${i + 1}. ${steps[i].instruction}',
      ].join('\n');
      sections.add(
        '【写前静默导演推演清单（仅在内部思考执行，严禁输出任何思考过程、编号或 <think> 标签到正文）】\n$numbered',
      );
    }

    return sections.join('\n\n');
  }

  /// 按权重顺序拼装动态写前推演步骤（未开启深度推演且无必须插队步骤时返回空列表）。
  static List<DirectorThinkingStep> composeThinkingSteps(
    WritingDirectorConfig cfg, {
    required bool r18Enabled,
  }) {
    if (!cfg.deepPreWriteThinking && !cfg.strictAntiOmniscience) {
      return const [];
    }
    final steps = <DirectorThinkingStep>[];

    if (cfg.deepPreWriteThinking) {
      steps.add(
        const DirectorThinkingStep(
          order: 10,
          instruction: '复盘前情脉络、上一章结尾定格姿态（衣着/道具/站位）以及待推进或回避的潜台词伏笔',
        ),
      );
    }

    if (cfg.strictAntiOmniscience) {
      steps.add(
        const DirectorThinkingStep(
          order: 20,
          instruction: '逐一界定在场每位角色当前视角能够知道的信息边界与知识盲区，确保无任何角色拥有上帝视野',
        ),
      );
    }

    if (cfg.deepPreWriteThinking) {
      steps.add(
        DirectorThinkingStep(
          order: 30,
          instruction: cfg.livingHumanFeel
              ? '推演在场角色此刻的即时情绪、生活化惯性与微反应（情感驱动优先，避免机械工具人）'
              : '推演在场每位角色此刻的深层动机、性格反差与可观察微动作',
        ),
      );
      steps.add(
        DirectorThinkingStep(
          order: 40,
          instruction: (r18Enabled && cfg.r18StrictOutlineGate)
              ? '自查本章细纲边界、世界硬规则与防八股禁令；先确认本章细纲是否明确触发亲密线，未触发则严格保持正常剧情推进'
              : '自查本章细纲边界、世界硬规则与去 AI 味禁令，提前避开设定穿帮与套话',
        ),
      );
      steps.add(
        DirectorThinkingStep(
          order: 50,
          instruction: cfg.cameraMode == ProseCameraMode.cinematic
              ? '按电影运镜编排空间光影、气味声景与远/近/特写动作分镜（动作后不附情绪解释）'
              : '编排场景空间感、光影气味与关键动作的先后节奏',
        ),
      );
      steps.add(
        const DirectorThinkingStep(
          order: 60,
          instruction: '校准不同角色的声带口吻差异，并决定结尾在哪个具体动作/台词处利落切断',
        ),
      );
    }

    steps.sort((a, b) => a.order.compareTo(b.order));
    return steps;
  }
}
