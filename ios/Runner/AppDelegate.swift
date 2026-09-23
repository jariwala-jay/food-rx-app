import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    
    // Set notification delegate (but don't request permissions here - let Flutter handle it)
    // This prevents duplicate permission requests
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Register for remote notifications (this doesn't request permissions, just registers the device)
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Under UIScene the window/root view controller don't exist yet in
  // didFinishLaunching, so plugins and the badge channel register here.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let badgeChannel = FlutterMethodChannel(
      name: "foodrx/badge",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    badgeChannel.setMethodCallHandler { call, result in
      guard call.method == "setBadge" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let count = args["count"] as? Int else {
        result(
          FlutterError(
            code: "BAD_ARGS",
            message: "Missing or invalid 'count'",
            details: nil
          )
        )
        return
      }

      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = max(0, count)
        result(nil)
      }
    }
  }

  // Handle APNs token registration
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    print("APNs token registered: \(deviceToken)")
  }
  
  // Handle APNs registration failure
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error)")
  }
}
