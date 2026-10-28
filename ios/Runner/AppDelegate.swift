import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UNUserNotificationCenterDelegate {
  private var pushChannel: FlutterMethodChannel?
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

  func userNotificationCenter(_ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .sound])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
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

