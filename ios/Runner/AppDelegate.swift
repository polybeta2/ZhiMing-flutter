import AVFoundation
import CoreLocation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZhiMingBackgroundKeepAlive") {
      BackgroundKeepAliveHandler.shared.register(messenger: registrar.messenger())
    }
  }
}

/// iOS 后台保活原生实现：
/// - `silent_audio`：在临时目录生成 2 秒 44.1kHz ±1 LSB 抖动微幅音频 WAV 文件并通过 `.playback + .mixWithOthers` 循环播放，
///   在极低音量（0.01，人耳不可闻）下避免 `mediaserverd` 因全零 PCM 挂起进程，同时处理音频打断、路由变更与进后台加固。
/// - `low_power_location`：使用 `kCLLocationAccuracyNearestTenMeters` + `distanceFilter = kCLDistanceFilterNone`
///   并开启 `allowsBackgroundLocationUpdates = true` 与 `showsBackgroundLocationIndicator = true`（iOS 15+ 蓝标活跃保活），
///   仅用于长任务期间保活，绝不读取、存储或上传任何位置坐标。
final class BackgroundKeepAliveHandler: NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundKeepAliveHandler()

  private var channel: FlutterMethodChannel?
  private var currentMode: String = "none"
  private var audioPlayer: AVAudioPlayer?
  private var interruptionObserver: NSObjectProtocol?
  private var routeChangeObserver: NSObjectProtocol?
  private var didEnterBackgroundObserver: NSObjectProtocol?
  private var locationManager: CLLocationManager?
  private var isLocationUpdating: Bool = false
  private var pendingPermissionResult: FlutterResult?
  private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
  private var lastError: String?

  func register(messenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "zhiming/background_keep_alive",
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
    channel = methodChannel
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "start":
        let args = call.arguments as? [String: Any]
        let mode = (args?["mode"] as? String) ?? "none"
        self.start(mode: mode)
        result(self.buildStatusPayload())
      case "stop":
        self.stop()
        result(self.buildStatusPayload())
      case "getStatus":
        result(self.buildStatusPayload())
      case "getLocationPermission":
        result(self.wireStatus(self.ensureLocationManager().authorizationStatus))
      case "requestLocationPermission":
        self.requestLocationPermission(result: result)
      case "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func buildStatusPayload() -> [String: Any] {
    let authStatus = ensureLocationManager().authorizationStatus
    let audioPlaying = audioPlayer?.isPlaying ?? false
    let active =
      (currentMode == "silent_audio" && audioPlaying) ||
      (currentMode == "low_power_location" && isLocationUpdating)
    let blueIndicatorExpected =
      currentMode == "low_power_location" &&
      isLocationUpdating &&
      (authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways)
    var payload: [String: Any] = [
      "mode": currentMode,
      "active": active,
      "audioPlaying": audioPlaying,
      "locationUpdating": isLocationUpdating,
      "locationAuth": wireStatus(authStatus),
      "blueIndicatorExpected": blueIndicatorExpected,
    ]
    if let err = lastError, !err.isEmpty {
      payload["lastError"] = err
    }
    return payload
  }

  private func start(mode: String) {
    stop()
    lastError = nil
    currentMode = mode
    switch mode {
    case "silent_audio":
      startSilentAudio()
      installDidEnterBackgroundObserver()
    case "low_power_location":
      startLowPowerLocation()
      installDidEnterBackgroundObserver()
    default:
      currentMode = "none"
    }
  }

  private func stop() {
    currentMode = "none"
    lastError = nil
    removeDidEnterBackgroundObserver()
    endSafetyBackgroundTask()
    stopSilentAudio()
    stopLowPowerLocation()
  }

  // MARK: - Background Transition Guard

  private func installDidEnterBackgroundObserver() {
    guard didEnterBackgroundObserver == nil else { return }
    didEnterBackgroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.reinforceOnEnterBackground()
    }
  }

  private func removeDidEnterBackgroundObserver() {
    if let observer = didEnterBackgroundObserver {
      NotificationCenter.default.removeObserver(observer)
      didEnterBackgroundObserver = nil
    }
  }

  private func reinforceOnEnterBackground() {
    guard currentMode != "none" else { return }
    endSafetyBackgroundTask()
    backgroundTaskId = UIApplication.shared.beginBackgroundTask(
      withName: "ZhiMingKeepAliveEnsure"
    ) { [weak self] in
      self?.endSafetyBackgroundTask()
    }

    if currentMode == "silent_audio" {
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try? session.setActive(true)
      if let player = audioPlayer, !player.isPlaying {
        player.play()
      }
    } else if currentMode == "low_power_location", let manager = locationManager {
      let status = manager.authorizationStatus
      if status == .authorizedAlways || status == .authorizedWhenInUse {
        manager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
          manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        isLocationUpdating = true
      }
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      self?.endSafetyBackgroundTask()
    }
  }

  private func endSafetyBackgroundTask() {
    if backgroundTaskId != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTaskId)
      backgroundTaskId = .invalid
    }
  }

  // MARK: - Silent Audio Keep-Alive

  private func startSilentAudio() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
      try session.setActive(true)

      let wavURL = try Self.ensureSilentWavFile()
      let player = try AVAudioPlayer(contentsOf: wavURL)
      player.numberOfLoops = -1
      player.volume = 0.01
      player.prepareToPlay()
      let started = player.play()
      audioPlayer = player
      if !started || !player.isPlaying {
        lastError = "AVAudioPlayer 启动播放失败"
      }

      interruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: session,
        queue: .main
      ) { [weak self] note in
        self?.handleAudioInterruption(note)
      }

      routeChangeObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.routeChangeNotification,
        object: session,
        queue: .main
      ) { [weak self] _ in
        self?.resumeSilentAudioIfNeeded()
      }
    } catch {
      audioPlayer = nil
      lastError = "音频保活初始化失败：\(error.localizedDescription)"
    }
  }

  private func handleAudioInterruption(_ notification: Notification) {
    guard
      currentMode == "silent_audio",
      let info = notification.userInfo,
      let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType),
      type == .ended
    else { return }
    resumeSilentAudioIfNeeded()
  }

  private func resumeSilentAudioIfNeeded() {
    guard currentMode == "silent_audio" else { return }
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
    if let player = audioPlayer, !player.isPlaying {
      player.play()
    }
  }

  private func stopSilentAudio() {
    if let observer = interruptionObserver {
      NotificationCenter.default.removeObserver(observer)
      interruptionObserver = nil
    }
    if let observer = routeChangeObserver {
      NotificationCenter.default.removeObserver(observer)
      routeChangeObserver = nil
    }
    if let player = audioPlayer {
      player.stop()
      audioPlayer = nil
      try? AVAudioSession.sharedInstance().setActive(
        false,
        options: .notifyOthersOnDeactivation
      )
    }
  }

  private static func ensureSilentWavFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("zhiming_keep_alive_44k.wav")
    let sampleRate: UInt32 = 44100
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let numSamples: UInt32 = sampleRate * 2 // 2 seconds
    let dataSize: UInt32 = numSamples * UInt32(channels) * UInt32(bitsPerSample / 8)
    let expectedTotalSize = Int(44 + dataSize)

    if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
       let existingSize = attrs[.size] as? Int,
       existingSize == expectedTotalSize {
      return url
    }

    let wavData = buildDitherSilentWavData(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      numSamples: numSamples
    )
    try wavData.write(to: url, options: .atomic)
    return url
  }

  private static func buildDitherSilentWavData(
    sampleRate: UInt32,
    channels: UInt16,
    bitsPerSample: UInt16,
    numSamples: UInt32
  ) -> Data {
    let bytesPerSample = UInt32(bitsPerSample / 8)
    let dataSize: UInt32 = numSamples * UInt32(channels) * bytesPerSample
    let byteRate: UInt32 = sampleRate * UInt32(channels) * bytesPerSample
    let blockAlign: UInt16 = channels * (bitsPerSample / 8)

    var data = Data(capacity: Int(44 + dataSize))
    data.append("RIFF".data(using: .ascii)!)
    appendLE32(&data, 36 + dataSize)
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)
    appendLE32(&data, 16) // PCM fmt chunk size
    appendLE16(&data, 1)  // PCM format
    appendLE16(&data, channels)
    appendLE32(&data, sampleRate)
    appendLE32(&data, byteRate)
    appendLE16(&data, blockAlign)
    appendLE16(&data, bitsPerSample)
    data.append("data".data(using: .ascii)!)
    appendLE32(&data, dataSize)

    // Alternating +1 / -1 Int16 LSB dither (~ -90 dBFS): hardware-active yet physically inaudible.
    var pcm = Data(capacity: Int(dataSize))
    for idx in 0..<numSamples {
      let sample: Int16 = (idx % 2 == 0) ? 1 : -1
      var le = sample.littleEndian
      withUnsafeBytes(of: &le) { pcm.append(contentsOf: $0) }
    }
    data.append(pcm)
    return data
  }

  private static func appendLE32(_ data: inout Data, _ value: UInt32) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
  }

  private static func appendLE16(_ data: inout Data, _ value: UInt16) {
    var le = value.littleEndian
    withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
  }

  // MARK: - Active Background Location Keep-Alive

  private func ensureLocationManager() -> CLLocationManager {
    if let existing = locationManager {
      return existing
    }
    let manager = CLLocationManager()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.distanceFilter = kCLDistanceFilterNone
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .otherNavigation
    locationManager = manager
    return manager
  }

  private func activateLocationUpdates(_ manager: CLLocationManager) {
    manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    manager.distanceFilter = kCLDistanceFilterNone
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .otherNavigation
    manager.allowsBackgroundLocationUpdates = true
    if #available(iOS 11.0, *) {
      manager.showsBackgroundLocationIndicator = true
    }
    manager.startUpdatingLocation()
    isLocationUpdating = true
    lastError = nil
  }

  private func startLowPowerLocation() {
    let manager = ensureLocationManager()
    let status = manager.authorizationStatus
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      activateLocationUpdates(manager)
    case .notDetermined:
      isLocationUpdating = false
      manager.requestAlwaysAuthorization()
    case .denied, .restricted:
      isLocationUpdating = false
      lastError = "定位权限被拒或受限，无法启动后台位置保活"
    @unknown default:
      isLocationUpdating = false
    }
  }

  private func stopLowPowerLocation() {
    isLocationUpdating = false
    guard let manager = locationManager else { return }
    manager.stopUpdatingLocation()
    if #available(iOS 11.0, *) {
      manager.showsBackgroundLocationIndicator = false
    }
    manager.allowsBackgroundLocationUpdates = false
  }

  private func requestLocationPermission(result: @escaping FlutterResult) {
    let manager = ensureLocationManager()
    let status = manager.authorizationStatus
    if status != .notDetermined {
      result(wireStatus(status))
      return
    }
    if let prev = pendingPermissionResult {
      prev(wireStatus(status))
    }
    pendingPermissionResult = result
    manager.requestAlwaysAuthorization()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    if let pending = pendingPermissionResult, status != .notDetermined {
      pendingPermissionResult = nil
      pending(wireStatus(status))
    }
    if currentMode == "low_power_location" {
      if status == .authorizedAlways || status == .authorizedWhenInUse {
        activateLocationUpdates(manager)
      } else if status == .denied || status == .restricted {
        isLocationUpdating = false
        lastError = "定位权限被拒或受限"
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 后台定位仅用于触发 iOS 活跃保活标识并维持进程调度，绝不读取、存储或上传任何坐标
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let nsError = error as NSError
    if nsError.domain == kCLErrorDomain && nsError.code == CLError.Code.locationUnknown.rawValue {
      // 瞬时搜星中（iOS 会继续重试），不视为失败
      return
    }
    if nsError.domain == kCLErrorDomain && nsError.code == CLError.Code.denied.rawValue {
      isLocationUpdating = false
    }
    lastError = error.localizedDescription
  }

  private func wireStatus(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .notDetermined:
      return "notDetermined"
    case .authorizedAlways:
      return "authorizedAlways"
    case .authorizedWhenInUse:
      return "authorizedWhenInUse"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    @unknown default:
      return "unknown"
    }
  }
}
