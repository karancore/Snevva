import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/mood_model.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../consts/images.dart';

class MoodController extends GetxService {
  List<String> moods = ['Pleasant', 'Good', 'Unpleasant'];

  // 0 = Happy, 1 = Neutral, 2 = Sad
  var selectedMoodIndex = (-1).obs;
  RxString selectedMood = ''.obs;

  String get selectedUserMood => moods[selectedMoodIndex.value];

  void selectMood(int index) {
    selectedMoodIndex.value = index;
  }

  String getImage(String mood){
    switch(mood){
      case 'Pleasant':
        return pleasant;
      case 'Good':
        return neutral;
      case 'Unpleasant':
        return unpleasant;
      default:
        return neutral; // Default to "Good" if something goes wrong
    }
  }

  RxList<Map<String, String>> moodEntries = <Map<String, String>>[].obs;

  Future<List<MoodModel>> loadMoodFromAPI(
      {required int month, required int year}) async {
    try {
      final payload = {"Month": month, "Year": year};

      debugPrint("📤 API Request Payload: $payload");

      final response = await ApiService.post(
        moodTrackData,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📥 Raw API Response: $response");

      if (response is http.Response) {
        debugPrint("❌ API returned http.Response instead of decoded body");
        debugPrint("❌ Status Code: ${response.statusCode}");
        debugPrint("❌ Body: ${response.body}");

        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to load mood data',
        );
        return [];
      }

      final resbody = jsonDecode(jsonEncode(response));

      debugPrint("✅ Parsed Response Body: $resbody");

      final List moodList = resbody['data']?['MoodTrackerData'] ?? [];

      debugPrint("📊 Mood List Length: ${moodList.length}");
      debugPrint("📊 Mood List Data: $moodList");

      // ✅ NO DATA → DEFAULT MOOD
      if (moodList.isEmpty) {
        selectedMood.value = 'All Good?';
        selectedMoodIndex.value = moods.indexOf('Good');

        debugPrint('🙂 No mood data → Default set to Good');
        return [];
      }

      // ✅ DATA EXISTS → TAKE LATEST ENTRY
      final latestMood = moodList.last['Mood'];

      debugPrint("🎯 Latest Mood Object: ${moodList.last}");
      debugPrint("🎯 Latest Mood Value: $latestMood");

      if (moods.contains(latestMood)) {
        selectedMood.value = latestMood;
        selectedMoodIndex.value = moods.indexOf(latestMood);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString('selectedMood', selectedMood.value);

        debugPrint('😄 Mood mapped from API → $latestMood');
      } else {
        debugPrint("⚠️ Mood not found in local list → fallback to Good");

        selectedMood.value = 'Good';
        selectedMoodIndex.value = moods.indexOf('Good');
      }
      final modelList = moodList.map((e) => MoodModel.fromJson(e)).toList();
      debugPrint("✅ Converted to MoodModel List: $modelList");
      return modelList;
    } catch (e, stackTrace) {
      debugPrint('❌ Exception while loading mood data: $e');
      debugPrint('❌ StackTrace: $stackTrace');

      // Fail-safe default
      selectedMood.value = 'Good';
      selectedMoodIndex.value = moods.indexOf('Good');
      return [];
    }
  }

  Future<void> storeMoodLocally(Map<String, String> moodMap) async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now().toIso8601String().split('T')[0];

    // unique key per day
    final key = "moods_$today";

    String? storedList = prefs.getString(key);

    List<Map<String, String>> tempList = [];

    if (storedList != null) {
      final decoded = jsonDecode(storedList) as List;
      tempList = decoded.map((e) => Map<String, String>.from(e)).toList();
    }

    tempList.add(moodMap);

    await prefs.setString(key, jsonEncode(tempList));

    debugPrint("💾 Stored for $today → $moodMap");
  }


  Future<void> loadTodayMoods() async {
    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now().toIso8601String().split('T')[0];
    final key = "moods_$today";

    String? storedList = prefs.getString(key);

    if (storedList != null) {
      final decoded = jsonDecode(storedList) as List;

      moodEntries.value =
          decoded.map((e) => Map<String, String>.from(e)).toList();
    } else {
      moodEntries.value = [];
    }
  }

  Future<bool> updateMood(
      {required BuildContext context, required String time}) async {
    if (selectedMoodIndex.value == -1) {
      debugPrint("⚠️ No mood selected");
      Get.snackbar('No Mood Selected', 'Please select your mood first');
      return false;
    }

    try {
      selectedMood.value = moods[selectedMoodIndex.value];

      debugPrint("🎯 Selected Mood Index: ${selectedMoodIndex.value}");
      debugPrint("🎯 Selected Mood Value: ${selectedMood.value}");

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('selectedMood', selectedMood.value);

      print("Time being sent to API: $time");

      final DateTime now = DateTime.now();
      final payload = {
        "Mood": moods[selectedMoodIndex.value],
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": time,
      };

      debugPrint("📤 API Payload: $payload");

      final response = await ApiService.post(
        logmood,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📥 Raw API Response: $response");

      if (response is http.Response) {
        debugPrint("📥 Status Code: ${response.statusCode}");
        debugPrint("📥 Response Body: ${response.body}");
      } else {
        debugPrint("📥 Decoded Response: $response");
      }

      if (response is http.Response && response.statusCode >= 400) {
        debugPrint("❌ API Error: ${response.statusCode}");

        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Mood record: ${response.statusCode}',
        );
        return false;
      } else {
        debugPrint("✅ Mood saved successfully");

        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Mood record saved successfully',
        );
        return true;
      }
    } catch (e, stackTrace) {
      debugPrint("❌ Exception: $e");
      debugPrint("❌ StackTrace: $stackTrace");

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while saving Mood record',
      );
      return false;
    }
  }
}
