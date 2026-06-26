import Flutter
import UIKit
import BackgroundTasks
import flutter_local_notifications
import QuartzCore
import FirebaseCore
import FirebaseMessaging
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

    private let displayConfigChannelName = "com.coretegra.snevva/display_config"
    private let timezoneChannelName = "com.coretegra.snevvaa/timezone"
    private let stepServiceChannelName = "com.coretegra.snevvaa/step_service"
    private let sleepServiceChannelName = "com.coretegra.snevvaa/sleep_service"
    // Channel used to ask Flutter to call Alarm.stop() when the iOS "Clear"
    // button dismisses an alarm notification without the custom "Stop" action.
    private let alarmControlChannelName = "com.coretegra.snevvaa/alarm_control"

    private var alarmControlChannel: FlutterMethodChannel?

    // MARK: - App lifecycle

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let didFinish = super.application(application, didFinishLaunchingWithOptions: launchOptions)

        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
            GeneratedPluginRegistrant.register(with: registry)
        }

        FirebaseApp.configure()

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        application.registerForRemoteNotifications()

        if #available(iOS 13.0, *) {
            registerBGTasks()
        }

        _ = requestHighRefreshRateIfAvailable()

        // Start step tracking — MethodChannel is wired in didInitializeImplicitFlutterEngine.
        IOSStepService.shared.start()

        // Register for lock/unlock notifications (iOS equivalent of Android SCREEN_OFF/ON).
        // initializeForSleepWindow seeds the anchor so a BGTask flush at wake time works even
        // if the app was killed before any lock notification was received.
        IOSLockUnlockSleepDetector.shared.start()
        IOSLockUnlockSleepDetector.shared.initializeForSleepWindow()

        return didFinish
    }

    // MARK: - APNS

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        print("✅ APNS Token registered")
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
        // Wire the live step push channel to IOSStepService BEFORE configuring channels
        // so the first push that arrives after launch reaches Flutter correctly.
        IOSStepService.shared.configure(messenger: messenger)
        IOSSleepService.shared.configure(messenger: messenger)

        configureDisplayConfigChannel(with: messenger)
        configureTimezoneChannel(with: messenger)
        configureStepServiceChannel(with: messenger)

        // Wire the alarm control channel so the "Clear" dismiss handler can
        // ask Flutter to call Alarm.stop(alarmId) for clean alarm teardown.
        alarmControlChannel = FlutterMethodChannel(
            name: alarmControlChannelName,
            binaryMessenger: messenger
        )

        // The alarm package registers notification categories without
        // .customDismissAction, so iOS never fires didReceive for "Clear".
        // Wait briefly for the alarm plugin's async init to finish, then
        // re-register those categories with .customDismissAction added.
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms
            await self.addDismissActionToAlarmCategories()
        }
    }

    // MARK: - Alarm notification dismiss ("Clear" button)

    // iOS only calls userNotificationCenter(_:didReceive:) for the "Clear"
    // (dismiss) button when the notification category has .customDismissAction.
    // The alarm package omits this option, so we patch it in after init.
    private func addDismissActionToAlarmCategories() async {
        let center = UNUserNotificationCenter.current()
        var categories = await center.notificationCategories()
        var changed = false

        let alarmCategories = categories.filter {
            $0.identifier == "ALARM_CATEGORY_NO_ACTION" ||
            $0.identifier.hasPrefix("ALARM_CATEGORY_WITH_ACTION_")
        }

        for category in alarmCategories {
            guard !category.options.contains(.customDismissAction) else { continue }
            categories.remove(category)
            categories.insert(UNNotificationCategory(
                identifier: category.identifier,
                actions: category.actions,
                intentIdentifiers: category.intentIdentifiers,
                options: category.options.union(.customDismissAction)
            ))
            changed = true
        }

        if changed {
            center.setNotificationCategories(categories)
            print("[Snevva] ✅ Alarm categories updated with .customDismissAction")
        }
    }

    // Intercept "Clear" (UNNotificationDismissActionIdentifier) for alarm
    // notifications and route a stop request through Flutter so the alarm
    // package can clean up its audio player, timers, and volume state.
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDismissActionIdentifier,
           let alarmId = response.notification.request.content.userInfo["ALARM_ID"] as? Int {
            // Immediately stop audio in case the Flutter call is delayed.
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            // Ask Flutter to call Alarm.stop(alarmId) for full teardown.
            alarmControlChannel?.invokeMethod("stopAlarm", arguments: alarmId)
        }

        // Forward to FlutterAppDelegate so other plugins (alarm "Stop" action,
        // FCM, flutter_local_notifications) receive the response normally.
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
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
        IOSStepService.shared.start()
        // Re-seed lock anchor in case the app was relaunched mid-sleep-window.
        IOSLockUnlockSleepDetector.shared.initializeForSleepWindow()
        // Pull HealthKit sleep data for last night so SleepController sees it on next read.
        IOSSleepService.shared.fetchAndStoreLastNightSleep(completion: nil)
    }

    override func applicationDidEnterBackground(_ application: UIApplication) {
        super.applicationDidEnterBackground(application)
        // Flush both step and sleep buffers before potential suspension
        IOSStepBufferManager.shared.flushStepsToDaily()
        IOSStepBufferManager.shared.flushSleepToDaily()
        // Schedule BGTasks while we still have time in the background transition window
        if #available(iOS 13.0, *) {
            scheduleStepRefreshTask()
            scheduleApiSyncTask()
            IOSSleepService.shared.scheduleSleepCalcTask()
        }
    }

    // MARK: - Display Config

    private func configureDisplayConfigChannel(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: displayConfigChannelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterError(code: "APP_DELEGATE_RELEASED", message: nil, details: nil))
                return
            }
            switch call.method {
            case "getDisplayRefreshRate",
                 "getHighestSupportedRefreshRate":
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
        let channel = FlutterMethodChannel(name: timezoneChannelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { (call, result) in
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
        let channel = FlutterMethodChannel(name: stepServiceChannelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "startStepService":
                IOSStepService.shared.start()
                result(true)
            case "stopStepService":
                IOSStepService.shared.stop()
                result(true)
            case "seedTodaySteps":
                // Dart passes the API step count as an Int argument
                if let steps = call.arguments as? Int {
                    IOSStepService.shared.seedTodaySteps(steps)
                }
                result(true)
            case "refreshNotification":
                // No persistent notification on iOS; no-op
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - BGTask Registration

    @available(iOS 13.0, *)
    private func registerBGTasks() {
        // Background app refresh — short periodic step count update (~30 s budget)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.coretegra.snevva.step_refresh",
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleStepRefreshTask(refreshTask)
        }

        // Background processing — full API sync (~minutes budget when plugged in / idle)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.coretegra.snevva.api_sync",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleApiSyncTask(processingTask)
        }

        // Sleep finalization + sync (~minutes budget, runs near wake time)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.coretegra.snevva.sleep_calc",
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleSleepCalcTask(processingTask)
        }

        // Remaining identifiers — no active handler yet
        let noopIds = [
            "com.coretegra.snevva.period_sync",
            "com.coretegra.snevvaa.reminderReconcile",
            "com.coretegra.snevvaa.reminderOneShot",
        ]
        for id in noopIds {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
                task.setTaskCompleted(success: true)
            }
        }
    }

    // MARK: - BGTask Handlers

    @available(iOS 13.0, *)
    private func handleStepRefreshTask(_ task: BGAppRefreshTask) {
        scheduleStepRefreshTask()   // re-arm immediately

        task.expirationHandler = {
            IOSStepBufferManager.shared.flushStepsToDaily()
            task.setTaskCompleted(success: false)
        }

        IOSStepService.shared.performBackgroundRefresh {
            task.setTaskCompleted(success: true)
        }
    }

    @available(iOS 13.0, *)
    private func handleSleepCalcTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        IOSSleepService.shared.performSleepCalcBackgroundTask {
            task.setTaskCompleted(success: true)
        }
    }

    @available(iOS 13.0, *)
    private func handleApiSyncTask(_ task: BGProcessingTask) {
        scheduleApiSyncTask()       // re-arm immediately

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        IOSStepService.shared.performBackgroundSync { success in
            task.setTaskCompleted(success: success)
        }
    }

    // MARK: - BGTask Scheduling

    @available(iOS 13.0, *)
    private func scheduleStepRefreshTask() {
        let request = BGAppRefreshTaskRequest(
            identifier: "com.coretegra.snevva.step_refresh"
        )
        // Earliest begin date: 15 minutes from now.
        // iOS may defer further based on usage patterns.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ Failed to schedule step_refresh BGTask: \(error)")
        }
    }

    @available(iOS 13.0, *)
    private func scheduleApiSyncTask() {
        let request = BGProcessingTaskRequest(
            identifier: "com.coretegra.snevva.api_sync"
        )
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("⚠️ Failed to schedule api_sync BGTask: \(error)")
        }
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