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
    description: '仅在后台任务期间播放 44.1kHz 微幅混音保持音频会话活跃（不打断其它音乐，人耳不可闻），无需额外权限。',
  ),
  lowPowerLocation(
    storageKey: 'low_power_location',
    label: '持续位置获取',
    description: '仅在后台任务期间启用活跃后台定位保活（iOS 会在状态栏显示“织命正在活跃使用你的位置”蓝标，这是系统允许持续运行的信号），绝不记录或上传坐标。',
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

/// 原生保活运行时状态快照（由 iOS `zhiming/background_keep_alive` 通道返回）。
class KeepAliveNativeStatus {
  const KeepAliveNativeStatus({
    required this.mode,
    required this.active,
    required this.audioPlaying,
    required this.locationUpdating,
    required this.locationAuth,
    required this.blueIndicatorExpected,
    this.lastError,
  });

  static const KeepAliveNativeStatus empty = KeepAliveNativeStatus(
    mode: 'none',
    active: false,
    audioPlaying: false,
    locationUpdating: false,
    locationAuth: LocationPermissionState.unknown,
    blueIndicatorExpected: false,
  );

  factory KeepAliveNativeStatus.fromMap(Map<Object?, Object?> raw) {
    return KeepAliveNativeStatus(
      mode: raw['mode']?.toString() ?? 'none',
      active: raw['active'] == true,
      audioPlaying: raw['audioPlaying'] == true,
      locationUpdating: raw['locationUpdating'] == true,
      locationAuth: LocationPermissionState.fromWire(
        raw['locationAuth']?.toString(),
      ),
      blueIndicatorExpected: raw['blueIndicatorExpected'] == true,
      lastError: raw['lastError']?.toString(),
    );
  }

  final String mode;
  final bool active;
  final bool audioPlaying;
  final bool locationUpdating;
  final LocationPermissionState locationAuth;
  final bool blueIndicatorExpected;
  final String? lastError;

  String get summaryLabel {
    if (!active) {
      if (lastError != null && lastError!.isNotEmpty) {
        return '未激活（$lastError）';
      }
      return '未激活';
    }
    if (audioPlaying) return '已激活：音频会话持续运行中';
    if (locationUpdating) {
      return blueIndicatorExpected
          ? '已激活：活跃定位中（切换至桌面应显示状态栏蓝标）'
          : '已激活：定位更新运行中';
    }
    return '已激活';
  }
}

typedef KeepAlivePlatformInvoke =
    Future<dynamic> Function(String method, [Map<String, dynamic>? arguments]);

/// 跨平台后台保活管理器：
/// - 在 iOS 上通过原生 `zhiming/background_keep_alive` 通道控制 `AVAudioPlayer`（微幅混音）或 `CLLocationManager`（活跃后台定位指示器）；
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
  KeepAliveNativeStatus _lastStatus = KeepAliveNativeStatus.empty;

  BackgroundKeepAliveMode get mode => _mode;
  int get activeCount => _activeCount;
  KeepAliveNativeStatus get lastStatus => _lastStatus;

  bool get _runsOnIos =>
      _isIos?.call() ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  @visibleForTesting
  void resetForTest() {
    _mode = BackgroundKeepAliveMode.none;
    _prefsLoaded = false;
    _nativeRunning = false;
    _activeCount = 0;
    _lastStatus = KeepAliveNativeStatus.empty;
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
      final res = await _invoker('start', {'mode': _mode.storageKey});
      _nativeRunning = true;
      if (res is Map) {
        _lastStatus = KeepAliveNativeStatus.fromMap(res);
      }
    } on MissingPluginException {
      // ignore in headless / non-iOS bindings
    } catch (_) {}
  }

  Future<void> _stopNative() async {
    if (!_runsOnIos || !_nativeRunning) return;
    try {
      final res = await _invoker('stop');
      if (res is Map) {
        _lastStatus = KeepAliveNativeStatus.fromMap(res);
      } else {
        _lastStatus = KeepAliveNativeStatus.empty;
      }
    } on MissingPluginException {
      // ignore in headless / non-iOS bindings
    } catch (_) {} finally {
      _nativeRunning = false;
    }
  }

  /// 查询当前 iOS 原生保活通道运行时状态；非 iOS 或通道未注册时返回 [KeepAliveNativeStatus.empty]。
  Future<KeepAliveNativeStatus> getStatus() async {
    if (!_runsOnIos) return KeepAliveNativeStatus.empty;
    try {
      final res = await _invoker('getStatus');
      if (res is Map) {
        _lastStatus = KeepAliveNativeStatus.fromMap(res);
        return _lastStatus;
      }
      return KeepAliveNativeStatus.empty;
    } catch (_) {
      return KeepAliveNativeStatus.empty;
    }
  }

  /// 试运行指定时长的保活自检：临时持有一次 [acquire]，并在结束后自动 [release]。
  /// 在 iOS 真机设置页可点击触发，并在试运行期间切换回桌面观察状态栏蓝标或音频后台会话。
  Future<KeepAliveNativeStatus> runSelfTest({
    Duration duration = const Duration(seconds: 6),
    void Function(KeepAliveNativeStatus status)? onStarted,
  }) async {
    await acquire();
    var snapshot = await getStatus();
    if (!snapshot.active && _lastStatus.mode == _mode.storageKey) {
      snapshot = _lastStatus;
    }
    onStarted?.call(snapshot);
    try {
      if (duration > Duration.zero) {
        await Future<void>.delayed(duration);
      }
      final latest = await getStatus();
      return latest.active || latest.lastError != null ? latest : snapshot;
    } finally {
      await release();
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
