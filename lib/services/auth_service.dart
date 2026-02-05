import 'dart:convert';
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
import 'package:snevva/Controllers/Reminder/water_controller.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/Vitals/vitalsController.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/hive_models/steps_model.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';

import 'auth_header_helper.dart';
import 'device_token_service.dart';
import 'encryption_service.dart';

class AuthService {

  static bool _isLoggingOut = false;

  
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
    try{      
      
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
      CustomSnackbar.showOtherDeviceLogoutSuccess(
        context: Get.context!,
      );


    }catch(e){
      print('❌ Error during logout API call: $e');
    }
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

  static Future<void> logExceptionToServer(Map<String , dynamic> exceptionDetails) async {
    try{
      final payload = {'ExceptionDetails': exceptionDetails};

      debugPrint("🚨 Logging exception to server: $exceptionDetails");

      final response = await ApiService.post(
        logexception,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        throw Exception('API Error: ${response.statusCode}');
      }

      print('Successfully logged exception to server');
  }catch(e){
      print('Error during log exception API call: $e');
    }
  }
  static Future<void> forceLogout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    try {
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

    // ❌ REMOVE THIS
    // Get.deleteAll(force: true);

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

    Get.delete<SleepController>();
    Get.delete<StepCounterController>();
    Get.delete<VitalsController>();

    Get.offAll(() => SignInScreen());
    } finally {
      _isLoggingOut = false;
    }
  }

}
