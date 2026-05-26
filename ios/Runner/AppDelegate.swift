import Flutter
import UIKit
import CoreMotion
import BackgroundTasks
import flutter_local_notifications
import QuartzCore
import FirebaseCore

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let displayConfigChannelName = "com.coretegra.snevvaa/display_config"
  private let timezoneChannelName = "com.coretegra.snevvaa/timezone"
  private let stepServiceChannelName = "com.coretegra.snevvaa/step_service"

  private let pedometer = CMPedometer()
  private var displayLink: CADisplayLink?

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // 1. Super first — Flutter engine and plugins initialize here
    let didFinish = super.application(
        application,
        didFinishLaunchingWithOptions: launchOptions
    )

    // 2. Plugin registrant callback before any plugin tries to use it
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // 3. GeneratedPluginRegistrant already called inside super, no need to call again

    // 4. Firebase configure — now safe, only called once
    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    if #available(iOS 13.0, *) {
      registerBGTasks()
    }

    configureDisplayConfigChannel()
    configureTimezoneChannel()
    configureStepServiceChannel()

    _ = requestHighRefreshRateIfAvailable()
    startPedometerTracking()

    return didFinish
  }

  // MARK: - UIScene lifecycle (required for iOS 13+ scene-based apps)

  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    return UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
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
        // No-op on iOS
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Pedometer

  private func startPedometerTracking() {

    guard CMPedometer.isStepCountingAvailable() else {
      return
    }

    pedometer.stopUpdates()

    let startOfDay = Calendar.current.startOfDay(for: Date())

    pedometer.startUpdates(from: startOfDay) { data, error in

      guard let data = data, error == nil else {
        return
      }

      let steps = data.numberOfSteps.intValue

      UserDefaults.standard.set(
          steps,
          forKey: "flutter.today_steps"
      )
    }
  }

  // MARK: - BGTask Registration

  @available(iOS 13.0, *)
  private func registerBGTasks() {

    let noopHandler: (BGTask) -> Void = { task in
      task.setTaskCompleted(success: true)
    }

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevva.sleep_calc",
        using: nil,
        launchHandler: noopHandler
    )

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevva.api_sync",
        using: nil,
        launchHandler: noopHandler
    )

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevva.period_sync",
        using: nil,
        launchHandler: noopHandler
    )

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevvaa.reminderReconcile",
        using: nil,
        launchHandler: noopHandler
    )

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevvaa.reminderOneShot",
        using: nil,
        launchHandler: noopHandler
    )
  }

  // MARK: - Display Helpers

  private func currentDisplayRefreshRate() -> Double {
    return Double(UIScreen.main.maximumFramesPerSecond)
  }

  @discardableResult
  private func requestHighRefreshRateIfAvailable() -> Bool {

    guard UIScreen.main.maximumFramesPerSecond >= 120 else {
      return false
    }

    displayLink?.invalidate()

    let link = CADisplayLink(target: self, selector: #selector(displayLinkTick))

    if #available(iOS 15.0, *) {
      link.preferredFrameRateRange = CAFrameRateRange(
          minimum: 80,
          maximum: 120,
          preferred: 120
      )
    } else {
      link.preferredFramesPerSecond = 120
    }

    link.add(to: .main, forMode: .common)
    displayLink = link

    return true
  }

  @objc private func displayLinkTick() {
    // No-op — the display link just signals ProMotion preference to the system
  }
}