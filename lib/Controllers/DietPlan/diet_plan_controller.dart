import 'dart:convert';

import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import 'package:http/http.dart' as http;

import '../../env/env.dart';

// To send - gender , age , bmi labels - obese etc
class DietPlanController extends GetxController {
  final selectedDayIndex = 0.obs;
  final selectedCategoryIndex = 0.obs;

  var isLoading = true.obs;
  var categoryResponse = DietTagsResponse().obs;
  var suggestionsResponse = DietTagsResponse().obs;
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
      print("diet controller ${categoryResponse.value.toJson()}");
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
    try {
      isLoading.value = true;

      final payload = {
        "Tags": ["General", "Vegetarian"],
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
      suggestionsResponse.value = DietTagsResponse.fromJson(parsed);
      print("diet controller ${suggestionsResponse.value.toJson()}");
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

  Future<void> getCelebrityDiet(BuildContext context , String category) async {
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
      print("diet controller ${suggestionsResponse.value.toJson()}");
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void onClose() {
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}
