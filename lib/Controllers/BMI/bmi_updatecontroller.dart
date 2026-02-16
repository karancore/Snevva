import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:http/http.dart' as http;
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class BmiUpdateController extends GetxService {
  RxInt age = 0.obs;
  RxString bmi_text = "Great-Shape".obs;
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;

  RxDouble height = 0.0.obs; // in cm
  RxDouble weight = 0.0.obs; // in kg
  RxDouble bmi = 0.0.obs;

  var isLoading = true.obs;
  var hasError = false.obs;

  late LocalStorageManager localStorageManager;
  late EditprofileController editprofileController;

  @override
  void onInit() {
    super.onInit();
    localStorageManager = Get.find<LocalStorageManager>();
    editprofileController = Get.find<EditprofileController>();
  }
  Future<bool> setHeightAndWeight(
    BuildContext context,
    dynamic age,
    dynamic height,
    dynamic weight,
  ) async {
    final flag1 = await editprofileController.saveHeight(
      context,
      height,
      day: DateTime.now().day,
      month: DateTime.now().month,
      year: DateTime.now().year,
      time: TimeOfDay.now().format(context),
    );
    final flag2 = await editprofileController.saveWeight(
      context,
      weight,
      day: DateTime.now().day,
      month: DateTime.now().month,
      year: DateTime.now().year,
      time: TimeOfDay.now().format(context),
    );

    if (!flag1 || !flag2) {
      // CustomSnackbar.showError(
      //   context: context,
      //   title: 'Error',
      //   message: 'Failed to save height or weight',
      // );
      return false;
    }

    this.age.value = age;
    this.height.value = height;
    this.weight.value = weight;

    print('Set Age: ${age}, Height: ${height} cm, Weight: ${weight} kg');
    updatebmivalues();
    return true;
  }

  Future<void> updatebmivalues() async {
    print(
      "ht and wt before ${localStorageManager.userGoalDataMap['HeightData']['Value']} and ${localStorageManager.userGoalDataMap['WeightData']['Value']}",
    );
    localStorageManager.userGoalDataMap['HeightData']['Value'] = height.value;
    localStorageManager.userGoalDataMap['WeightData']['Value'] = weight.value;

    print('Updated Height: ${height.value}, Weight: ${weight.value}');
    print(
      "ht and wt updated in local storage manager ${localStorageManager.userGoalDataMap['HeightData']['Value']} and ${localStorageManager.userGoalDataMap['WeightData']['Value']}",
    );
    // await localStorageManager.reloadUserMap();
  }

  Future<void> loadUserBMI() async {
    // // final prefs = await SharedPreferences.getInstance();
    // final savedHeight = prefs.getDouble('height') ?? 0.0; // cm
    // final savedWeight = prefs.getDouble('weight') ?? 0.0; // kg

    final savedHeight =
        localStorageManager.userGoalDataMap['HeightData'] != null
            ? double.tryParse(
                  localStorageManager.userGoalDataMap['HeightData']['Value']
                      .toString(),
                ) ??
                0.0
            : 0.0;
    final savedWeight =
        localStorageManager.userGoalDataMap['WeightData'] != null
            ? double.tryParse(
                  localStorageManager.userGoalDataMap['WeightData']['Value']
                      .toString(),
                ) ??
                0.0
            : 0.0;

    height.value = savedHeight;
    weight.value = savedWeight;

    print('  ${height.value} cm, Weight: ${weight.value} kg');

    if (height.value > 0 && weight.value > 0) {
      final heightInMeters = height.value / 100;
      bmi.value = double.parse(
        (weight.value / (heightInMeters * heightInMeters)).toStringAsFixed(2),
      );

      if (bmi.value < 18.5) {
        bmi_text.value = "Underweight";
      } else if (bmi.value >= 18.5 && bmi.value < 24.9) {
        bmi_text.value = "Great-Shape";
      } else if (bmi.value >= 25 && bmi.value < 29.9) {
        bmi_text.value = "Overweight";
      } else {
        bmi_text.value = "Obese";
      }
    }

    print('Calculated BMI: ${bmi.value}');
  }

  Future<void> loadAllHealthTips(BuildContext context) async {
    isLoading.value = true;
    hasError.value = false;
    try {
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

  Future<void> GetCustomHealthTips() async {
    try {
      List<String> tags = ['BMI', bmi_text.value];
      if (age.value >= 13 && age.value <= 18) {
        tags.add("Age 13 to 18");
      } else if (age.value >= 19 && age.value <= 25) {
        tags.add("Age 19 to 25");
      } else if (age.value > 25 && age.value <= 60) {
        tags.add("Age 25 to 60");
      }
      // print(localStorageManager.userGoalDataMap['HeightData']['Value']);
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
      randomTips.assignAll(allTips.take(2).toList()); // ✅ use assignAll
      isLoading.value = false;
    } catch (e) {
      customTips.value = [];
      randomTips.clear(); // ✅ safely clear reactive list
      throw Exception('Error fetching custom health tips: $e');
    }
  }
}
