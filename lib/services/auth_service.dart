import 'dart:convert';
import 'dart:io';

import 'package:alarm/alarm.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/Reminder/event_controller.dart';
import 'package:snevva/Controllers/Reminder/meal_controller.dart';
import 'package:snevva/Controllers/Reminder/medicine_controller.dart';
import 'package:snevva/Controllers/Reminder/reminder_controller.dart';
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/WomenHealth/bottom_sheet_controller.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/hive_models/steps_model.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/reminder/native_alarm_bridge.dart';
import 'package:snevva/services/reminder/reminder_worker.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import 'package:snevva/views/permissions/permission_gate_screen.dart';
import 'package:workmanager/workmanager.dart';

import '../Controllers/signupAndSignIn/otp_verification_controller.dart';
import '../Controllers/signupAndSignIn/sign_in_controller.dart';
import '../Widgets/home_wrapper.dart';
import '../bindings/initial_bindings.dart';
import '../views/ProfileAndQuestionnaire/height_and_weight_screen.dart';
import '../views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../views/ProfileAndQuestionnaire/questionnaire_screen.dart';
import 'app_initializer.dart';
import 'auth_header_helper.dart';
import 'background_pedometer_service.dart';
import 'decisiontree_service.dart';
import 'device_token_service.dart';
import 'encryption_service.dart';
import 'file_storage_service.dart';
import 'permission_manager.dart';
import 'tracking_service_manager.dart';

class AuthService {
  static bool _isLoggingOut = false;

  StepCounterController get stepController => Get.find<StepCounterController>();
  SleepController get sleepController => Get.find<SleepController>();
  HydrationStatController get waterController =>
      Get.find<HydrationStatController>();

  VitalsController get vitalsController => Get.put(VitalsController());
  LocalStorageManager get localStorageManager =>
      Get.find<LocalStorageManager>();
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');
  MoodController get moodcontroller => Get.find<MoodController>();
  BottomSheetController get bottomsheetcontroller =>
      Get.find<BottomSheetController>();
  WomenHealthController get womenhealthController =>
      Get.find<WomenHealthController>();
  SignInController get signInController => Get.put(SignInController());

  Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  static Future<void> devicelogout(String deviceId) async {
    try {
      final payload = {'DeviceId': deviceId};
      final response = await ApiService.post(
        deleteDeviceApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        throw Exception('API Error: ${response.statusCode}');
      }

      debugPrint('✅ Successfully logged out from server');
      CustomSnackbar.showOtherDeviceLogoutSuccess(context: Get.context!);
    } catch (e) {
      debugPrint('❌ Error during logout API call: $e');
    }
  }

  void loginLog(String msg) {
    debugPrint("🟩 LOGIN_FLOW: $msg");
  }

  Future<bool> _ensurePostLoginPermissionsAndStartTracking({
    bool ignoreSessionGuard = false,
  }) async {
    final permissionManager = PermissionManager();
    final prefs = await SharedPreferences.getInstance();
    final shouldRun =
        ignoreSessionGuard
            ? true
            : await permissionManager.shouldRunPostLoginFlow(prefs);
    final requirements = await permissionManager.getRequiredPermissions();
    final alreadyGranted = await permissionManager.areAllRequiredGranted(
      requirements,
    );

    if (!shouldRun && !alreadyGranted) {
      return false;
    }

    bool granted = alreadyGranted;
    if (shouldRun && !alreadyGranted) {
      granted =
          await Get.to<bool>(
            () => PermissionGateScreen(
              permissionManager: permissionManager,
              requirements: requirements,
            ),
          ) ??
          false;
    }

    await permissionManager.markPostLoginFlowDone(prefs);

    if (granted) {
      await TrackingServiceManager.instance.start();
    }

    return granted;
  }

  Future<bool> ensurePostLoginPermissionsAndStartTracking({
    bool ignoreSessionGuard = false,
  }) async {
    debugPrint(
      "Ensuring post-login permissions and starting tracking if granted...",
    );
    return _ensurePostLoginPermissionsAndStartTracking(
      ignoreSessionGuard: ignoreSessionGuard,
    );
  }

  Future<void> handleSuccessfulSignIn({
    required String emailOrPhone,
    required SharedPreferences prefs,
    required BuildContext context,
    required bool rememberMe,
  }) async {
    loginLog("==== LOGIN STARTED ====");

    if (rememberMe) {
      loginLog("Saving remember me credentials");
      prefs.setBool('remember_me', true);
      prefs.setString('user_credential', emailOrPhone);
    }

    // ✅ Re-enable reminders upon successful login
    await prefs.remove('reminders_disabled');

    //PERMISSIONS
    loginLog("Requesting permissions...");
    final permissionsGranted =
        await _ensurePostLoginPermissionsAndStartTracking();
    loginLog(
      permissionsGranted ? "Permissions granted" : "Permissions not granted",
    );

    if (permissionsGranted) {
      loginLog("Background service started");
    } else {
      loginLog("Tracking services not started (missing permissions)");
    }

    /// HEALTH DATA LOAD
    loginLog("Loading Steps...");
    await stepController.loadStepsfromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Steps loaded");

    loginLog("Loading Sleep...");
    await sleepController.loadSleepfromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Sleep loaded");

    loginLog("Loading Water...");
    await waterController.loadWaterIntakefromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Water loaded");

    loginLog("Loading Vitals...");
    await vitalsController.loadvitalsfromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Vitals loaded");

    loginLog("Registering FCM...");
    localStorageManager.registerDeviceFCMIfNeeded();

    loginLog("Fetching reminders...");
    await reminderController.syncRemindersFromServer(context);
    loginLog("Reminders loaded");

    loginLog("Loading mood...");
    await moodcontroller.loadMoodFromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Mood loaded");

    /// USER INFO — already fetched during signInUsing*; reuse cached data.
    loginLog("Using cached user info...");
    final userInfo = signInController.userProfData;
    final userData = userInfo['data'];
    loginLog("User info received");
    debugPrint('User data: ${jsonEncode(userData)}');

    await prefs.setString('userdata', jsonEncode(userData));
    localStorageManager.userMap.value = userData ?? {};

    final PatientCode = userData['PatientCode']?.toString() ?? '';
    await prefs.setString('PatientCode', PatientCode);
    loginLog("PatientCode saved: $PatientCode");

    // Reset the cached fs/<uid>/ directory so this login session reads from the
    // correct user-scoped folder (handles hot-session-swap without a process kill).
    FileStorageService().reset();
    loginLog("FileStorageService cache reset for $PatientCode");

    final Map userMap = localStorageManager.userMap;
    final bool profileComplete = isProfileSetupInitialComplete(userMap);

    final gender = userMap['Gender']?.toString() ?? 'Unknown';
    loginLog("Gender: $gender");

    if (gender == 'Female') {
      loginLog("Female user → loading women health data");
      await bottomsheetcontroller.loaddatafromAPI();
      await womenhealthController.lastPeriodDatafromAPI();
    }

    /// PROFILE CHECK
    loginLog("Checking ProfileSetupInitial completeness...");
    if (profileComplete) {
      loginLog("Profile setup initial complete");

      final userActiveDataResponse = signInController.userGoalData;
      final userActiveData = userActiveDataResponse['data'];

      debugPrint('User active data: ${jsonEncode(userActiveData)}');
      localStorageManager.userGoalDataMap.value = userActiveData ?? {};
      prefs.setString('userGoalDataMap', jsonEncode(userActiveData));

      if (userActiveData != null && userActiveData is Map) {
        await prefs.setString('useractivedata', jsonEncode(userActiveData));

        /// HOME
        if (userActiveData['ActivityLevel'] != null &&
            userActiveData['HealthGoal'] != null) {
          loginLog("All goals set → Navigating to HOME");
          Get.offAll(() => HomeWrapper(), binding: InitialBindings());
          return;
        }

        /// QUESTIONNAIRE
        if (userActiveData['HeightData'] != null &&
            userActiveData['WeightData'] != null) {
          loginLog("Height/Weight done but goals missing → Questionnaire");
          Get.offAll(() => QuestionnaireScreen());
          return;
        }

        /// HEIGHT WEIGHT
        loginLog("Missing height/weight → HeightWeightScreen");
        Get.offAll(() => HeightWeightScreen(gender: gender));
        return;
      }

      loginLog("Goal data invalid → HOME fallback");
      Get.offAll(() => HomeWrapper(), binding: InitialBindings());
      return;
    }

    /// PROFILE SETUP
    loginLog("Profile setup initial missing → ProfileSetupInitial");
    Get.offAll(() => ProfileSetupInitial());
  }

  Future<String?> loginWithEmail(String email, String password) async {
    final plainEmail = jsonEncode({'Gmail': email, 'Password': password});

    final uri = Uri.parse("$baseUrl$signInEmailEndpoint");

    final encryptedEmail = EncryptionService.encryptData(plainEmail);

    final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
    headers['x-data-hash'] = encryptedEmail['Hash']!;
    headers['X-Device-Info'] =
        await DeviceTokenService().buildDeviceInfoHeader();

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'data': encryptedEmail['encryptedData']}),
    );

    if (response.statusCode != 200) return null;

    final responseBody = jsonDecode(response.body);
    final decrypted = EncryptionService.decryptData(
      responseBody['data'],
      response.headers['x-data-hash']!,
    );

    final token = jsonDecode(decrypted!)['data'];
    return token;
  }

  static Future<void> logExceptionToServer(dynamic exceptionDetails) async {
    try {
      debugPrint("🚨 Logging exception to server: $exceptionDetails");

      final response = await ApiService.post(
        logexception,
        exceptionDetails,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        throw Exception('API Error: ${response.statusCode}');
      }

      debugPrint('Successfully logged exception to server');
    } catch (e) {
      debugPrint('Error during log exception API call: $e');
    }
  }

  static Future<void> clearReminderRuntimeOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_disabled', true);

    await NativeAlarmBridge.cancelAllPersisted();

    await Alarm.stopAll();

    final fln = FlutterLocalNotificationsPlugin();
    await fln.cancelAll();
    await fln.cancelAllPendingNotifications();

    try {
      await Workmanager().cancelByUniqueName(kReminderReconcileTask);
      await Workmanager().cancelByUniqueName(kReminderOneShotTask);
    } catch (_) {}

    Get.delete<ReminderController>(tag: 'reminder', force: true);
    Get.delete<WaterController>(force: true);
    Get.delete<MedicineController>(force: true);
    Get.delete<MealController>(force: true);
    Get.delete<EventController>(force: true);
  }

  static Future<void> clearProfileImageStateOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString('profileImagePath');

    if (Get.isRegistered<ProfileSetupController>()) {
      try {
        await Get.find<ProfileSetupController>().clearImage();
      } catch (e) {
        debugPrint('⚠️ Failed to clear ProfileSetupController image: $e');
      }
    } else {
      await prefs.remove('profileImagePath');
    }

    if (savedPath != null && savedPath.isNotEmpty) {
      try {
        await FileImage(File(savedPath)).evict();
      } catch (e) {
        debugPrint('⚠️ Failed to evict saved profile image: $e');
      }
    }

    if (Get.isRegistered<LocalStorageManager>()) {
      final localStorageManager = Get.find<LocalStorageManager>();
      final cdnUrl =
          localStorageManager.userMap['ProfilePicture']?['CdnUrl']?.toString();
      if (cdnUrl != null && cdnUrl.isNotEmpty) {
        final imageUrl = cdnUrl.startsWith('http') ? cdnUrl : 'https://$cdnUrl';
        try {
          await CachedNetworkImage.evictFromCache(imageUrl);
          await CachedNetworkImageProvider(imageUrl).evict();
        } catch (e) {
          debugPrint('⚠️ Failed to evict profile network image: $e');
        }
      }
      localStorageManager.userMap.remove('ProfilePicture');
      localStorageManager.userMap.refresh();
    }

    imageCache.clear();
    imageCache.clearLiveImages();
  }

  static Future<void> forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      // ── Final step sync before logout ────────────────────────────────────────
      // Auth token is still valid here. Once prefs.clear() runs it's gone, so
      // this is the ONLY window where we can push today's unflushed steps to
      // the API. We do it synchronously (awaited) so the data reaches the server
      // before the token is wiped. Non-fatal — a failure must never block logout.
      try {
        if (Get.isRegistered<StepCounterController>()) {
          final ctrl = Get.find<StepCounterController>();
          if (ctrl.todaySteps.value > 0) {
            debugPrint(
              '📤 Logout: syncing today\'s steps (${ctrl.todaySteps.value}) before token clear...',
            );
            await ctrl.saveStepRecordToServer();
            debugPrint('✅ Logout step sync done');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Logout step sync failed (non-fatal): $e');
      }
      // ── End final step sync ──────────────────────────────────────────────────

      try {
        debugPrint('🛑 Stopping background services...');

        await stopUnifiedBackgroundService();

        // Back-compat safety: if anything else is wired to old stopper.
        await stopBackgroundService();

        // Stop the native foreground service so the sticky notification
        // disappears on all logout paths (manual or token-expired).
        await TrackingServiceManager.instance.stopNativeStepService();

        debugPrint('✅ Background services stopped');
      } catch (e) {
        debugPrint('⚠️ Failed to stop background service: $e');
        // DO NOT block logout
      }

      final prefs = await SharedPreferences.getInstance();

      // Invalidate the user-scoped fs/<uid>/ cache BEFORE clearing prefs so that
      // any in-flight Dart read that starts after this point gets a fresh lookup.
      FileStorageService().reset();
      debugPrint('🗑️ FileStorageService cache invalidated');

      // Clear alarms while prefs still contain native_reminder_alarms
      await clearReminderRuntimeOnLogout();
      await clearProfileImageStateOnLogout();

      await prefs.clear();

      // ✅ FIX: Restore the reminders_disabled tombstone flag because prefs.clear() wiped it!
      // This is critical so native BootReceiver/armFromSharedPrefs doesn't resurrect alarms
      await prefs.setBool('reminders_disabled', true);

      try {
        final stepBox = await Hive.openBox<StepEntry>('step_history');
        await stepBox.clear();
        debugPrint('🗑️ step_history Hive box cleared');
      } catch (e) {
        debugPrint('❌ Failed to clear step_history on logout: $e');
      }

      final localStorageManager = Get.find<LocalStorageManager>();
      localStorageManager.userMap.value = {};
      localStorageManager.userMap.refresh();

      localStorageManager.userGoalDataMap.value = {};
      localStorageManager.userGoalDataMap.refresh();

      debugPrint('🧠 Clearing DecisionTreeService...');
      await DecisionTreeService().clearAll();

      // ❌ REMOVE THIS
      // Get.deleteAll(force: true);

      // ✅ Delete only app controllers
      Get.delete<DietPlanController>();
      Get.delete<HealthTipsController>();
      Get.delete<HydrationStatController>();
      Get.delete<MentalWellnessController>();
      Get.delete<MoodController>();
      Get.delete<MoodQuestionController>();
      Get.delete<ProfileSetupController>(force: true);
      Get.delete<EditprofileController>(force: true);
      Get.delete<SignInController>(force: true);
      Get.delete<OTPVerificationController>(force: true);
      Get.delete<SleepController>();
      Get.delete<StepCounterController>();
      Get.delete<VitalsController>();

      Get.offAll(() => SignInScreen());
    } finally {
      _isLoggingOut = false;
    }
  }
}
