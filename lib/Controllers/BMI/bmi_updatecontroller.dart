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
  static const int _pageSize = 8;

  RxInt age = 0.obs;
  RxString bmi_text = "Great-Shape".obs;
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;

  RxDouble height = 0.0.obs; // in cm
  RxDouble weight = 0.0.obs; // in kg
  RxDouble bmi = 0.0.obs;

  var isLoading = true.obs;
  var hasError = false.obs;
  var isLoadingMore = false.obs;
  var hasMoreData = true.obs;
  int pageIndex = 1;

  late LocalStorageManager localStorageManager;
  late EditprofileController editprofileController;
  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    localStorageManager = Get.find<LocalStorageManager>();
    editprofileController = Get.find<EditprofileController>();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      GetCustomHealthTips(loadMore: true);
    }
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

    debugPrint('Set Age: $age, Height: $height cm, Weight: ${weight} kg');
    updateBmiValues();
    return true;
  }

  void updateBmiValues() {
    debugPrint(
      "ht and wt before ${localStorageManager.userGoalDataMap['HeightData']['Value']} and ${localStorageManager.userGoalDataMap['WeightData']['Value']}",
    );
    localStorageManager.userGoalDataMap['HeightData']['Value'] = height.value;
    localStorageManager.userGoalDataMap['WeightData']['Value'] = weight.value;

    debugPrint('Updated Height: ${height.value}, Weight: ${weight.value}');
    debugPrint(
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

    debugPrint('  ${height.value} cm, Weight: ${weight.value} kg');

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

    debugPrint('Calculated BMI: ${bmi.value}');
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

  Future<void> GetCustomHealthTips({bool loadMore = false}) async {
    if (loadMore && (isLoadingMore.value || !hasMoreData.value)) return;

    final targetPage = loadMore ? pageIndex + 1 : 1;
    if (loadMore) {
      isLoadingMore.value = true;
    } else {
      hasMoreData.value = true;
      pageIndex = 1;
      customTips.clear();
      randomTips.clear();
    }

    try {
      List<String> tags = ['BMI', bmi_text.value];
      if (age.value >= 13 && age.value <= 18) {
        tags.add("Age 13 to 18");
      } else if (age.value >= 19 && age.value <= 25) {
        tags.add("Age 19 to 25");
      } else if (age.value > 25 && age.value <= 60) {
        tags.add("Age 25 to 60");
      }
      // debugPrint(localStorageManager.userGoalDataMap['HeightData']['Value']);
      final payload = {
        'Tags': tags,
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
      };

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
      final fetchedTips = List<dynamic>.from(parsedData['data'] ?? []);
      if (fetchedTips.isEmpty) {
        hasMoreData.value = false;
        return;
      }

      pageIndex = targetPage;
      if (loadMore) {
        customTips.addAll(fetchedTips);
        randomTips.addAll(fetchedTips);
      } else {
        customTips.assignAll(fetchedTips);
        randomTips.assignAll(fetchedTips);
      }

      if (fetchedTips.length < _pageSize) {
        hasMoreData.value = false;
      }
    } catch (e) {
      if (!loadMore) {
        customTips.clear();
        randomTips.clear();
      }
      hasError.value = true;
      debugPrint('Error fetching custom health tips: $e');
    } finally {
      if (loadMore) {
        isLoadingMore.value = false;
      }
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }
}
