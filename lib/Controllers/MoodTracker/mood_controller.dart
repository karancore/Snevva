import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';

class MoodController extends GetxService {
  List<String> moods = ['Pleasant', 'Unpleasant', 'Good'];

  // 0 = Happy, 1 = Neutral, 2 = Sad
  var selectedMoodIndex = (-1).obs;
  RxString selectedMood = ''.obs;

  String get selectedUserMood => moods[selectedMoodIndex.value];

  void selectMood(int index) {
    selectedMoodIndex.value = index;
  }

  void swipeLeft() {
    if (selectedMoodIndex.value < moods.length - 1) {
      selectedMoodIndex.value++;
    }
  }

  void swipeRight() {
    if (selectedMoodIndex.value > 0) {
      selectedMoodIndex.value--;
    }
  }

  Future<void> loadmoodfromAPI({required int month, required int year}) async {
    try {
      final payload = {"Month": month, "Year": year};

      final response = await ApiService.post(
        moodTrackData,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to load mood data',
        );
        return;
      }

      final resbody = jsonDecode(jsonEncode(response));
      debugPrint('✅ Mood data loaded: $resbody');

      final List moodList = resbody['data']?['MoodTrackerData'] ?? [];

      // ✅ NO DATA → DEFAULT MOOD
      if (moodList.isEmpty) {
        selectedMood.value = 'All Good?'; // or "All Good"
        selectedMoodIndex.value = moods.indexOf('Good');

        debugPrint('🙂 No mood data → Default set to Good');
        return;
      }

      // ✅ DATA EXISTS → TAKE LATEST ENTRY
      final latestMood = moodList.last['Mood'];
      print('Latest mood from API: $latestMood');

      if (moods.contains(latestMood)) {
        selectedMood.value = latestMood;
        selectedMoodIndex.value = moods.indexOf(latestMood);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('selectedMood', selectedMood.value);

        debugPrint('😄 Mood mapped from API → $latestMood');
      } else {
        // Safety fallback
        selectedMood.value = 'Good';
        selectedMoodIndex.value = moods.indexOf('Good');
      }
    } catch (e) {
      debugPrint('❌ Exception while loading mood data: $e');

      // Fail-safe default
      selectedMood.value = 'Good';
      selectedMoodIndex.value = moods.indexOf('Good');
    }
  }

  Future<bool> updateMood(BuildContext context) async {
    if (selectedMoodIndex.value == -1) {
      Get.snackbar('No Mood Selected', 'Please select your mood first');
      return false;
    }

    try {
      selectedMood.value = moods[selectedMoodIndex.value];
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('selectedMood', selectedMood.value);

      final payload = {
        "Mood": moods[selectedMoodIndex.value],
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
      };

      final response = await ApiService.post(
        logmood,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Mood record: ${response.statusCode}',
        );
        return false;
      } else {
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Mood record saved successfully',
        );
        return true;
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while saving Mood record',
      );
      return false;
    }
  }
}
