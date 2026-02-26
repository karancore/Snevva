import Flutter
import UIKit
import flutter_local_notifications
import QuartzCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let displayConfigChannelName = "com.coretegra.snevva/display_config"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureDisplayConfigChannel()
    _ = requestHighRefreshRateIfAvailable()
    return didFinish
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    _ = requestHighRefreshRateIfAvailable()
  }

  private func configureDisplayConfigChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: displayConfigChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(
          FlutterError(
            code: "APP_DELEGATE_RELEASED",
            message: "AppDelegate is unavailable",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "getDisplayRefreshRate":
        result(self.currentDisplayRefreshRate())
      case "getHighestSupportedRefreshRate":
        result(self.currentDisplayRefreshRate())
      case "requestHighestRefreshRate":
        result(self.requestHighRefreshRateIfAvailable())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func currentDisplayRefreshRate() -> Double {
    return Double(UIScreen.main.maximumFramesPerSecond)
  }

  @discardableResult
  private func requestHighRefreshRateIfAvailable() -> Bool {
    guard #available(iOS 15.0, *) else { return false }
    guard UIScreen.main.maximumFramesPerSecond >= 120 else { return false }

    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      windowScene.preferredFrameRateRange = CAFrameRateRange(
        minimum: 80,
        maximum: 120,
        preferred: 120
      )
    }
    return true
  }
}
