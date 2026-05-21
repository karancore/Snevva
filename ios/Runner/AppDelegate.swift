import Flutter
import UIKit
import CoreMotion
import BackgroundTasks
import flutter_local_notifications
import QuartzCore

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let displayConfigChannelName = "com.coretegra.snevvaa/display_config"
  private let timezoneChannelName = "com.coretegra.snevvaa/timezone"
  private let stepServiceChannelName = "com.coretegra.snevvaa/step_service"

  private let pedometer = CMPedometer()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: self)

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    if #available(iOS 13.0, *) {
      registerBGTasks()
    }

    let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureDisplayConfigChannel()
    configureTimezoneChannel()
    configureStepServiceChannel()
    _ = requestHighRefreshRateIfAvailable()
    startPedometerTracking()
    return didFinish
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    _ = requestHighRefreshRateIfAvailable()
    startPedometerTracking()
  }

  // MARK: - Display Config

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

  // MARK: - Timezone

  private func configureTimezoneChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: timezoneChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getTimeZoneId":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Step Service

  private func configureStepServiceChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: stepServiceChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startStepService":
        self?.startPedometerTracking()
        result(true)
      case "stopStepService":
        self?.pedometer.stopUpdates()
        result(true)
      case "seedTodaySteps":
        // No-op on iOS — CMPedometer tracks natively from the motion coprocessor
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // Starts (or restarts) CMPedometer from the beginning of the current day.
  // Called on launch and on every app-active transition so the step count
  // stays accurate across midnight crossings.
  private func startPedometerTracking() {
    guard CMPedometer.isStepCountingAvailable() else { return }

    pedometer.stopUpdates()
    let startOfDay = Calendar.current.startOfDay(for: Date())

    pedometer.startUpdates(from: startOfDay) { data, error in
      guard let data = data, error == nil else { return }
      let steps = data.numberOfSteps.intValue
      // flutter. prefix matches how shared_preferences stores keys on iOS
      UserDefaults.standard.set(steps, forKey: "flutter.today_steps")
    }
  }

  // MARK: - BGTask Registration

  @available(iOS 13.0, *)
  private func registerBGTasks() {
    let noopHandler: (BGTask) -> Void = { task in
      task.setTaskCompleted(success: true)
    }
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.coretegra.snevva.sleep_calc", using: nil, launchHandler: noopHandler
    )
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.coretegra.snevva.api_sync", using: nil, launchHandler: noopHandler
    )
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.coretegra.snevva.period_sync", using: nil, launchHandler: noopHandler
    )
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.coretegra.snevvaa.reminderReconcile", using: nil, launchHandler: noopHandler
    )
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: "com.coretegra.snevvaa.reminderOneShot", using: nil, launchHandler: noopHandler
    )
  }

  // MARK: - Display Helpers

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