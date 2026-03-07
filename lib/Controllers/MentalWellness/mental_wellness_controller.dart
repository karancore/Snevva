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
  static const int _pageSize = 8;

  RxBool isLoading = true.obs;
  RxBool hasError = false.obs;
  Future<void>? _inFlightFetch;

  final RxList<Map<String, String>> generalUrls = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> natureUrls = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> meditationUrls =
      <Map<String, String>>[].obs;

  // ================== GENERAL MUSIC ==================
  final RxList<MusicItem> generalMusic = <MusicItem>[].obs;
  final RxList<MusicItem> selectedGeneralMusic = <MusicItem>[].obs;
  final ScrollController generalScrollController = ScrollController();
  final RxBool isGeneralLoadingMore = false.obs;
  final RxBool hasMoreGeneralData = true.obs;
  int generalPageIndex = 1;

  // ================== MEDITATION MUSIC ==================
  final RxList<MusicItem> meditationMusic = <MusicItem>[].obs;
  MusicItem? selectedMeditationMusic;
  final ScrollController meditationScrollController = ScrollController();
  final RxBool isMeditationLoadingMore = false.obs;
  final RxBool hasMoreMeditationData = true.obs;
  int meditationPageIndex = 1;

  // ================== CDN URL LIST ==================
  final RxList<String> allCdnUrls = <String>[].obs;
  final RxList<String> shuffledCdnUrls = <String>[].obs;

  // ================== NATURE MUSIC ==================
  final RxList<MusicItem> natureMusic = <MusicItem>[].obs;
  final RxList<MusicItem> selectedNatureMusics = <MusicItem>[].obs;
  final ScrollController natureScrollController = ScrollController();
  final RxBool isNatureLoadingMore = false.obs;
  final RxBool hasMoreNatureData = true.obs;
  int naturePageIndex = 1;

  bool get hasCachedMusic =>
      generalMusic.isNotEmpty &&
      meditationMusic.isNotEmpty &&
      natureMusic.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    generalScrollController.addListener(_onGeneralScroll);
    meditationScrollController.addListener(_onMeditationScroll);
    natureScrollController.addListener(_onNatureScroll);

    debugPrint("🟢 MentalWellnessController initialized");
  }

  void _onGeneralScroll() {
    if (!generalScrollController.hasClients) return;
    final position = generalScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadGeneralMusic(loadMore: true);
    }
  }

  void _onMeditationScroll() {
    if (!meditationScrollController.hasClients) return;
    final position = meditationScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadMeditationMusic(loadMore: true);
    }
  }

  void _onNatureScroll() {
    if (!natureScrollController.hasClients) return;
    final position = natureScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      loadNatureMusic(loadMore: true);
    }
  }

  // ================== FETCH ALL ==================
  Future<void> fetchMusic(BuildContext context, {bool forceRefresh = false}) {
    if (!forceRefresh && hasCachedMusic) {
      isLoading.value = false;
      hasError.value = false;
      return Future<void>.value();
    }

    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }

    _inFlightFetch = _fetchMusicInternal(context);
    return _inFlightFetch!.whenComplete(() {
      _inFlightFetch = null;
    });
  }

  Future<void> _fetchMusicInternal(BuildContext context) async {
    debugPrint("🎵 fetchMusic() called");

    isLoading.value = true;
    hasError.value = false;

    try {
      await Future.wait([
        loadGeneralMusic(),
        loadMeditationMusic(),
        loadNatureMusic(),
      ]);

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
  Future<MusicResponse?> loadGeneralMusic({bool loadMore = false}) async {
    debugPrint("🎶 Loading General Music...");
    if (loadMore && (isGeneralLoadingMore.value || !hasMoreGeneralData.value)) {
      return null;
    }

    final targetPage = loadMore ? generalPageIndex + 1 : 1;
    if (loadMore) {
      isGeneralLoadingMore.value = true;
    } else {
      generalPageIndex = 1;
      hasMoreGeneralData.value = true;
      generalMusic.clear();
      generalUrls.clear();
      selectedGeneralMusic.clear();
    }

    try {
      final payload = {
        'Tags': ['General'],
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
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
      final fetchedItems = musicResponse.data;
      if (fetchedItems.isEmpty) {
        hasMoreGeneralData.value = false;
        return musicResponse;
      }
      generalPageIndex = targetPage;
      if (loadMore) {
        generalMusic.addAll(fetchedItems);
      } else {
        generalMusic.assignAll(fetchedItems);
      }

      debugPrint("🔍 Parsed type: ${musicResponse.runtimeType}");
      debugPrint("🔍 Total tracks: ${generalMusic.length}");
      logLong(
        "🔍 General track list:",
        generalMusic.map((e) => e.toString()).join('\n'),
      );
      debugPrint(
        "✅ Selected General Music: ${selectedNatureMusics.map((e) => e.media.cdnUrl).toList()}",
      );
      generalUrls.assignAll(
        generalMusic
            .map(
              (e) => {
                "title": e.title,
                "cdnUrl": e.media.cdnUrl,
                "thumbnailUrl": _normalizeUrl(e.thumbnailMedia),
              },
            )
            .toList(),
      );

      print("General music urls ${generalUrls.length}");
      print("General music first ${generalUrls.first}");

      extractAndShuffleCdnUrls(generalMusic, take: 2);

      final shuffled = List<MusicItem>.from(generalMusic)..shuffle();
      selectedGeneralMusic.assignAll(shuffled.take(2));
      hasMoreGeneralData.value = fetchedItems.length == _pageSize;

      debugPrint(
        "✅ Selected General Music: ${selectedGeneralMusic.map((e) => e.title).toList()}",
      );

      // ✅ Return MusicResponse (NOT decoded map)
      return musicResponse;
    } catch (e, s) {
      debugPrint("❌ loadGeneralMusic() error: $e");
      debugPrintStack(stackTrace: s);
      if (!loadMore) {
        generalMusic.clear();
        selectedGeneralMusic.clear();
      }
      return null;
    } finally {
      if (loadMore) {
        isGeneralLoadingMore.value = false;
      }
    }
  }

  // ================== MEDITATION MUSIC ==================
  Future<MusicResponse?> loadMeditationMusic({bool loadMore = false}) async {
    debugPrint("🧘 Loading Meditation Music...");
    if (loadMore &&
        (isMeditationLoadingMore.value || !hasMoreMeditationData.value)) {
      return null;
    }

    final targetPage = loadMore ? meditationPageIndex + 1 : 1;
    if (loadMore) {
      isMeditationLoadingMore.value = true;
    } else {
      meditationPageIndex = 1;
      hasMoreMeditationData.value = true;
      meditationMusic.clear();
      meditationUrls.clear();
      selectedMeditationMusic = null;
    }

    try {
      final payload = {
        'Tags': ['Meditation For You'],
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
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
      final fetchedItems = musicResponse.data;
      if (fetchedItems.isEmpty) {
        hasMoreMeditationData.value = false;
        return musicResponse;
      }
      meditationPageIndex = targetPage;
      if (loadMore) {
        meditationMusic.addAll(fetchedItems);
      } else {
        meditationMusic.assignAll(fetchedItems);
      }

      meditationUrls.assignAll(
        meditationMusic
            .map(
              (e) => {
                "title": e.media.title,
                "cdnUrl": e.media.cdnUrl,
                "thumbnailUrl": _normalizeUrl(e.thumbnailMedia),
              },
            )
            .toList(),
      );
      print("Meditation music urls ${meditationUrls.length}");

      debugPrint("📥 Meditation Music Count: ${meditationMusic.length}");

      debugPrint(
        "✅ Selected Meditation Music: ${selectedNatureMusics.map((e) => e.media.cdnUrl).toList()}",
      );
      extractAndShuffleCdnUrls(meditationMusic, take: 1);

      if (meditationMusic.isNotEmpty) {
        selectedMeditationMusic =
            meditationMusic[Random().nextInt(meditationMusic.length)];

        debugPrint(
          "✅ Selected Meditation Music: ${selectedMeditationMusic?.title}",
        );
      }
      hasMoreMeditationData.value = fetchedItems.length == _pageSize;
      return musicResponse;
    } catch (e) {
      debugPrint("❌ loadMeditationMusic() error: $e");
      if (!loadMore) {
        meditationMusic.clear();
        selectedMeditationMusic = null;
      }
      return null;
    } finally {
      if (loadMore) {
        isMeditationLoadingMore.value = false;
      }
    }
  }

  // ================== NATURE MUSIC ==================
  Future<MusicResponse?> loadNatureMusic({bool loadMore = false}) async {
    debugPrint("🌿 Loading Nature Music...");
    if (loadMore && (isNatureLoadingMore.value || !hasMoreNatureData.value)) {
      return null;
    }

    final targetPage = loadMore ? naturePageIndex + 1 : 1;
    if (loadMore) {
      isNatureLoadingMore.value = true;
    } else {
      naturePageIndex = 1;
      hasMoreNatureData.value = true;
      natureMusic.clear();
      natureUrls.clear();
      selectedNatureMusics.clear();
    }

    try {
      final payload = {
        'Tags': ['Nature Sounds'],
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
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
      final fetchedItems = musicResponse.data;
      if (fetchedItems.isEmpty) {
        hasMoreNatureData.value = false;
        return musicResponse;
      }
      naturePageIndex = targetPage;
      if (loadMore) {
        natureMusic.addAll(fetchedItems);
      } else {
        natureMusic.assignAll(fetchedItems);
      }

      natureUrls.assignAll(
        natureMusic
            .map(
              (e) => {
                "title": e.title,
                "cdnUrl": e.media.cdnUrl,
                "thumbnailUrl": _normalizeUrl(e.thumbnailMedia),
              },
            )
            .toList(),
      );
      print("Nature music urls ${natureUrls.length}");

      extractAndShuffleCdnUrls(natureMusic, take: 4);
      debugPrint("📥 Nature Music Count: ${natureMusic.length}");

      final shuffled = List<MusicItem>.from(natureMusic)..shuffle();
      selectedNatureMusics.assignAll(shuffled.take(4));

      // debugPrint(
      //   "✅ Selected Nature Music: ${selectedNatureMusics.map((e) => e.media.cdnUrl).toList()}",
      // );
      debugPrint("✅ Selected Nature Music: $natureUrls");
      hasMoreNatureData.value = fetchedItems.length == _pageSize;
      return musicResponse;
    } catch (e) {
      debugPrint("❌ loadNatureMusic() error: $e");
      if (!loadMore) {
        natureMusic.clear();
        selectedNatureMusics.clear();
      }
      return null;
    } finally {
      if (loadMore) {
        isNatureLoadingMore.value = false;
      }
    }
  }

  void extractAndShuffleCdnUrls(List<MusicItem> musicList, {int? take}) {
    // 1. Extract CDN URLs
    final urls =
        musicList
            .map((e) => e.media.cdnUrl)
            .where((url) => url.isNotEmpty)
            .toList();

    // 2. Shuffle
    urls.shuffle(Random());

    // 3. Store
    allCdnUrls.assignAll(urls);

    if (take != null) {
      shuffledCdnUrls.assignAll(urls.take(take));
    } else {
      shuffledCdnUrls.assignAll(urls);
    }

    debugPrint("🎧 CDN URLs (${shuffledCdnUrls.length}): $shuffledCdnUrls");
  }

  String _normalizeUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    return url.startsWith('http') ? url : 'https://$url';
  }

  @override
  void onClose() {
    generalScrollController.removeListener(_onGeneralScroll);
    meditationScrollController.removeListener(_onMeditationScroll);
    natureScrollController.removeListener(_onNatureScroll);
    generalScrollController.dispose();
    meditationScrollController.dispose();
    natureScrollController.dispose();
    super.onClose();
  }
}
