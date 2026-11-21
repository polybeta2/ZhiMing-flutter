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
/// - `silent_audio`：在内存生成 1 秒 8kHz 静音 PCM WAV 循环播放（.playback + .mixWithOthers，不打断音乐）。
/// - `low_power_location`：使用 `kCLLocationAccuracyThreeKilometers` 低精度定位保持后台运行，不存储或上报任何坐标。
final class BackgroundKeepAliveHandler: NSObject, CLLocationManagerDelegate {
  static let shared = BackgroundKeepAliveHandler()

  private var channel: FlutterMethodChannel?
  private var currentMode: String = "none"
  private var audioPlayer: AVAudioPlayer?
  private var interruptionObserver: NSObjectProtocol?
  private var locationManager: CLLocationManager?
  private var pendingPermissionResult: FlutterResult?

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
        result(nil)
      case "stop":
        self.stop()
        result(nil)
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

  private func start(mode: String) {
    stop()
    currentMode = mode
    switch mode {
    case "silent_audio":
      startSilentAudio()
    case "low_power_location":
      startLowPowerLocation()
    default:
      currentMode = "none"
    }
  }

  private func stop() {
    currentMode = "none"
    stopSilentAudio()
    stopLowPowerLocation()
  }

  // MARK: - Silent Audio Keep-Alive

  private func startSilentAudio() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, options: [.mixWithOthers])
      try session.setActive(true)

      let player = try AVAudioPlayer(
        data: Self.buildSilentWavData(),
        fileTypeHint: AVFileType.wav.rawValue
      )
      player.numberOfLoops = -1
      player.volume = 0.0
      player.prepareToPlay()
      player.play()
      audioPlayer = player

      interruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: session,
        queue: .main
      ) { [weak self] note in
        self?.handleAudioInterruption(note)
      }
    } catch {
      audioPlayer = nil
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

    try? AVAudioSession.sharedInstance().setActive(true)
    audioPlayer?.play()
  }

  private func stopSilentAudio() {
    if let observer = interruptionObserver {
      NotificationCenter.default.removeObserver(observer)
      interruptionObserver = nil
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

  private static func buildSilentWavData() -> Data {
    let sampleRate: UInt32 = 8000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let numSamples: UInt32 = sampleRate // 1 second
    let dataSize: UInt32 = numSamples * UInt32(channels) * UInt32(bitsPerSample / 8)
    let byteRate: UInt32 = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
    let blockAlign: UInt16 = channels * (bitsPerSample / 8)

    var data = Data()
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
    data.append(Data(count: Int(dataSize)))
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

  // MARK: - Low-Power Location Keep-Alive

  private func ensureLocationManager() -> CLLocationManager {
    if let existing = locationManager {
      return existing
    }
    let manager = CLLocationManager()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    manager.distanceFilter = 500
    manager.pausesLocationUpdatesAutomatically = false
    manager.activityType = .other
    locationManager = manager
    return manager
  }

  private func startLowPowerLocation() {
    let manager = ensureLocationManager()
    let status = manager.authorizationStatus
    switch status {
    case .authorizedAlways, .authorizedWhenInUse:
      manager.allowsBackgroundLocationUpdates = true
      manager.startUpdatingLocation()
    case .notDetermined:
      manager.requestAlwaysAuthorization()
    case .denied, .restricted:
      break
    @unknown default:
      break
    }
  }

  private func stopLowPowerLocation() {
    guard let manager = locationManager else { return }
    manager.stopUpdatingLocation()
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
    if currentMode == "low_power_location",
       status == .authorizedAlways || status == .authorizedWhenInUse {
      manager.allowsBackgroundLocationUpdates = true
      manager.startUpdatingLocation()
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // 低精度定位仅用于维持 iOS 后台保活，不读取、不存储、不上传任何坐标
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
