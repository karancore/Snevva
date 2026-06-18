import Flutter
import UIKit
import CoreMotion
import BackgroundTasks
import flutter_local_notifications
import QuartzCore
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let displayConfigChannelName = "com.coretegra.snevva/display_config"
  private let timezoneChannelName = "com.coretegra.snevvaa/timezone"
  private let stepServiceChannelName = "com.coretegra.snevvaa/step_service"
  private let pedometer = CMPedometer()

  override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let didFinish = super.application(
        application,
        didFinishLaunchingWithOptions: launchOptions
    )

    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    FirebaseApp.configure()

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

      // ✅ APNS registration
      application.registerForRemoteNotifications()

    if #available(iOS 13.0, *) {
      registerBGTasks()
    }

    _ = requestHighRefreshRateIfAvailable()
    startPedometerTracking()

    return didFinish
  }

    // MARK: - APNS Token → Firebase
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        print("✅ APNS Token registered successfully")
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNS registration failed: \(error.localizedDescription)")
    }

    // MARK: - FlutterImplicitEngineDelegate

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    configureDisplayConfigChannel(with: messenger)
    configureTimezoneChannel(with: messenger)
    configureStepServiceChannel(with: messenger)
  }

    // MARK: - UIScene lifecycle

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

  private func configureDisplayConfigChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
        name: displayConfigChannelName,
        binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
          result(FlutterError(code: "APP_DELEGATE_RELEASED", message: "AppDelegate is unavailable", details: nil))
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

  private func configureTimezoneChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
        name: timezoneChannelName,
        binaryMessenger: messenger
    )

    channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getTimeZoneId":
        result(TimeZone.current.identifier)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Step Service

  private func configureStepServiceChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
        name: stepServiceChannelName,
        binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startStepService":
        self?.startPedometerTracking()
        result(true)
      case "stopStepService":
        self?.pedometer.stopUpdates()
        result(true)
      case "seedTodaySteps":
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
        forTaskWithIdentifier: "com.coretegra.snevva.sleep_calc",
        using: nil, launchHandler: noopHandler)

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevva.api_sync",
        using: nil, launchHandler: noopHandler)

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevva.period_sync",
        using: nil, launchHandler: noopHandler)

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevvaa.reminderReconcile",
        using: nil, launchHandler: noopHandler)

    BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.coretegra.snevvaa.reminderOneShot",
        using: nil, launchHandler: noopHandler)
  }

  // MARK: - Display Helpers

  private func currentDisplayRefreshRate() -> Double {
    return Double(UIScreen.main.maximumFramesPerSecond)
  }

  @discardableResult
  private func requestHighRefreshRateIfAvailable() -> Bool {
    return UIScreen.main.maximumFramesPerSecond >= 120
  }
}