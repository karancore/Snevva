import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/consts/consts.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class MentalWellnessController extends GetxController {
  dynamic generalMusic = <dynamic>[].obs;
  dynamic selectedGenralMusics = <dynamic>[].obs;
  dynamic meditationMusic = <dynamic>[].obs;
  dynamic selectedmeditationMusic;

  dynamic natureMusic = <dynamic>[].obs;
  dynamic selectedNatureMusics = <dynamic>[].obs;
  var isLoading = true.obs;
  var hasError = false.obs;

  // @override
  // void onInit() {
  //   super.onInit();
  //   fetchMusic();
  // }

  Future<void> fetchMusic(BuildContext context) async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await loadGeneralMusic(context);
      await loadMedicationMusic(context);
      await loadNatureMusic(context);
    } catch (e) {
      hasError.value = true;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load music.',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadGeneralMusic(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["General"],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
      };
      final response = await ApiService.post(
        genralmusicAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load general music: ${response.statusCode}',
        );
        return;
      }

      dynamic parsedData = jsonDecode(jsonEncode(response));
      generalMusic = parsedData['data'] ?? [];

      final List<dynamic> allMusic = List.from(generalMusic);
      allMusic.shuffle();
      selectedGenralMusics.assignAll(allMusic.take(2).toList());
    } catch (e) {
      generalMusic.value = [];
      selectedGenralMusics.clear();
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load general music',
      );
    }
  }

  Future<void> loadMedicationMusic(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["Meditation For You"],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
      };
      final response = await ApiService.post(
        genralmusicAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load meditation music: ${response.statusCode}',
        );
        return;
      }

      dynamic parsedData = jsonDecode(jsonEncode(response));
      meditationMusic = parsedData['data'] ?? [];
      final random = Random();
      selectedmeditationMusic =
          meditationMusic[random.nextInt(meditationMusic.length)];
      print(selectedmeditationMusic);
    } catch (e) {
      meditationMusic.value = [];
      selectedmeditationMusic = null;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load meditation music.',
      );
    }
  }

  Future<void> loadNatureMusic(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["Nature Sounds"],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
      };
      final response = await ApiService.post(
        genralmusicAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load Nature  music: ${response.statusCode}',
        );
        return;
      }

      dynamic parsedData = jsonDecode(jsonEncode(response));
      natureMusic = parsedData['data'] ?? [];

      final List<dynamic> allMusic = List.from(natureMusic);
      allMusic.shuffle();
      selectedNatureMusics.assignAll(allMusic.take(4).toList());
    } catch (e) {
      natureMusic.value = [];
      selectedNatureMusics.clear();
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load Nature music',
      );
    }
  }
}
