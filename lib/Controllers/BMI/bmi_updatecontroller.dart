import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'package:snevva/consts/consts.dart';

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

    ever(height, (_) => updateBmiValues());
    ever(weight, (_) => updateBmiValues());
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      GetCustomHealthTips(loadMore: true);
    }
  }

  void updateBmiValues() {
    // This controller may initialize before active profile data is loaded.
    // Keep this method calculation-only so default 0.0 values never overwrite
    // the user's cached height/weight.
    if (height.value > 0 && weight.value > 0) {
      final heightInMeters = height.value / 100;
      bmi.value = double.parse(
        (weight.value / (heightInMeters * heightInMeters)).toStringAsFixed(2),
      );

      if (bmi.value < 18.5) {
        bmi_text.value = "Underweight";
      } else if (bmi.value < 24.9) {
        bmi_text.value = "Great-Shape";
      } else if (bmi.value < 29.9) {
        bmi_text.value = "Overweight";
      } else {
        bmi_text.value = "Obese";
      }

      debugPrint('✅ BMI recalculated: ${bmi.value} → ${bmi_text.value}');
    }
  }

  Future<bool> setHeightAndWeight(
    BuildContext context,
    dynamic age,
    dynamic height,
    dynamic weight,
  ) async {
    final heightValue = _positiveDoubleOrNull(height);
    final weightValue = _positiveDoubleOrNull(weight);

    if (heightValue == null || weightValue == null) {
      CustomSnackbar.showError(
        context: context,
        title: 'Invalid value',
        message: 'Height and weight must be greater than zero.',
      );
      return false;
    }

    final flag1 = await editprofileController.saveHeight(
      context,
      heightValue,
      day: DateTime.now().day,
      month: DateTime.now().month,
      year: DateTime.now().year,
      time: TimeOfDay.now().format(context),
    );
    final flag2 = await editprofileController.saveWeight(
      context,
      weightValue,
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
    this.height.value = heightValue;
    this.weight.value = weightValue;
    await _saveHeightAndWeightLocally(heightValue, weightValue);

    debugPrint(
      'Set Age: $age, Height: $heightValue cm, Weight: $weightValue kg',
    );
    // updateBmiValues();
    return true;
  }

  Future<void> loadUserBMI() async {
    // // final prefs = await SharedPreferences.getInstance();
    // final savedHeight = prefs.getDouble('height') ?? 0.0; // cm
    // final savedWeight = prefs.getDouble('weight') ?? 0.0; // kg

    final savedHeight = _readGoalValue('HeightData');
    final savedWeight = _readGoalValue('WeightData');

    if (savedHeight == null || savedWeight == null) {
      height.value = 0.0;
      weight.value = 0.0;
      bmi.value = 0.0;
      debugPrint('BMI data unavailable; skipping height/weight cache update');
      return;
    }

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

  double? _readGoalValue(String key) {
    final rawValue = localStorageManager.userGoalDataMap[key]?['Value'];
    return _positiveDoubleOrNull(rawValue);
  }

  double? _positiveDoubleOrNull(dynamic value) {
    final parsed =
        value is num ? value.toDouble() : double.tryParse(value.toString());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  Map<String, dynamic> _goalDataMapFor(String key) {
    final current = localStorageManager.userGoalDataMap[key];
    if (current is Map) return Map<String, dynamic>.from(current);
    return <String, dynamic>{};
  }

  Future<void> _saveHeightAndWeightLocally(
    double heightValue,
    double weightValue,
  ) async {
    final heightData = _goalDataMapFor('HeightData')..['Value'] = heightValue;
    final weightData = _goalDataMapFor('WeightData')..['Value'] = weightValue;

    localStorageManager.userGoalDataMap['HeightData'] = heightData;
    localStorageManager.userGoalDataMap['WeightData'] = weightData;
    await localStorageManager.saveUserGoalMap();
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
