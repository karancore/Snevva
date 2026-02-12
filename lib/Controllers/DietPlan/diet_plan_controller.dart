import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../consts/consts.dart';
import 'package:http/http.dart' as http;

import '../../env/env.dart';
import '../BMI/bmi_controller.dart';
import '../local_storage_manager.dart';

class DietPlanController extends GetxController {
  final selectedDayIndex = 0.obs;
  final selectedCategoryIndex = 0.obs;
  final isCategoryLoading = false.obs;
  final isSuggestionsLoading = false.obs;
  final isCelebrityLoading = false.obs;

  var categoryResponse = DietTagsResponse(data: []).obs;
  var categoryDataResponse = DietTagData(mealPlan: [], tags: []).obs;
  var suggestionsResponse = DietTagsResponse(data: []).obs;
  var dietTagsDataResponse = DietTagData(mealPlan: [], tags: []).obs;

  // Replaces raw Map usage: typed list for celebrity responses
  var celebrityList = <DietTagData>[].obs;

  late PageController celebrityPageController;
  late PageController categoryPageController;

  @override
  void onInit() {
    debugPrint("🟢 [DietPlanController] Initializing...");
    celebrityPageController = PageController(
      initialPage: selectedDayIndex.value,
    );
    categoryPageController = PageController(
      initialPage: selectedCategoryIndex.value,
    );

    super.onInit();
  }

  void onCelebrityPageChanged(int index) {
    if (selectedDayIndex.value != index) {
      selectedDayIndex.value = index;
    }
  }

  void changeDay(int index) {
    if (selectedDayIndex.value == index) return;

    selectedDayIndex.value = index;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (celebrityPageController.hasClients) {
        celebrityPageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void changeCategory(int index) {
    debugPrint("🍽️ [Category Change] Index: $index");
    selectedCategoryIndex.value = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (categoryPageController.hasClients) {
        categoryPageController.jumpToPage(index);
      } else {
        debugPrint("⚠️ [Category Change] PageController not attached yet.");
      }
    });
  }

  Future<DietTagsResponse?> getAllDiets(
    BuildContext context,
    String categoryText,
  ) async {
    debugPrint(
      "🔍 [API - getAllDiets] Fetching category: ${categoryText.isEmpty ? 'Vegetarian (Default)' : categoryText}",
    );
    isCategoryLoading.value = true;
    try {
      final payload = {
        "Tags": ["General", categoryText.isEmpty ? "Vegetarian" : categoryText],
        "FetchAll": true,
      };
      print("🚀 [API - getAllDiets] Payload: $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ [API - getAllDiets] Failed: HTTP ${response.statusCode}");
        return null;
      }
      // if(categoryText == "Celebrity"){
      //
      //   categoryResponse.value = DietTagsResponse.fromJson(parsed);
      // }

      final parsed = Map<String, dynamic>.from(response as Map);
      categoryResponse.value = DietTagsResponse.fromJson(parsed);
      logLong(
        'categoryResponse.value',
        categoryResponse.value.toJson().toString(),
      );

      debugPrint(
        "✅ [API - getAllDiets] Success. Items found: ${categoryResponse.value.data?.length ?? 0}",
      );
    } catch (e) {
      debugPrint("🔥 [API - getAllDiets] Exception: $e");
    } finally {
      isCategoryLoading.value = false;
    }
    return null;
  }

  /// Helper to normalize media fields. Accepts either String or Map and returns a usable URL string.
  String? _extractMediaUrl(dynamic media) {
    if (media == null) return null;
    if (media is String) {
      return media.isEmpty ? null : media;
    }
    if (media is Map) {
      final cdn =
          media['CdnUrl'] ?? media['cdnUrl'] ?? media['Url'] ?? media['url'];
      if (cdn == null) return null;
      final cdnStr = cdn.toString();
      if (cdnStr.startsWith('http')) return cdnStr;
      return 'https://$cdnStr';
    }
    return null;
  }

  Future<void> getCelebrity(BuildContext context) async {
    isCelebrityLoading.value = true;
    try {
      final payload = {
        "Tags": ["General", "Celebrity"],
        "FetchAll": true,
      };
      print("🚀 [API - getCelebrity] Payload: $payload");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ [API - getCelebrity] HTTP Error: ${response.statusCode}");
        return;
      }

      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        response as Map,
      );
      final List<dynamic> data = parsed['data'] ?? [];

      final List<DietTagData> parsedList =
          data.map((item) {
            final Map<String, dynamic> it = Map<String, dynamic>.from(
              item as Map,
            );

            // Convert meal plan
            final mealPlanRaw = it['MealPlan'] as List? ?? [];
            final List<MealPlanItem> mealPlan =
                mealPlanRaw.map((mp) {
                  final Map<String, dynamic> mpMap = Map<String, dynamic>.from(
                    mp as Map,
                  );
                  return MealPlanItem(
                    day: mpMap['Day'] ?? 0,
                    breakFast: (mpMap['BreakFast'] ?? '').toString(),
                    breakFastMedia: _extractMediaUrl(mpMap['BreakFastMedia']),
                    lunch: (mpMap['Lunch'] ?? '').toString(),
                    lunchMedia: _extractMediaUrl(mpMap['LunchMedia']),
                    evening: (mpMap['Evening'] ?? '').toString(),
                    eveningMedia: _extractMediaUrl(mpMap['EveningMedia']),
                    dinner: (mpMap['Dinner'] ?? '').toString(),
                    dinnerMedia: _extractMediaUrl(mpMap['DinnerMedia']),
                  );
                }).toList();

            return DietTagData(
              id: it['Id'],
              dataCode: it['DataCode']?.toString(),
              thumbnailMedia: _extractMediaUrl(it['ThumbnailMedia']),
              heading: it['Heading']?.toString(),
              title: it['Title']?.toString(),
              shortDescription: it['ShortDescription']?.toString(),
              mealPlan: mealPlan,
              tags: List<String>.from(it['Tags'] ?? []),
              isActive: it['IsActive'],
            );
          }).toList();

      celebrityList.value = parsedList;

      logLong(
        'celebrityList',
        celebrityList.map((e) => e.toJson()).toList().toString(),
      );

      debugPrint(
        "✅ [API - getCelebrity] Success. Celebrity items: ${celebrityList.length}",
      );
    } catch (e, stack) {
      debugPrint("🔥 [API - getCelebrity] Exception: $e\n$stack");
    } finally {
      isCelebrityLoading.value = false;
    }
  }

  Future<DietTagsResponse?> getAllSuggestions(BuildContext context) async {
    debugPrint("🧠 [Suggestions] Generating tags for user profile...");
    try {
      isSuggestionsLoading.value = true;

      List<String> tags = [];

      final localStorageManager = Get.find<LocalStorageManager>();
      final bmiController = Get.find<BmiController>();

      // Tracking tag inputs
      String bmiLabel = bmiController.bmi_text.value;
      tags.add(bmiLabel);

      final storedGender = localStorageManager.userMap['Gender'];
      final activityLevel =
          localStorageManager.userGoalDataMap["ActivityLevel"] ?? "";
      final healthGoal =
          localStorageManager.userGoalDataMap["HealthGoal"] ?? "";

      if (activityLevel.isNotEmpty) tags.add(activityLevel);
      if (healthGoal.isNotEmpty) tags.add(healthGoal);
      if (storedGender == "Female") tags.add("Female");

      // Age Logic
      final year = localStorageManager.userMap['YearOfBirth'];

      num age = DateTime.now().year - year;
      print("🚀 [Suggestions] Calculated Age: $age");
      if (age >= 13 && age <= 18) {
        tags.add("Age 13 to 18");
      } else if (age >= 19 && age <= 25) {
        tags.add("Age 19 to 25");
      } else if (age > 25 && age <= 60) {
        tags.add("Age 25 to 60");
      }
      debugPrint("🚀 [Suggestions] Final Tag List: $tags");

      final payload = {"Tags": tags, "FetchAll": true};
      print("🚀 [Suggestions] Payload: {Tags: $payload, FetchAll: true}");

      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ [Suggestions] HTTP Error: ${response.statusCode}");
        return null;
      }

      suggestionsResponse.value = DietTagsResponse.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      logLong(
        "suggestionsResponse.value",
        suggestionsResponse.value.toJson().toString(),
      );
      debugPrint(
        "📊 [Suggestions] Parsing complete. Suggestions found: ${suggestionsResponse.value.data?.length}",
      );
    } catch (e, stack) {
      debugPrint("🔥 [Suggestions] Critical Error: $e\n$stack");
    } finally {
      isSuggestionsLoading.value = false;
    }
    return null;
  }

  @override
  void onClose() {
    debugPrint("🗑️ [DietPlanController] Disposing Controllers");
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}
