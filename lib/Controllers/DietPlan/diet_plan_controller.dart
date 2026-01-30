import 'dart:convert';

import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import 'package:http/http.dart' as http;

import '../../env/env.dart';
import '../BMI/bmi_controller.dart';
import '../local_storage_manager.dart';

// To send - gender , age , bmi labels - obese etc
class DietPlanController extends GetxController {
  final selectedDayIndex = 0.obs;
  final selectedCategoryIndex = 0.obs;

  var isLoading = true.obs;
  var categoryResponse = DietTagsResponse(data: []).obs;
  var suggestionsResponse = DietTagsResponse(data: []).obs;
  var dietTagsDataResponse = DietTagData(mealPlan: [], tags: []).obs;
  var celebrityResponse = {}.obs;

  late PageController celebrityPageController;
  late PageController categoryPageController;

  @override
  void onInit() {
    debugPrint("🟢 DietPlanController onInit");

    celebrityPageController = PageController(
      initialPage: selectedDayIndex.value,
    );
    categoryPageController = PageController(
      initialPage: selectedCategoryIndex.value,
    );

    debugPrint(
      "📄 Initial pages → Day: ${selectedDayIndex.value}, Category: ${selectedCategoryIndex.value}",
    );

    super.onInit();
  }

  void changeDay(int index) {
    debugPrint("📅 changeDay called → $index");
    selectedDayIndex.value = index;
    celebrityPageController.jumpToPage(index);
  }

  void changeCategory(int index) {
    debugPrint("🍽️ changeCategory called → $index");
    selectedCategoryIndex.value = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (categoryPageController.hasClients) {
        debugPrint("➡️ Jumping to category page: $index");
        categoryPageController.jumpToPage(index);
      } else {
        debugPrint("⚠️ categoryPageController has no clients");
      }
    });
  }

  void onCelebrityPageChanged(int index) {
    debugPrint("🌟 Celebrity page changed → $index");
    selectedDayIndex.value = index;
  }

  void onCategoryPageChanged(int index) {
    debugPrint("📂 Category page changed → $index");
    selectedCategoryIndex.value = index;
  }

  Future<DietTagsResponse?> getAllDiets(
      BuildContext context,
      String categoryText,
      ) async {
    debugPrint("🔵 getAllDiets called | category: $categoryText");

    try {
      final payload = {
        "Tags": ["General", categoryText.isEmpty ? "Vegetarian" : categoryText],
        "FetchAll": true,
      };

      debugPrint("📤 getAllDiets payload → $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ getAllDiets HTTP error → ${response.statusCode}");
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load diets (${response.statusCode})',
        );
        return null;
      }

      final parsed = Map<String, dynamic>.from(response as Map);
      debugPrint("📥 getAllDiets response received");

      categoryResponse.value = DietTagsResponse.fromJson(parsed);

      debugPrint(
        "✅ Category diets count → ${categoryResponse.value.data}",
      );
    } catch (e, stack) {
      debugPrint("🔥 getAllDiets exception → $e");
      debugPrint(stack.toString());

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
    }

    return null;
  }

  Future<DietTagsResponse?> getAllSuggestions(BuildContext context) async {
    debugPrint("🟣 getAllSuggestions called");

    try {
      isLoading.value = true;
      List<String> tags = [];

      final localStorageManager = Get.find<LocalStorageManager>();
      final bmiController = Get.find<BmiController>();

      tags.add(bmiController.bmi_text.value);
      debugPrint("➕ BMI tag added → ${bmiController.bmi_text.value}");

      final storedGender = localStorageManager.userMap['Gender'];
      final activityLevel =
          localStorageManager.userGoalDataMap["ActivityLevel"] ?? "";
      final healthGoal =
          localStorageManager.userGoalDataMap["HealthGoal"] ?? "";

      tags.add(activityLevel);
      tags.add(healthGoal);

      debugPrint("🏃 ActivityLevel → $activityLevel");
      debugPrint("🎯 HealthGoal → $healthGoal");

      if (storedGender == "Female") {
        tags.add("Female");
        debugPrint("🚺 Gender tag added → Female");
      }

      final day = localStorageManager.userMap['DayOfBirth'];
      final month = localStorageManager.userMap['MonthOfBirth'];
      final year = localStorageManager.userMap['YearOfBirth'];

      if (day != null && month != null && year != null) {
        final today = DateTime.now();
        final birthDate = DateTime(year, month, day);
        int age = today.year - birthDate.year;

        if (today.month < birthDate.month ||
            (today.month == birthDate.month &&
                today.day < birthDate.day)) {
          age--;
        }

        debugPrint("🎂 Calculated age → $age");

        if (age >= 13 && age <= 18) {
          tags.add("Age 13 to 18");
        } else if (age >= 19 && age <= 25) {
          tags.add("Age 19 to 25");
        } else if (age > 25 && age <= 60) {
          tags.add("Age 25 to 60");
        }
      }

      final payload = {
        "Tags": tags,
        "FetchAll": true,
      };

      debugPrint("📤 getAllSuggestions payload → $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ getAllSuggestions HTTP error → ${response.statusCode}");
        CustomSnackbar.showSnackbar(
          context: context,
          title: 'Error',
          message: 'Failed to load diets (${response.statusCode})',
        );
        return null;
      }

      final parsed = Map<String, dynamic>.from(response as Map);
      debugPrint("📥 Suggestions response received");

      suggestionsResponse.value = DietTagsResponse.fromJson(parsed);

      debugPrint(
        "✅ Suggestions count → ${suggestionsResponse.value.data}",
      );
    } catch (e, stack) {
      debugPrint("🔥 getAllSuggestions exception → $e");
      debugPrint(stack.toString());

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      isLoading.value = false;
      debugPrint("⏹️ getAllSuggestions loading finished");
    }

    return null;
  }

  Future<void> getCelebrityDiet(BuildContext context, String category) async {
    debugPrint("⭐ getCelebrityDiet called | category: $category");

    try {
      final payload = {
        "Tags": ["General", category],
        "FetchAll": true,
      };

      debugPrint("📤 Celebrity payload → $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint(
          "❌ Celebrity API error → ${response.statusCode}",
        );
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load celebrity data (${response.statusCode})',
        );
        return;
      }

      final parsed = Map<String, dynamic>.from(response as Map);
      celebrityResponse.value = jsonDecode(jsonEncode(parsed));

      debugPrint("✅ Celebrity diet data loaded");
    } catch (e, stack) {
      debugPrint("🔥 getCelebrityDiet exception → $e");
      debugPrint(stack.toString());
    }
  }

  @override
  void onClose() {
    debugPrint("🔴 DietPlanController onClose");
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}