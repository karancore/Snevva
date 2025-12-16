import 'dart:convert';

import 'package:snevva/models/diet_tags_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import 'package:http/http.dart' as http;

import '../../env/env.dart';

class DietPlanController extends GetxController {
  final selectedDayIndex = 0.obs;
  final selectedCategoryIndex = 0.obs;

  var isLoading = true.obs;
  var dietTagResponse = DietTagsResponse().obs;

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
      isLoading.value = true;
      if (categoryText.isEmpty) {
        categoryText = " Non-Vegetarian";
      }
      Map<String, dynamic> payload = {
        "Tags": ["General", categoryText],
        "FetchAll": true,
      };
      final response = await ApiService.post(
        getDietByTags,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      // print("Payload: $payload");

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load diets : ${response.statusCode}',
        );
        print(response.body);
        return null;
      }
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        response as Map,
      );
      dietTagResponse.value = DietTagsResponse.fromJson(parsed);
      print("diet controller ${dietTagResponse.value.toJson()}");
    } catch (e) {
      //print(e);
      throw Exception(e);
      CustomSnackbar.showError(context: context, title: 'Error', message: '$e');
    }
  }

  @override
  void onClose() {
    celebrityPageController.dispose();
    categoryPageController.dispose();
    super.onClose();
  }
}
