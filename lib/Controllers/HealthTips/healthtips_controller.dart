import 'dart:convert';
import 'dart:math';

import 'package:snevva/consts/consts.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class HealthTipsController extends GetxService {
  /// ✅ Reactive variables
  dynamic generalTips;
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;
  dynamic randomTip; // can be null

  var isLoading = true.obs;
  var hasError = false.obs;

  // @override
  // void onInit() {
  //   super.onInit();
  //   loadAllHealthTips();
  // }

  Future<void> loadAllHealthTips(BuildContext context) async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await GetGeneralhealthtips(context);
      await GetCustomHealthTips();
    } catch (e) {
      hasError.value = true;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load health tips',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> GetGeneralhealthtips(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["Health Tips", "General"],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
      };

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load general tips: ${response.statusCode}',
        );
        generalTips = [];
        randomTip = null;
        return;
      }

      final parsedData = jsonDecode(jsonEncode(response));
      generalTips = parsedData['data'] ?? [];

      // ✅ Check if list has elements before picking random
      if (generalTips != null && generalTips.isNotEmpty) {
        final random = Random();
        randomTip = generalTips[random.nextInt(generalTips.length)];
      } else {
        randomTip = null;
      }
    } catch (e) {
      generalTips = [];
      randomTip = null;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load general tips',
      );
    }
  }

  Future<void> GetCustomHealthTips() async {
    try {
      List<String> tags = ['Health Tips'];
      print("call2");

      final localStorageManager = Get.find<LocalStorageManager>();
      final day = localStorageManager.userMap['DayOfBirth'];
      final month = localStorageManager.userMap['MonthOfBirth'];
      final year = localStorageManager.userMap['YearOfBirth'];

      // final bmitext = prefs.getString('bmi_text');
      // final activitylevel = prefs.getString('ActivityLevel');
      // final healthgoal = prefs.getString('HealthGoal');
      final storedGender = localStorageManager.userMap['Gender'];

      // if (bmitext != null && bmitext.isNotEmpty) tags.add(bmitext);
      // if (activitylevel != null && activitylevel.isNotEmpty) tags.add(activitylevel);
      // if (healthgoal != null && healthgoal.isNotEmpty) tags.add(healthgoal);
      if (storedGender != null && storedGender.toString().isNotEmpty) {
        tags.add(storedGender);
      }

      if (day != null && month != null && year != null) {
        DateTime today = DateTime.now();
        DateTime birthDate = DateTime(year, month, day);
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        if (age >= 13 && age <= 18) {
          tags.add("Age 13 to 18");
        } else if (age >= 19 && age <= 25) {
          tags.add("Age 19 to 25");
        } else if (age > 25 && age <= 60) {
          tags.add("Age 25 to 60");
        }
      }
      // print(localStorageManager.userGoalDataMap['HeightData']['Value']);
      // print(tags);
      final payload = {'Tags': tags, 'FetchAll': true, 'Count': 0, 'Index': 0};

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final parsedData = jsonDecode(jsonEncode(response));
      customTips.value = parsedData['data'] ?? [];

      final List<dynamic> allTips = List.from(customTips);
      allTips.shuffle();
      randomTips.assignAll(allTips.take(4).toList()); // ✅ use assignAll
    } catch (e) {
      customTips.value = [];
      randomTips.clear(); // ✅ safely clear reactive list
      throw Exception('Error fetching custom health tips: $e');
    }
  }
}
