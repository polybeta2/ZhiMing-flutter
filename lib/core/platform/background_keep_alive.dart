import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iOS 后台保活方案（用于长篇原作扫描 / 自动撰写 / 文风蒸馏等耗时任务）。
enum BackgroundKeepAliveMode {
  none(
    storageKey: 'none',
    label: '不保活',
    description: '默认。切至后台或锁屏约 30 秒后系统将挂起网络任务，最省电。',
  ),
  silentAudio(
    storageKey: 'silent_audio',
    label: '静音音频',
    description: '仅在后台扫描/长任务运行期间循环播放无声音频（混音不打断其它音乐），保活最稳定，无需额外权限。',
  ),
  lowPowerLocation(
    storageKey: 'low_power_location',
    label: '持续位置获取',
    description: '仅在后台扫描/长任务运行期间启用 3km 低精度定位保活，不记录也不上传任何坐标；首次使用需授予定位权限。',
  );

  const BackgroundKeepAliveMode({
    required this.storageKey,
    required this.label,
    required this.description,
  });

  final String storageKey;
  final String label;
  final String description;

  static BackgroundKeepAliveMode fromStorageKey(String? raw) {
    for (final mode in values) {
      if (mode.storageKey == raw) return mode;
    }
    return BackgroundKeepAliveMode.none;
  }
}

/// iOS 位置权限状态（仅当选择「持续位置获取」时使用）。
enum LocationPermissionState {
  unknown,
  notDetermined,
  authorizedAlways,
  authorizedWhenInUse,
  denied,
  restricted;

  static LocationPermissionState fromWire(String? raw) => switch (raw) {
    'notDetermined' => LocationPermissionState.notDetermined,
    'authorizedAlways' => LocationPermissionState.authorizedAlways,
    'authorizedWhenInUse' => LocationPermissionState.authorizedWhenInUse,
    'denied' => LocationPermissionState.denied,
    'restricted' => LocationPermissionState.restricted,
    _ => LocationPermissionState.unknown,
  };

  bool get isGranted =>
      this == authorizedAlways || this == authorizedWhenInUse;

  bool get isDenied => this == denied || this == restricted;

  String get displayLabel => switch (this) {
    LocationPermissionState.unknown => '未检测',
    LocationPermissionState.notDetermined => '待授权（选择后将弹出系统授权）',
    LocationPermissionState.authorizedAlways => '已授予“始终允许”',
    LocationPermissionState.authorizedWhenInUse => '已授予“使用 App 期间”（支持后台蓝标保活）',
    LocationPermissionState.denied => '已被拒绝（需前往系统设置开启）',
    LocationPermissionState.restricted => '受系统限制无法开启',
  };
}

typedef KeepAlivePlatformInvoke =
    Future<dynamic> Function(String method, [Map<String, dynamic>? arguments]);

/// 跨平台后台保活管理器：
/// - 在 iOS 上通过原生 `zhiming/background_keep_alive` 通道控制 `AVAudioPlayer`（静音混音）或 `CLLocationManager`（3km 低精度）；
/// - 使用引用计数（[acquire] / [release]），仅在扫描/自动撰写/文风蒸馏等任务活跃期间启停保活；
/// - 在 Windows / macOS / Linux / Web 与单元测试环境下自动安全降级为无操作。
class BackgroundKeepAliveService {
  BackgroundKeepAliveService._({
    KeepAlivePlatformInvoke? invoker,
    bool Function()? isIosOverride,
  }) : _invoker = invoker ?? _defaultInvoke,
       _isIos = isIosOverride;

  @visibleForTesting
  factory BackgroundKeepAliveService.forTesting({
    KeepAlivePlatformInvoke? invoker,
    bool isIos = true,
  }) => BackgroundKeepAliveService._(
    invoker: invoker,
    isIosOverride: () => isIos,
  );

  static final BackgroundKeepAliveService instance =
      BackgroundKeepAliveService._();

  static const String prefKey = 'background.keepAliveMode';
  static const MethodChannel _channel = MethodChannel(
    'zhiming/background_keep_alive',
  );

  static Future<dynamic> _defaultInvoke(
    String method, [
    Map<String, dynamic>? arguments,
  ]) => _channel.invokeMethod<dynamic>(method, arguments);

  final KeepAlivePlatformInvoke _invoker;
  final bool Function()? _isIos;

  BackgroundKeepAliveMode _mode = BackgroundKeepAliveMode.none;
  bool _prefsLoaded = false;
  bool _nativeRunning = false;
  int _activeCount = 0;

  BackgroundKeepAliveMode get mode => _mode;
  int get activeCount => _activeCount;

  bool get _runsOnIos =>
      _isIos?.call() ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @visibleForTesting
  void resetForTest() {
    _mode = BackgroundKeepAliveMode.none;
    _prefsLoaded = false;
    _nativeRunning = false;
    _activeCount = 0;
  }

  /// 从 SharedPreferences 加载用户选择的后台保活模式（幂等，若已通过 setMode 设置则保留内存值）。
  Future<BackgroundKeepAliveMode> loadFromPrefs() async {
    if (_prefsLoaded) return _mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_prefsLoaded) {
        _mode = BackgroundKeepAliveMode.fromStorageKey(
          prefs.getString(prefKey),
        );
        _prefsLoaded = true;
      }
    } catch (_) {
      _prefsLoaded = true;
    }
    return _mode;
  }

  /// 更新后台保活方案并持久化；若当前已有任务在运行，立即热切换原生保活会话。
  Future<void> setMode(BackgroundKeepAliveMode next) async {
    _mode = next;
    _prefsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, next.storageKey);
    } catch (_) {}

    if (_activeCount > 0) {
      await _syncNative();
    }
  }

  /// 为当前长任务获取保活会话；需与 [release] 成对在 try/finally 中调用。
  Future<void> acquire() async {
    await loadFromPrefs();
    _activeCount += 1;
    if (_activeCount == 1) {
      await _syncNative();
    }
  }

  /// 释放保活会话；计数归零时停止原生音频播放或定位监听。
  Future<void> release() async {
    if (_activeCount <= 0) {
      _activeCount = 0;
      return;
    }
    _activeCount -= 1;
    if (_activeCount == 0) {
      await _stopNative();
    }
  }

  Future<void> _syncNative() async {
    if (!_runsOnIos) return;
    if (_mode == BackgroundKeepAliveMode.none) {
      await _stopNative();
      return;
    }
    try {
      await _invoker('start', {'mode': _mode.storageKey});
      _nativeRunning = true;
    } on MissingPluginException {
      // ignore in headless / non-iOS bindings
    } catch (_) {}
  }

  Future<void> _stopNative() async {
    if (!_runsOnIos || !_nativeRunning) return;
    try {
      await _invoker('stop');
    } on MissingPluginException {
      // ignore in headless / non-iOS bindings
    } catch (_) {} finally {
      _nativeRunning = false;
    }
  }

  /// 查询 iOS 位置权限状态；非 iOS 返回 [LocationPermissionState.unknown]。
  Future<LocationPermissionState> getLocationPermission() async {
    if (!_runsOnIos) return LocationPermissionState.unknown;
    try {
      final res = await _invoker('getLocationPermission');
      return LocationPermissionState.fromWire(res?.toString());
    } catch (_) {
      return LocationPermissionState.unknown;
    }
  }

  /// 请求 iOS 后台定位权限；非 iOS 返回 [LocationPermissionState.unknown]。
  Future<LocationPermissionState> requestLocationPermission() async {
    if (!_runsOnIos) return LocationPermissionState.unknown;
    try {
      final res = await _invoker('requestLocationPermission');
      return LocationPermissionState.fromWire(res?.toString());
    } catch (_) {
      return LocationPermissionState.unknown;
    }
  }

  /// 打开系统应用设置页（用于定位权限被拒绝后引导开启）。
  Future<void> openAppSettings() async {
    if (!_runsOnIos) return;
    try {
      await _invoker('openAppSettings');
    } catch (_) {}
  }
}

class BackgroundKeepAliveNotifier extends Notifier<BackgroundKeepAliveMode> {
  @override
  BackgroundKeepAliveMode build() {
    _load();
    return BackgroundKeepAliveService.instance.mode;
  }

  Future<void> _load() async {
    final loaded = await BackgroundKeepAliveService.instance.loadFromPrefs();
    state = loaded;
  }

  Future<void> setMode(BackgroundKeepAliveMode mode) async {
    state = mode;
    await BackgroundKeepAliveService.instance.setMode(mode);
  }
}

final backgroundKeepAliveProvider =
    NotifierProvider<BackgroundKeepAliveNotifier, BackgroundKeepAliveMode>(
      BackgroundKeepAliveNotifier.new,
    );
