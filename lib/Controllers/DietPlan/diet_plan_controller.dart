import 'package:http/http.dart' as http;
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../consts/consts.dart';
import '../../env/env.dart';
import '../BMI/bmi_controller.dart';
import '../local_storage_manager.dart';

class DietPlanController extends GetxController {
  static const int _pageSize = 8;

  final selectedDayIndex = 0.obs;
  final selectedCategoryIndex = 0.obs;
  final isCategoryLoading = false.obs;
  final isSuggestionsLoading = false.obs;
  final isCelebrityLoading = false.obs;
  final isCategoryLoadingMore = false.obs;
  final isSuggestionsLoadingMore = false.obs;
  final isCelebrityLoadingMore = false.obs;
  final hasMoreCategoryData = true.obs;
  final hasMoreSuggestionsData = true.obs;
  final hasMoreCelebrityData = true.obs;

  var categoryResponse = DietTagsResponse(data: []).obs;
  var categoryDataResponse = DietTagData(mealPlan: [], tags: []).obs;
  var suggestionsResponse = DietTagsResponse(data: []).obs;
  var dietTagsDataResponse = DietTagData(mealPlan: [], tags: []).obs;

  // Replaces raw Map usage: typed list for celebrity responses
  var celebrityList = <DietTagData>[].obs;
  int categoryPageIndex = 1;
  int suggestionsPageIndex = 1;
  int celebrityPageIndex = 1;
  String selectedCategoryText = 'Vegetarian';
  List<String> _activeSuggestionTags = <String>[];
  final ScrollController categoryScrollController = ScrollController();
  final ScrollController suggestionsScrollController = ScrollController();
  final ScrollController celebrityScrollController = ScrollController();

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
    categoryScrollController.addListener(_onCategoryScroll);
    suggestionsScrollController.addListener(_onSuggestionsScroll);
    celebrityScrollController.addListener(_onCelebrityScroll);

    super.onInit();
  }

  void _onCategoryScroll() {
    if (!categoryScrollController.hasClients) return;
    final position = categoryScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      getAllDiets(null, selectedCategoryText, loadMore: true);
    }
  }

  void _onSuggestionsScroll() {
    if (!suggestionsScrollController.hasClients) return;
    final position = suggestionsScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      getAllSuggestions(null, loadMore: true);
    }
  }

  void _onCelebrityScroll() {
    if (!celebrityScrollController.hasClients) return;
    final position = celebrityScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      getCelebrity(null, loadMore: true);
    }
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
    BuildContext? context,
    String categoryText, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (isCategoryLoadingMore.value || !hasMoreCategoryData.value)) {
      return null;
    }

    final String normalizedCategory =
        categoryText.isEmpty ? "Vegetarian" : categoryText;
    final int targetPage = loadMore ? categoryPageIndex + 1 : 1;

    debugPrint(
      "🔍 [API - getAllDiets] Fetching category: $normalizedCategory (page $targetPage)",
    );
    if (loadMore) {
      isCategoryLoadingMore.value = true;
    } else {
      selectedCategoryText = normalizedCategory;
      categoryPageIndex = 1;
      hasMoreCategoryData.value = true;
      isCategoryLoading.value = true;
      categoryResponse.value = DietTagsResponse(data: []);
    }
    try {
      final payload = {
        "Tags": ["General", normalizedCategory],
        "FetchAll": false,
        "Count": _pageSize,
        "Index": targetPage,
      };
      debugPrint("🚀 [API - getAllDiets] Payload: $payload");

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
      final fetchedResponse = DietTagsResponse.fromJson(parsed);
      final fetchedItems = List<DietTagData>.from(fetchedResponse.data ?? []);
      if (fetchedItems.isEmpty) {
        hasMoreCategoryData.value = false;
        return fetchedResponse;
      }

      categoryPageIndex = targetPage;
      final mergedItems =
          loadMore
              ? <DietTagData>[
                ...(categoryResponse.value.data ?? <DietTagData>[]),
                ...fetchedItems,
              ]
              : fetchedItems;

      categoryResponse.value = DietTagsResponse(
        status: fetchedResponse.status,
        statusType: fetchedResponse.statusType,
        message: fetchedResponse.message,
        data: mergedItems,
      );
      hasMoreCategoryData.value = fetchedItems.length == _pageSize;
      logLong(
        'categoryResponse.value',
        categoryResponse.value.toJson().toString(),
      );

      debugPrint(
        "✅ [API - getAllDiets] Success. Items found: ${categoryResponse.value.data?.length ?? 0}",
      );
      return categoryResponse.value;
    } catch (e) {
      debugPrint("🔥 [API - getAllDiets] Exception: $e");
    } finally {
      if (loadMore) {
        isCategoryLoadingMore.value = false;
      } else {
        isCategoryLoading.value = false;
      }
    }
    return null;
  }

  Future<void> getCelebrity(
    BuildContext? context, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (isCelebrityLoadingMore.value || !hasMoreCelebrityData.value)) {
      return;
    }

    final targetPage = loadMore ? celebrityPageIndex + 1 : 1;
    if (loadMore) {
      isCelebrityLoadingMore.value = true;
    } else {
      isCelebrityLoading.value = true;
      celebrityPageIndex = 1;
      hasMoreCelebrityData.value = true;
      celebrityList.clear();
    }
    try {
      final payload = {
        "Tags": ["General", "Celebrity"],
        "FetchAll": false,
        "Count": _pageSize,
        "Index": targetPage,
      };
      debugPrint("🚀 [API - getCelebrity] Payload: $payload");

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

      final parsedResponse = DietTagsResponse.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
      final parsedList = List<DietTagData>.from(parsedResponse.data ?? []);

      if (parsedList.isEmpty) {
        hasMoreCelebrityData.value = false;
        return;
      }

      celebrityPageIndex = targetPage;
      if (loadMore) {
        celebrityList.addAll(parsedList);
      } else {
        celebrityList.assignAll(parsedList);
      }
      hasMoreCelebrityData.value = parsedList.length == _pageSize;

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
      if (loadMore) {
        isCelebrityLoadingMore.value = false;
      } else {
        isCelebrityLoading.value = false;
      }
    }
  }

  Future<DietTagsResponse?> getAllSuggestions(
    BuildContext? context, {
    bool loadMore = false,
  }) async {
    if (loadMore &&
        (isSuggestionsLoadingMore.value || !hasMoreSuggestionsData.value)) {
      return null;
    }

    final targetPage = loadMore ? suggestionsPageIndex + 1 : 1;
    debugPrint("🧠 [Suggestions] Generating tags for user profile...");
    try {
      if (loadMore) {
        isSuggestionsLoadingMore.value = true;
      } else {
        isSuggestionsLoading.value = true;
        suggestionsPageIndex = 1;
        hasMoreSuggestionsData.value = true;
        suggestionsResponse.value = DietTagsResponse(data: []);
        _activeSuggestionTags = <String>[];
      }

      final profileTags = _buildSuggestionTags();
      debugPrint("🚀 [Suggestions] Final Tag List: $profileTags");

      final tagAttempts =
          loadMore && _activeSuggestionTags.isNotEmpty
              ? <List<String>>[_activeSuggestionTags]
              : _buildSuggestionTagAttempts(profileTags);

      DietTagsResponse? parsedResponse;
      List<DietTagData> fetchedItems = <DietTagData>[];
      List<String> usedTags = <String>[];

      for (var index = 0; index < tagAttempts.length; index++) {
        final tags = tagAttempts[index];
        if (index > 0) {
          debugPrint("ℹ️ [Suggestions] Trying fallback tags: $tags");
        }

        final response = await _fetchDietTagsByTags(
          tags,
          targetPage,
          "[Suggestions]",
        );
        if (response == null) return null;

        parsedResponse = response;
        fetchedItems = List<DietTagData>.from(response.data ?? []);
        usedTags = tags;

        if (fetchedItems.isNotEmpty) break;
      }

      if (fetchedItems.isEmpty) {
        hasMoreSuggestionsData.value = false;
        return parsedResponse;
      }

      final responseWithItems = parsedResponse;
      if (responseWithItems == null) return null;

      _activeSuggestionTags = usedTags;
      suggestionsPageIndex = targetPage;
      final mergedItems =
          loadMore
              ? <DietTagData>[
                ...(suggestionsResponse.value.data ?? <DietTagData>[]),
                ...fetchedItems,
              ]
              : fetchedItems;
      suggestionsResponse.value = DietTagsResponse(
        status: responseWithItems.status,
        statusType: responseWithItems.statusType,
        message: responseWithItems.message,
        data: mergedItems,
      );
      hasMoreSuggestionsData.value = fetchedItems.length == _pageSize;

      logLong(
        "suggestionsResponse.value",
        suggestionsResponse.value.toJson().toString(),
      );
      debugPrint(
        "📊 [Suggestions] Parsing complete. Suggestions found: ${suggestionsResponse.value.data?.length}",
      );
      return suggestionsResponse.value;
    } catch (e, stack) {
      debugPrint("🔥 [Suggestions] Critical Error: $e\n$stack");
    } finally {
      if (loadMore) {
        isSuggestionsLoadingMore.value = false;
      } else {
        isSuggestionsLoading.value = false;
      }
    }
    return null;
  }

  Future<DietTagsResponse?> _fetchDietTagsByTags(
    List<String> tags,
    int page,
    String logPrefix,
  ) async {
    final payload = {
      "Tags": tags,
      "FetchAll": false,
      "Count": _pageSize,
      "Index": page,
    };
    debugPrint("🚀 $logPrefix Payload: $payload");

    final response = await ApiService.post(
      getDietByTags,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response) {
      debugPrint("❌ $logPrefix HTTP Error: ${response.statusCode}");
      return null;
    }

    return DietTagsResponse.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  List<List<String>> _buildSuggestionTagAttempts(List<String> profileTags) {
    final attempts = <List<String>>[];

    void addAttempt(Iterable<String> tags) {
      final cleaned = _cleanTags(tags);
      if (cleaned.isEmpty || attempts.any((item) => _sameTags(item, cleaned))) {
        return;
      }
      attempts.add(cleaned);
    }

    addAttempt(profileTags);
    addAttempt(<String>['General', ...profileTags]);
    addAttempt(<String>['General', selectedCategoryText]);
    addAttempt(<String>['General', 'Vegetarian']);
    addAttempt(<String>['General']);

    return attempts;
  }

  List<String> _cleanTags(Iterable<String> tags) {
    final cleaned = <String>[];
    for (final tag in tags) {
      final value = tag.trim();
      if (value.isEmpty || cleaned.contains(value)) continue;
      cleaned.add(value);
    }
    return cleaned;
  }

  bool _sameTags(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  List<String> _buildSuggestionTags() {
    final tags = <String>[];
    final localStorageManager = Get.find<LocalStorageManager>();
    final bmiController = Get.find<BmiController>();

    final bmiLabel = bmiController.bmi_text.value;
    if (bmiLabel.isNotEmpty) {
      tags.add(bmiLabel);
    }

    final storedGender = localStorageManager.userMap['Gender'];
    final activityLevel =
        localStorageManager.userGoalDataMap["ActivityLevel"]?.toString() ?? "";
    final healthGoal =
        localStorageManager.userGoalDataMap["HealthGoal"]?.toString() ?? "";

    if (activityLevel.isNotEmpty) tags.add(activityLevel);
    if (healthGoal.isNotEmpty) tags.add(healthGoal);
    if (storedGender == "Female") tags.add("Female");

    final year = int.tryParse(
      localStorageManager.userMap['YearOfBirth']?.toString() ?? '',
    );
    if (year != null) {
      final age = DateTime.now().year - year;
      if (age >= 13 && age <= 18) {
        tags.add("Age 13 to 18");
      } else if (age >= 19 && age <= 25) {
        tags.add("Age 19 to 25");
      } else if (age > 25 && age <= 60) {
        tags.add("Age 25 to 60");
      }
    }

    return tags;
  }

  @override
  void onClose() {
    debugPrint("🗑️ [DietPlanController] Disposing Controllers");
    categoryScrollController.removeListener(_onCategoryScroll);
    suggestionsScrollController.removeListener(_onSuggestionsScroll);
    celebrityScrollController.removeListener(_onCelebrityScroll);
    categoryScrollController.dispose();
    suggestionsScrollController.dispose();
    celebrityScrollController.dispose();
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}
