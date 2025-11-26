import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

class MoodController extends GetxController {
  List<String> moods = ['Pleasent', 'Unpleasent', 'Good'];

  // 0 = Happy, 1 = Neutral, 2 = Sad
  var selectedMoodIndex = (-1).obs;
  RxString selectedMood = ''.obs;

  
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


  Future<bool> updateMood() async {
    if (selectedMoodIndex.value == -1) {
      Get.snackbar('No Mood Selected', 'Please select your mood first');
      return false;
    }

    try {
      selectedMood.value = moods[selectedMoodIndex.value];
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('selectedMood', selectedMood.value);
      final now = DateTime.now();
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
        Get.snackbar(
          'Error',
          '❌ Failed to save Mood record: ${response.statusCode}',
        );
        return false;
      } else {
        Get.snackbar('Success', '✅ Mood record saved successfully');
        return true;
      }
    } catch (e) {
      Get.snackbar('Error', '❌ Exception while saving Mood record');
      return false;
    }
  }
}
