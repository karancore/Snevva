import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/common/global_variables.dart';

import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../../models/music/music_response.dart';

class MentalWellnessController extends GetxController {
  RxBool isLoading = true.obs;
  RxBool hasError = false.obs;

  // ================== GENERAL MUSIC ==================
  final RxList<MusicItem> generalMusic = <MusicItem>[].obs;
  final RxList<MusicItem> selectedGeneralMusic = <MusicItem>[].obs;

  // ================== MEDITATION MUSIC ==================
  final RxList<MusicItem> meditationMusic = <MusicItem>[].obs;
  MusicItem? selectedMeditationMusic;

  // ================== NATURE MUSIC ==================
  final RxList<MusicItem> natureMusic = <MusicItem>[].obs;
  final RxList<MusicItem> selectedNatureMusics = <MusicItem>[].obs;

  // ================== FETCH ALL ==================
  Future<void> fetchMusic(BuildContext context) async {
    debugPrint("🎵 fetchMusic() called");

    isLoading.value = true;
    hasError.value = false;

    try {
      await loadGeneralMusic();
      await loadMeditationMusic();
      await loadNatureMusic();

      debugPrint("✅ fetchMusic() completed successfully");
    } catch (e) {
      hasError.value = true;
      debugPrint("❌ fetchMusic() error: $e");

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load music.',
      );
    } finally {
      isLoading.value = false;
      debugPrint("🔄 fetchMusic() loading stopped");
    }
  }

  // ================== GENERAL MUSIC ==================
  Future<MusicResponse?> loadGeneralMusic() async {
    debugPrint("🎶 Loading General Music...");

    try {
      final payload = {
        'Tags': ['General'],
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
        debugPrint("❌ HTTP error: ${response.statusCode}");
        return null;
      }

      final decoded = jsonDecode(jsonEncode(response));

      debugPrint("🔍 General Music Raw JSON: $decoded");

      // ✅ Parse once
      final musicResponse = MusicResponse.fromJson(decoded);

      debugPrint("🔍 Parsed type: ${musicResponse.runtimeType}");
      debugPrint("🔍 Total tracks: ${musicResponse.data?.length}");

      // ✅ Update controller state
      generalMusic.assignAll(musicResponse.data ?? []);

      final shuffled = List<MusicItem>.from(generalMusic)..shuffle();
      selectedGeneralMusic.assignAll(shuffled.take(2));

      debugPrint(
        "✅ Selected General Music: ${selectedGeneralMusic.map((e) => e.title).toList()}",
      );

      // ✅ Return MusicResponse (NOT decoded map)
      return musicResponse;
    } catch (e, s) {
      debugPrint("❌ loadGeneralMusic() error: $e");
      debugPrintStack(stackTrace: s);

      generalMusic.clear();
      selectedGeneralMusic.clear();
      return null;
    }
  }

  // ================== MEDITATION MUSIC ==================
  Future<MusicResponse?> loadMeditationMusic() async {
    debugPrint("🧘 Loading Meditation Music...");

    try {
      final payload = {
        'Tags': ['Meditation For You'],
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

      if (response is http.Response) return null;

      final decoded = jsonDecode(jsonEncode(response));
      debugPrint("🔍 Meditation Music Response: $decoded");
      final musicResponse = MusicResponse.fromJson(decoded);

      meditationMusic.assignAll(musicResponse.data ?? []);
      debugPrint("📥 Meditation Music Count: ${meditationMusic.length}");

      if (meditationMusic.isNotEmpty) {
        selectedMeditationMusic =
            meditationMusic[Random().nextInt(meditationMusic.length)];

        debugPrint(
          "✅ Selected Meditation Music: ${selectedMeditationMusic?.title}",
        );
      }
      return musicResponse;
    } catch (e) {
      debugPrint("❌ loadMeditationMusic() error: $e");
      meditationMusic.clear();
      selectedMeditationMusic = null;
      return null;
    }
  }

  // ================== NATURE MUSIC ==================
  Future<MusicResponse?> loadNatureMusic() async {
    debugPrint("🌿 Loading Nature Music...");

    try {
      final payload = {
        'Tags': ['Nature Sounds'],
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

      if (response is http.Response) return null;

      final decoded = jsonDecode(jsonEncode(response));
      debugPrint("🔍 Nature Music Response: $decoded");
      final musicResponse = MusicResponse.fromJson(decoded);

      natureMusic.assignAll(musicResponse.data ?? []);
      debugPrint("📥 Nature Music Count: ${natureMusic.length}");

      final shuffled = List<MusicItem>.from(natureMusic)..shuffle();
      selectedNatureMusics.assignAll(shuffled.take(4));

      debugPrint(
        "✅ Selected Nature Music: ${selectedNatureMusics.map((e) => e.title).toList()}",
      );
      return musicResponse;
    } catch (e) {
      debugPrint("❌ loadNatureMusic() error: $e");
      natureMusic.clear();
      selectedNatureMusics.clear();
      return null;
    }
  }
}
