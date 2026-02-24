import 'dart:convert';
import 'dart:developer' as AgentDebugLogger;
import 'package:alarm/alarm.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/DietPlan/diet_plan_controller.dart';
import 'package:snevva/Controllers/HealthTips/healthtips_controller.dart';
import 'package:snevva/Controllers/Hydration/hydration_stat_controller.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
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
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/hive_models/steps_model.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';

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

class AuthService {
  static bool _isLoggingOut = false;

  StepCounterController get stepController => Get.find<StepCounterController>();
  SleepController get sleepController => Get.find<SleepController>();
  HydrationStatController get waterController =>
      Get.find<HydrationStatController>();
  VitalsController get vitalsController => Get.find<VitalsController>();
  LocalStorageManager get localStorageManager =>
      Get.find<LocalStorageManager>();
  ReminderController get reminderController =>
      Get.find<ReminderController>(tag: 'reminder');
  MoodController get moodcontroller => Get.find<MoodController>();
  BottomSheetController get bottomsheetcontroller =>
      Get.find<BottomSheetController>();
  WomenHealthController get womenhealthController =>
      Get.find<WomenHealthController>();
  SignInController get signInController => Get.find<SignInController>();

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

      print('✅ Successfully logged out from server');
      CustomSnackbar.showOtherDeviceLogoutSuccess(context: Get.context!);
    } catch (e) {
      print('❌ Error during logout API call: $e');
    }
  }

  // Future<void> handleSuccessfulSignIn({
  //   required String emailOrPhone,
  //   required SharedPreferences prefs,
  //   required BuildContext context,
  //   required bool rememberMe,
  // }) async {
  //   if (rememberMe) {
  //     prefs.setBool('remember_me', true);
  //     prefs.setString('user_credential', emailOrPhone);
  //   }
  //
  //   // #endregion
  //
  //   await requestAllPermissions();
  //   await initBackgroundService();
  //
  //   // #endregion
  //
  //   await stepController.loadStepsfromAPI(
  //     month: DateTime.now().month,
  //     year: DateTime.now().year,
  //   );
  //
  //   await sleepController.loadSleepfromAPI(
  //     month: DateTime.now().month,
  //     year: DateTime.now().year,
  //   );
  //
  //   await waterController.loadWaterIntakefromAPI(
  //     month: DateTime.now().month,
  //     year: DateTime.now().year,
  //   );
  //
  //   await vitalsController.loadvitalsfromAPI(
  //     month: DateTime.now().month,
  //     year: DateTime.now().year,
  //   );
  //
  //   localStorageManager.registerDeviceFCMIfNeeded();
  //   await reminderController.getReminderFromAPI(context);
  //
  //   // await bottomsheetcontroller.loaddatafromAPI();
  //   // await womenhealthController.lastPeriodDatafromAPI();
  //
  //   await moodcontroller.loadmoodfromAPI(
  //     month: DateTime.now().month,
  //     year: DateTime.now().year,
  //   );
  //
  //   final userInfo = await signInController.userInfo();
  //   final userData = userInfo['data'];
  //   print(userData);
  //   await prefs.setString('userdata', jsonEncode(userData));
  //   localStorageManager.userMap.value = userData ?? {};
  //
  //   final PatientCode = userData['PatientCode']?.toString() ?? '';
  //   await prefs.setString('PatientCode', PatientCode);
  //
  //   final nameValid = userData['Name']?.toString().trim().isNotEmpty ?? false;
  //   final genderValid =
  //       userData['Gender']?.toString().trim().isNotEmpty ?? false;
  //   final occupationValid = userData['OccupationData'] != null;
  //
  //   final gender = userData['Gender']?.toString() ?? 'Unknown';
  //   print("Gender is $gender");
  //   if (gender == 'Female') {
  //     await bottomsheetcontroller.loaddatafromAPI();
  //     await womenhealthController.lastPeriodDatafromAPI();
  //   }
  //
  //   if (nameValid && genderValid && occupationValid) {
  //     final userActiveDataResponse = signInController.userGoalData;
  //     final userActiveData = userActiveDataResponse['data'];
  //     print(userActiveData);
  //
  //     localStorageManager.userGoalDataMap.value = userActiveData ?? {};
  //     prefs.setString('userGoalDataMap', jsonEncode(userActiveData));
  //
  //     if (userActiveData != null && userActiveData is Map) {
  //       await prefs.setString('useractivedata', jsonEncode(userActiveData));
  //
  //       // 🚀 Final check 1 → All goals set → go home
  //       if (userActiveData['ActivityLevel'] != null &&
  //           userActiveData['HealthGoal'] != null) {
  //         Get.offAll(() => HomeWrapper(), binding: InitialBindings());
  //         return; // <<< CRITICAL
  //       }
  //
  //       // 🚀 Final check 2 → Ask only remaining questions
  //       if (userActiveData['HeightData'] != null &&
  //           userActiveData['WeightData'] != null) {
  //         Get.offAll(() => QuestionnaireScreen());
  //         return; // <<< CRITICAL
  //       }
  //
  //       // 🚀 Missing height/weight
  //       final gender = userData['Gender']?.toString() ?? 'Unknown';
  //       Get.offAll(() => HeightWeightScreen(gender: gender));
  //       return; // <<< CRITICAL
  //     }
  //
  //     // If userActiveData invalid
  //     Get.offAll(() => HomeWrapper(), binding: InitialBindings());
  //     return;
  //   }
  //
  //   // Missing basic profile info
  //   Get.offAll(() => ProfileSetupInitial());
  //   return;
  // }

  void loginLog(String msg) {
    debugPrint("🟩 LOGIN_FLOW: $msg");
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

    /// PERMISSIONS
    loginLog("Requesting permissions...");
    await requestAllPermissions();
    loginLog("Permissions granted");

    /// BACKGROUND SERVICE
    loginLog("Initializing background service...");
    await initBackgroundService();
    loginLog("Background service started");

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
    await reminderController.getReminderFromAPI(context);
    loginLog("Reminders loaded");

    loginLog("Loading mood...");
    await moodcontroller.loadmoodfromAPI(
      month: DateTime.now().month,
      year: DateTime.now().year,
    );
    loginLog("Mood loaded");

    /// USER INFO
    loginLog("Fetching user info...");
    final userInfo = await signInController.userInfo();
    final userData = userInfo['data'];
    loginLog("User info received");
    print(userData);

    await prefs.setString('userdata', jsonEncode(userData));
    localStorageManager.userMap.value = userData ?? {};

    final PatientCode = userData['PatientCode']?.toString() ?? '';
    await prefs.setString('PatientCode', PatientCode);
    loginLog("PatientCode saved: $PatientCode");

    final nameValid = userData['Name']?.toString().trim().isNotEmpty ?? false;
    final genderValid =
        userData['Gender']?.toString().trim().isNotEmpty ?? false;
    final occupationValid = userData['OccupationData'] != null;

    final gender = userData['Gender']?.toString() ?? 'Unknown';
    loginLog("Gender: $gender");

    if (gender == 'Female') {
      loginLog("Female user → loading women health data");
      await bottomsheetcontroller.loaddatafromAPI();
      await womenhealthController.lastPeriodDatafromAPI();
    }

    /// PROFILE CHECK
    loginLog("Checking basic profile completeness...");
    if (nameValid && genderValid && occupationValid) {
      loginLog("Basic profile complete");

      final userActiveDataResponse = signInController.userGoalData;
      final userActiveData = userActiveDataResponse['data'];

      print(userActiveData);
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
    loginLog("Basic profile missing → ProfileSetupInitial");
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

      print('Successfully logged exception to server');
    } catch (e) {
      print('Error during log exception API call: $e');
    }
  }

  static Future<void> forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
      try {
        debugPrint('🛑 Stopping background services...');

        await stopUnifiedBackgroundService();

        // Back-compat safety: if anything else is wired to old stopper.
        await stopBackgroundService();

        debugPrint('✅ Background services stopped');
      } catch (e) {
        debugPrint('⚠️ Failed to stop background service: $e');
        // DO NOT block logout
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      try {
        await Hive.box<StepEntry>('step_history').clear();
      } catch (e) {
        print('❌ Failed to clear step_history on logout: $e');
        try {
          await Hive.box<StepEntry>('step_history').clear();
        } catch (e2) {
          print('❌ Second attempt to clear step_history failed: $e2');
        }
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
      await Alarm.stopAll();
      // ✅ Delete only app controllers
      Get.delete<DietPlanController>();
      Get.delete<HealthTipsController>();
      Get.delete<HydrationStatController>();
      Get.delete<MentalWellnessController>();
      Get.delete<MoodController>();
      Get.delete<MoodQuestionController>();
      Get.delete<WaterController>();
      Get.delete<MedicineController>();
      Get.delete<EventController>();
      Get.delete<MealController>();
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
