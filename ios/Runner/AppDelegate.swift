import Flutter
import UIKit
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private let locationProvider = AutomotorsLocationProvider()
  private var dartReady = false
  private var deviceToken: String?
  private var pendingNotification: [String: Any]?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AutomotorsPush") else { return }
    let channel = FlutterMethodChannel(name: "automotors/push", binaryMessenger: registrar.messenger())
    pushChannel = channel
    let locationChannel = FlutterMethodChannel(name: "automotors/location", binaryMessenger: registrar.messenger())
    locationChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "request" else { result(FlutterMethodNotImplemented); return }
      self?.locationProvider.request(result)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "initialize":
        self.dartReady = true
        var state: [String: Any] = [:]
        if let token = self.deviceToken { state["device"] = self.deviceInfo(token) }
        if let notification = self.pendingNotification { state["notification"] = notification }
        self.pendingNotification = nil
        result(state)
      case "register":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
          DispatchQueue.main.async {
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            result(granted)
          }
        }
      case "unregister":
        UIApplication.shared.unregisterForRemoteNotifications()
        self.deviceToken = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func deviceInfo(_ token: String) -> [String: Any] {
    let configured = Bundle.main.object(forInfoDictionaryKey: "AutomotorsAPNSEnvironment") as? String
    return ["token": token, "environment": configured == "development" ? "sandbox" : "production"]
  }

  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    let value = token.map { String(format: "%02x", $0) }.joined()
    deviceToken = value
    if dartReady { pushChannel?.invokeMethod("deviceToken", arguments: deviceInfo(value)) }
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)
  }

  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    // Do not expose native registration details or tokens in logs.
    if dartReady { pushChannel?.invokeMethod("registrationFailed", arguments: nil) }
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void) {
    if response.actionIdentifier != UNNotificationDismissActionIdentifier {
      // Only pass routing identifiers to Dart. It checks the signed-in account.
      let info = response.notification.request.content.userInfo
      var route: [String: Any] = [:]
      for key in ["notification_id", "kind", "user_id", "listing_id", "conversation_id"] {
        if let value = info[key] as? String { route[key] = value }
      }
      if dartReady { pushChannel?.invokeMethod("notificationOpened", arguments: route) }
      else { pendingNotification = route }
    }
    completionHandler()
  }
}

/// Foreground, single-fix search only; precise coordinates never cross to Dart.
private final class AutomotorsLocationProvider: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var pending: FlutterResult?
  private var timeout: DispatchWorkItem?
  private var requestingFix = false

  override init() {
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
  }

  func request(_ result: @escaping FlutterResult) {
    guard pending == nil else { result(["status": "busy"]); return }
    pending = result
    authorize()
  }

  private func authorize() {
    guard pending != nil else { return }
    switch manager.authorizationStatus {
    case .notDetermined: manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      guard !requestingFix else { return }
      requestingFix = true
      let task = DispatchWorkItem { [weak self] in self?.finish(["status": "unavailable"]) }
      timeout = task
      DispatchQueue.main.asyncAfter(deadline: .now() + 25, execute: task)
      manager.requestLocation()
    default: finish(["status": "denied"])
    }
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { authorize() }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last, location.horizontalAccuracy >= 0,
          abs(location.timestamp.timeIntervalSinceNow) < 60 else {
      finish(["status": "unavailable"]); return
    }
    let coordinate = location.coordinate
    finish(["status": "ok", "lat": (coordinate.latitude * 100).rounded() / 100,
            "lon": (coordinate.longitude * 100).rounded() / 100])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finish(["status": "unavailable"])
  }

  private func finish(_ value: [String: Any]) {
    timeout?.cancel()
    timeout = nil
    manager.stopUpdatingLocation()
    requestingFix = false
    let result = pending
    pending = nil
    result?(value)
  }
}

