import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:snevva/consts/consts.dart';

import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class BmiController extends GetxService {
  static const int _pageSize = 8;

  RxInt age = 0.obs;
  RxString bmi_text = "Great-Shape".obs;
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;

  final RxDouble height = 0.0.obs; // in cm
  final RxDouble weight = 0.0.obs; // in kg
  final RxDouble bmi = 0.0.obs;

  var isLoading = true.obs;
  var hasError = false.obs;
  var isLoadingMore = false.obs;
  var hasMoreData = true.obs;
  int pageIndex = 1;

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
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

  Future<void> loadUserBMI() async {
    // // final prefs = await SharedPreferences.getInstance();
    // final savedHeight = prefs.getDouble('height') ?? 0.0; // cm
    // final savedWeight = prefs.getDouble('weight') ?? 0.0; // kg

    final localStorageManager = Get.find<LocalStorageManager>();
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

    debugPrint('Loaded Height: ${height.value} cm, Weight: ${weight.value} kg');

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
    debugPrint("===== loadAllHealthTips Called =====");

    isLoading.value = true;
    hasError.value = false;

    debugPrint("isLoading: ${isLoading.value}");
    debugPrint("hasError: ${hasError.value}");

    try {
      debugPrint("Calling GetCustomHealthTips()...");

      await GetCustomHealthTips();

      debugPrint("GetCustomHealthTips completed successfully");

      debugPrint("customTips Count: ${customTips.length}");
      debugPrint("randomTips Count: ${randomTips.length}");
    } catch (e, stackTrace) {
      hasError.value = true;

      debugPrint("===== ERROR IN loadAllHealthTips =====");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load health tips',
      );
    } finally {
      isLoading.value = false;

      debugPrint("Loading finished");
      debugPrint("isLoading: ${isLoading.value}");
      debugPrint("hasError: ${hasError.value}");

      debugPrint("===== loadAllHealthTips Finished =====");
    }
  }
  Future<void> GetCustomHealthTips({bool loadMore = false}) async {
    debugPrint("===== GetCustomHealthTips Called =====");
    debugPrint("loadMore: $loadMore");

    if (loadMore && (isLoadingMore.value || !hasMoreData.value)) {
      debugPrint(
        "Skipping API call -> isLoadingMore: ${isLoadingMore.value}, hasMoreData: ${hasMoreData.value}",
      );
      return;
    }

    final targetPage = loadMore ? pageIndex + 1 : 1;

    debugPrint("Current pageIndex: $pageIndex");
    debugPrint("Target page: $targetPage");

    if (loadMore) {
      isLoadingMore.value = true;
      debugPrint("Pagination loading started");
    } else {
      hasMoreData.value = true;
      pageIndex = 1;

      debugPrint("Refreshing data");
      debugPrint("Clearing previous tips");

      customTips.clear();
      randomTips.clear();
    }

    try {
      List<String> tags = ['BMI', bmi_text.value];

      debugPrint("BMI Text: ${bmi_text.value}");
      debugPrint("Age: ${age.value}");

      if (age.value >= 13 && age.value <= 18) {
        tags.add("Age 13 to 18");
      } else if (age.value >= 19 && age.value <= 25) {
        tags.add("Age 19 to 25");
      } else if (age.value > 25 && age.value <= 60) {
        tags.add("Age 25 to 60");
      }

      debugPrint("Generated Tags: $tags");

      final payload = {
        'Tags': tags,
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
      };

      debugPrint("API Payload: $payload");

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("Raw API Response: $response");

      if (response is http.Response) {
        debugPrint("HTTP Error Status: ${response.statusCode}");
        throw Exception('API Error: ${response.statusCode}');
      }

      final parsedData = jsonDecode(jsonEncode(response));

      debugPrint("Parsed Response: $parsedData");

      final fetchedTips = List<dynamic>.from(parsedData['data'] ?? []);

      debugPrint("Fetched Tips Count: ${fetchedTips.length}");

      if (fetchedTips.isEmpty) {
        debugPrint("No more tips available");
        hasMoreData.value = false;
        return;
      }

      pageIndex = targetPage;

      debugPrint("Updated pageIndex: $pageIndex");

      if (loadMore) {
        customTips.addAll(fetchedTips);
        randomTips.addAll(fetchedTips);

        debugPrint(
          "Added more tips -> customTips: ${customTips.length}, randomTips: ${randomTips.length}",
        );
      } else {
        customTips.assignAll(fetchedTips);
        randomTips.assignAll(fetchedTips);

        debugPrint(
          "Assigned fresh tips -> customTips: ${customTips.length}, randomTips: ${randomTips.length}",
        );
      }

      if (fetchedTips.length < _pageSize) {
        hasMoreData.value = false;
        debugPrint("Reached last page");
      } else {
        debugPrint("More data available");
      }
    } catch (e, stackTrace) {
      if (!loadMore) {
        customTips.clear();
        randomTips.clear();
      }

      hasError.value = true;

      debugPrint("===== ERROR IN GetCustomHealthTips =====");
      debugPrint("Error: $e");
      debugPrint("StackTrace: $stackTrace");
    } finally {
      if (loadMore) {
        isLoadingMore.value = false;
        debugPrint("Pagination loading ended");
      }

      debugPrint("===== GetCustomHealthTips Finished =====");
    }
  }
  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }
}
