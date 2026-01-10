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
    celebrityPageController = PageController(
      initialPage: selectedDayIndex.value,
    );
    categoryPageController = PageController(
      initialPage: selectedCategoryIndex.value,
    );
    super.onInit();
  }

  void changeDay(int index) {
    selectedDayIndex.value = index;
    celebrityPageController.jumpToPage(index);
  }

  void changeCategory(int index) {
    selectedCategoryIndex.value = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (categoryPageController.hasClients) {
        categoryPageController.jumpToPage(index);
      }
    });
  }

  void onCelebrityPageChanged(int index) {
    selectedDayIndex.value = index;
  }

  void onCategoryPageChanged(int index) {
    selectedCategoryIndex.value = index;
  }

  Future<DietTagsResponse?> getAllDiets(
    BuildContext context,
    String categoryText,
  ) async {
    print("get all diets called with category: $categoryText");
    try {
      final payload = {
        "Tags": ["General", categoryText.isEmpty ? "Vegetarian" : categoryText],
        "FetchAll": true,
      };

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load diets (${response.statusCode})',
        );
        return null;
      }
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        response as Map,
      );
      categoryResponse.value = DietTagsResponse.fromJson(parsed);
      logLong("diet controller", categoryResponse.value.toJson().toString());
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
      return null;
    }
    return null;
  }

  Future<DietTagsResponse?> getAllSuggestions(BuildContext context) async {
    print("get all suggestions called");
    try {
      isLoading.value = true;
      List<String> tags = [];

      final localStorageManager = Get.put(LocalStorageManager());
      final bmiController = Get.put(BmiController());
      final day = localStorageManager.userMap['DayOfBirth'];
      final month = localStorageManager.userMap['MonthOfBirth'];
      final year = localStorageManager.userMap['YearOfBirth'];
      tags.add(bmiController.bmi_text.value);
      print("bmi text added to tags: ${bmiController.bmi_text.value}");

      // final bmitext = prefs.getString('bmi_text');
      // final activitylevel = prefs.getString('ActivityLevel');
      // final healthgoal = prefs.getString('HealthGoal');
      final storedGender = localStorageManager.userMap['Gender'];

      final activityLevel =
          localStorageManager.userGoalDataMap["ActivityLevel"] ?? "";
      final healthGoal =
          localStorageManager.userGoalDataMap["HealthGoal"] ?? "";
      tags.add(activityLevel);
      tags.add(healthGoal);

      // if (bmitext != null && bmitext.isNotEmpty) tags.add(bmitext);
      // if (activitylevel != null && activitylevel.isNotEmpty) tags.add(activitylevel);
      // if (healthgoal != null && healthgoal.isNotEmpty) tags.add(healthgoal);
      if (storedGender != null && storedGender.toString().isNotEmpty) {
        print("gender is $storedGender");
        if (storedGender.toString() == "Female") {
          tags.add(storedGender);
        }
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
          print("age group is 13 to 18");
          tags.add("Age 13 to 18");
        } else if (age >= 19 && age <= 25) {
          print("age group is 19 to 25");
          tags.add("Age 19 to 25");
        } else if (age > 25 && age <= 60) {
          print("age group is 25 to 60");
          tags.add("Age 25 to 60");
        }
      }

      final payload = {
        //"Tags": ["General", "Vegetarian"],
        //
        "Tags": tags,
        "FetchAll": true,
      };
      print("Tags for suggestions: $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showSnackbar(
          context: context,
          title: 'Error',
          message: 'Failed to load diets (${response.statusCode})',
        );
        return null;
      }
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        response as Map,
      );
      logLong("Response from getAllSuggestions: ", parsed.toString());
      suggestionsResponse.value = DietTagsResponse.fromJson(parsed);
      logLong("diet controller", suggestionsResponse.value.toJson().toString());
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
      return null;
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  Future<void> getCelebrityDiet(BuildContext context, String category) async {
    print("get celebrity diet called with category: $category");
    try {
      final payload = {
        "Tags": ["General", category],
        "FetchAll": true,
      };
      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );
      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load celebrity data (${response.statusCode})',
        );
        return;
      }
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        response as Map,
      );
      celebrityResponse.value = jsonDecode(jsonEncode(parsed));
      logLong(
        "diet controller ",
        suggestionsResponse.value.toJson().toString(),
      );
    } catch (e) {
      logLong(" Catch block ", e.toString());
    }
  }

  @override
  void onClose() {
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}
