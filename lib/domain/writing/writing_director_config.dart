import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 镜头与文风微调模式（互斥单选，可与文风档案叠加互补）。
enum ProseCameraMode {
  none(
    key: 'none',
    label: '默认',
    description: '完全跟随作品风格约束与绑定文风，不附加额外镜头规则（0 Token）。',
  ),
  cinematic(
    key: 'cinematic',
    label: '电影运镜',
    description: '新场景由远及近、角色首出场细写外观/再出场留标志特征、动作分远/近/特写拆解力度节奏、绝不直接解说情绪。',
  ),
  pureSensory(
    key: 'pure_sensory',
    label: '纯五感写实',
    description: '强压心理旁白与主观评判，所有情绪与张力完全交给可见的物理动作与五感细节承载。',
  );

  const ProseCameraMode({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;

  static ProseCameraMode fromKey(String? raw) {
    for (final v in values) {
      if (v.key == raw) return v;
    }
    return ProseCameraMode.none;
  }
}

/// R18 细分风格档位（仅在作品开启 R18 开关时生效）。
enum R18StylePreset {
  gentleDetail(
    key: 'gentle_detail',
    label: '温柔重细节',
    description: '默认。拒绝粗暴与一笔带过，堆叠五感与亲密对话，禁止「检查/培训/科学报告」式绕弯腔。',
  ),
  soothingRestrained(
    key: 'soothing_restrained',
    label: '舒缓克制',
    description: '弱化剧烈生理反应（反弓、剧烈颤抖、痉挛、尖叫等），重心放在温柔感官细节与情感流动。',
  ),
  explicitIntense(
    key: 'explicit_intense',
    label: '直白浓烈',
    description: '直白具象描写与高感官张力，不绕弯不淡出，同时保持五感细节与人物性格连贯。',
  );

  const R18StylePreset({
    required this.key,
    required this.label,
    required this.description,
  });

  final String key;
  final String label;
  final String description;

  static R18StylePreset fromKey(String? raw) {
    for (final v in values) {
      if (v.key == raw) return v;
    }
    return R18StylePreset.gentleDetail;
  }
}

/// 单书「写作导演开关」配置（未开启项严格 0 Token 消耗，按书持久化于 SharedPreferences）。
class WritingDirectorConfig {
  const WritingDirectorConfig({
    this.cameraMode = ProseCameraMode.none,
    this.livingHumanFeel = false,
    this.calmDailyPacing = false,
    this.antiClicheOpenClose = false,
    this.strictAntiOmniscience = false,
    this.deepPreWriteThinking = false,
    this.trackOffscreenBeats = false,
    this.r18StylePreset = R18StylePreset.gentleDetail,
    this.r18StrictOutlineGate = true,
    this.r18IntimateDialogue = false,
  });

  final ProseCameraMode cameraMode;
  final bool livingHumanFeel;
  final bool calmDailyPacing;
  final bool antiClicheOpenClose;
  final bool strictAntiOmniscience;
  final bool deepPreWriteThinking;
  final bool trackOffscreenBeats;

  // 以下仅在 novel.r18Enabled == true 时生效
  final R18StylePreset r18StylePreset;
  final bool r18StrictOutlineGate;
  final bool r18IntimateDialogue;

  bool hasActiveRules({required bool r18Enabled}) =>
      cameraMode != ProseCameraMode.none ||
      livingHumanFeel ||
      calmDailyPacing ||
      antiClicheOpenClose ||
      strictAntiOmniscience ||
      deepPreWriteThinking ||
      trackOffscreenBeats ||
      r18Enabled;

  /// 用于编辑器弹窗与自动撰写面板展示的精简生效标签列表。
  List<String> activeLabels({required bool r18Enabled}) {
    final labels = <String>[];
    if (cameraMode != ProseCameraMode.none) labels.add(cameraMode.label);
    if (livingHumanFeel) labels.add('活人感');
    if (calmDailyPacing) labels.add('日常克制');
    if (antiClicheOpenClose) labels.add('防公式开合');
    if (strictAntiOmniscience) labels.add('严守防全知');
    if (deepPreWriteThinking) labels.add('深度导演推演');
    if (trackOffscreenBeats) labels.add('场外暗线');
    if (r18Enabled) {
      labels.add('R18·${r18StylePreset.label}');
      if (r18StrictOutlineGate) labels.add('防日常发情');
      if (r18IntimateDialogue) labels.add('声感对白');
    }
    return labels;
  }

  WritingDirectorConfig copyWith({
    ProseCameraMode? cameraMode,
    bool? livingHumanFeel,
    bool? calmDailyPacing,
    bool? antiClicheOpenClose,
    bool? strictAntiOmniscience,
    bool? deepPreWriteThinking,
    bool? trackOffscreenBeats,
    R18StylePreset? r18StylePreset,
    bool? r18StrictOutlineGate,
    bool? r18IntimateDialogue,
  }) {
    return WritingDirectorConfig(
      cameraMode: cameraMode ?? this.cameraMode,
      livingHumanFeel: livingHumanFeel ?? this.livingHumanFeel,
      calmDailyPacing: calmDailyPacing ?? this.calmDailyPacing,
      antiClicheOpenClose: antiClicheOpenClose ?? this.antiClicheOpenClose,
      strictAntiOmniscience:
          strictAntiOmniscience ?? this.strictAntiOmniscience,
      deepPreWriteThinking: deepPreWriteThinking ?? this.deepPreWriteThinking,
      trackOffscreenBeats: trackOffscreenBeats ?? this.trackOffscreenBeats,
      r18StylePreset: r18StylePreset ?? this.r18StylePreset,
      r18StrictOutlineGate: r18StrictOutlineGate ?? this.r18StrictOutlineGate,
      r18IntimateDialogue: r18IntimateDialogue ?? this.r18IntimateDialogue,
    );
  }

  Map<String, dynamic> toJson() => {
    'cameraMode': cameraMode.key,
    'livingHumanFeel': livingHumanFeel,
    'calmDailyPacing': calmDailyPacing,
    'antiClicheOpenClose': antiClicheOpenClose,
    'strictAntiOmniscience': strictAntiOmniscience,
    'deepPreWriteThinking': deepPreWriteThinking,
    'trackOffscreenBeats': trackOffscreenBeats,
    'r18StylePreset': r18StylePreset.key,
    'r18StrictOutlineGate': r18StrictOutlineGate,
    'r18IntimateDialogue': r18IntimateDialogue,
  };

  factory WritingDirectorConfig.fromJson(Map<String, dynamic> json) {
    return WritingDirectorConfig(
      cameraMode: ProseCameraMode.fromKey(json['cameraMode']?.toString()),
      livingHumanFeel: json['livingHumanFeel'] == true,
      calmDailyPacing: json['calmDailyPacing'] == true,
      antiClicheOpenClose: json['antiClicheOpenClose'] == true,
      strictAntiOmniscience: json['strictAntiOmniscience'] == true,
      deepPreWriteThinking: json['deepPreWriteThinking'] == true,
      trackOffscreenBeats: json['trackOffscreenBeats'] == true,
      r18StylePreset: R18StylePreset.fromKey(
        json['r18StylePreset']?.toString(),
      ),
      r18StrictOutlineGate: json['r18StrictOutlineGate'] != false,
      r18IntimateDialogue: json['r18IntimateDialogue'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WritingDirectorConfig &&
      other.cameraMode == cameraMode &&
      other.livingHumanFeel == livingHumanFeel &&
      other.calmDailyPacing == calmDailyPacing &&
      other.antiClicheOpenClose == antiClicheOpenClose &&
      other.strictAntiOmniscience == strictAntiOmniscience &&
      other.deepPreWriteThinking == deepPreWriteThinking &&
      other.trackOffscreenBeats == trackOffscreenBeats &&
      other.r18StylePreset == r18StylePreset &&
      other.r18StrictOutlineGate == r18StrictOutlineGate &&
      other.r18IntimateDialogue == r18IntimateDialogue;

  @override
  int get hashCode => Object.hash(
    cameraMode,
    livingHumanFeel,
    calmDailyPacing,
    antiClicheOpenClose,
    strictAntiOmniscience,
    deepPreWriteThinking,
    trackOffscreenBeats,
    r18StylePreset,
    r18StrictOutlineGate,
    r18IntimateDialogue,
  );
}

/// 单书导演配置持久化仓库（不改动 Drift Schema，按 novelId 独立隔离）。
abstract final class WritingDirectorStore {
  static String keyFor(String novelId) => 'writing_director.v1.$novelId';

  static Future<WritingDirectorConfig> load(String novelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyFor(novelId));
      if (raw == null || raw.trim().isEmpty) {
        return const WritingDirectorConfig();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return WritingDirectorConfig.fromJson(
          decoded.cast<String, dynamic>(),
        );
      }
    } catch (_) {}
    return const WritingDirectorConfig();
  }

  static Future<void> save(
    String novelId,
    WritingDirectorConfig config,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyFor(novelId), jsonEncode(config.toJson()));
    } catch (_) {}
  }

  static Future<void> delete(String novelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(novelId));
    } catch (_) {}
  }
}

class WritingDirectorNotifier
    extends FamilyNotifier<WritingDirectorConfig, String> {
  @override
  WritingDirectorConfig build(String arg) {
    _load(arg);
    return const WritingDirectorConfig();
  }

  Future<void> _load(String novelId) async {
    final loaded = await WritingDirectorStore.load(novelId);
    state = loaded;
  }

  Future<void> update(
    WritingDirectorConfig Function(WritingDirectorConfig current) transform,
  ) async {
    final next = transform(state);
    state = next;
    await WritingDirectorStore.save(arg, next);
  }
}

final writingDirectorProvider = NotifierProvider.family<
  WritingDirectorNotifier,
  WritingDirectorConfig,
  String
>(WritingDirectorNotifier.new);
