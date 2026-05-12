import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/tips_response.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';

class WomenHealthController extends GetxService {
  static const int _pageSize = 8;

  var periodDays = "5".obs;
  var periodCycleDays = "28".obs;
  var periodLastPeriodDay = "".obs;
  RxString nextPeriodDay = "Enter data".obs;
  RxString nextFertilityDay = "".obs;
  RxString nextOvulationDay = "".obs;
  var dayLeftNextPeriod = "".obs;
  var formattedCurrentDate = "".obs;
  RxBool isFirstTimeWomen = true.obs;
  Timer? _apiDebounce;

  var womenHealthTips = <TipData>[].obs;
  var isTipsLoadingMore = false.obs;
  var hasMoreTipsData = true.obs;
  int tipsPageIndex = 1;
  final ScrollController tipsScrollController = ScrollController();
  dynamic randomTip;
  var periodDay = 0;
  var periodMonth = 0;
  var periodYear = 0;

  // 🔥 PeriodData from API (priority over WomenHealthData)
  var periodDataStartDay = 0.obs;
  var periodDataStartMonth = 0.obs;
  var periodDataStartYear = 0.obs;
  var hasPeriodData = false.obs;

  @override
  void onInit() {
    super.onInit();
    tipsScrollController.addListener(_onTipsScroll);
  }

  @override
  void onReady() {
    super.onReady();
    formattedDate();
    loadWomenHealthFromLocalStorage();
    _flushPendingSyncOnAppOpen();
  }

  @override
  void onClose() {
    _apiDebounce?.cancel();
    tipsScrollController.removeListener(_onTipsScroll);
    tipsScrollController.dispose();
    saveWomenHealthToLocalStorage();
    super.onClose();
  }

  void _onTipsScroll() {
    if (!tipsScrollController.hasClients) return;
    final position = tipsScrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      if (Get.context != null) {
        getWomenHealthQuotes(Get.context!, loadMore: true);
      }
    }
  }

  void formattedDate() {
    formattedCurrentDate.value = DateFormat('EEE dd MMM').format(DateTime.now());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Date / cycle logic
  // ─────────────────────────────────────────────────────────────────────────

  void onDateChanged(DateTime newDate) {
    periodDay = newDate.day;
    periodMonth = newDate.month;
    periodYear = newDate.year;

    // Update PeriodData values for calendar
    periodDataStartDay.value = newDate.day;
    periodDataStartMonth.value = newDate.month;
    periodDataStartYear.value = newDate.year;
    hasPeriodData.value = true;

    periodLastPeriodDay.value =
        "${newDate.day.toString().padLeft(2, '0')}/"
        "${newDate.month.toString().padLeft(2, '0')}/"
        "${newDate.year}";

    _calculateNextDates();
    saveWomenHealthToLocalStorage();

    final lastPeriodDate = DateTime(periodYear, periodMonth, periodDay);

    // Use the rolled-forward nextPeriodDay that _calculateNextDates already
    // computed, so the API prediction always matches what is shown in the UI.
    DateTime predictedDate;
    try {
      predictedDate = DateFormat("d MMM")
          .parse(nextPeriodDay.value)
          .copyWith(year: DateTime.now().year);
      // Handle year rollover (e.g. next period is in January next year)
      if (predictedDate.isBefore(DateTime.now())) {
        predictedDate = DateTime(
          predictedDate.year + 1,
          predictedDate.month,
          predictedDate.day,
        );
      }
    } catch (_) {
      // Fallback: single-cycle addition if parse fails
      final cycleLength = int.parse(periodCycleDays.value);
      predictedDate = lastPeriodDate.add(Duration(days: cycleLength));
    }

    _apiDebounce?.cancel();
    _apiDebounce = Timer(const Duration(seconds: 1), () {
      editperioddatatoAPI(
        startDate: lastPeriodDate,
        predictedDate: predictedDate,
        isMatched: false,
        context: Get.context!,
      );
    });
  }

  void getPeriodDays(String day) {
    periodDays.value = day;
    _calculateNextDates();
    saveWomenHealthToLocalStorage();
  }

  void getPeriodCycleDays(String day) {
    periodCycleDays.value = day;
    _calculateNextDates();
    saveWomenHealthToLocalStorage();
  }

  /// Calculates next period / ovulation / fertility dates.
  ///
  /// If the stored last-period date is old enough that we've already passed
  /// one or more cycle boundaries, rolls forward to the current cycle and
  /// writes a pending sync so the server gets the new start date on next
  /// app open (or immediately if network is available).
  void _calculateNextDates() {
    if (periodLastPeriodDay.value.isEmpty ||
        periodCycleDays.value.isEmpty ||
        periodDays.value.isEmpty) {
      return;
    }

    try {
      DateTime cycleStart =
          DateFormat("dd/MM/yyyy").parse(periodLastPeriodDay.value);
      final cycleLength = int.tryParse(periodCycleDays.value) ?? 28;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Roll forward until we find the NEXT upcoming period start.
      bool cycleRolledForward = false;
      DateTime nextPeriod = cycleStart.add(Duration(days: cycleLength));
      while (
          nextPeriod.isBefore(today) || nextPeriod.isAtSameMomentAs(today)) {
        cycleStart = nextPeriod;
        nextPeriod = cycleStart.add(Duration(days: cycleLength));
        cycleRolledForward = true;
      }

      // Ovulation & fertile window are relative to the CURRENT cycle start.
      final ovulationDay = cycleStart.add(Duration(days: cycleLength - 14));
      final fertilityStart = ovulationDay.subtract(const Duration(days: 5));

      final format = DateFormat("d MMM");
      nextPeriodDay.value = format.format(nextPeriod);
      nextOvulationDay.value = format.format(ovulationDay);
      nextFertilityDay.value = format.format(fertilityStart);
      dayLeftNextPeriod.value = nextPeriod.difference(today).inDays.toString();

      // New cycle detected — write pending sync so _flushPendingSyncOnAppOpen
      // (or the next editperioddatatoAPI call) pushes the new data to the server.
      if (cycleRolledForward) {
        debugPrint(
          '🔄 New cycle detected — writing pending sync. '
          'cycleStart=${format.format(cycleStart)}, nextPeriod=${format.format(nextPeriod)}',
        );
        _writePendingSync(startDate: cycleStart, predictedDate: nextPeriod);
      }
    } catch (e) {
      debugPrint('❌ _calculateNextDates error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pending sync helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Writes the period payload to SharedPreferences only.
  /// No Kotlin worker is involved — the flush happens on the next app open
  /// via [_flushPendingSyncOnAppOpen], or immediately inside
  /// [editperioddatatoAPI] when the user manually sets a date.
  Future<void> _writePendingSync({
    required DateTime startDate,
    required DateTime predictedDate,
  }) async {
    try {
      final payload = {
        'StartDay': startDate.day,
        'StartMonth': startDate.month,
        'StartYear': startDate.year,
        'PredictedDay': predictedDate.day,
        'PredictedMonth': predictedDate.month,
        'PredictedYear': predictedDate.year,
        'IsMatched': false,
      };
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_period_sync', jsonEncode(payload));
      debugPrint('📝 pending_period_sync written: $payload');
    } catch (e) {
      debugPrint('⚠️ _writePendingSync error (non-fatal): $e');
    }
  }

  /// Called on every app open via [onReady].
  ///
  /// If a previous [editperioddatatoAPI] call failed (network down, app
  /// killed mid-request) or a new cycle was auto-detected while offline,
  /// this flushes the stored payload to the server before the user
  /// interacts with anything.
  Future<void> _flushPendingSyncOnAppOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getString('pending_period_sync');
      if (pending == null) {
        debugPrint('🔍 No pending period sync to flush');
        return;
      }

      debugPrint('🔄 Found pending period sync on app open — flushing...');
      final payload = jsonDecode(pending) as Map<String, dynamic>;

      final response = await ApiService.post(
        addperioddata,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is! http.Response) {
        await prefs.remove('pending_period_sync');
        debugPrint('✅ Pending period sync flushed on app open');
      } else {
        debugPrint(
          '⚠️ Flush attempt failed (${response.statusCode}) — will retry next open',
        );
      }
    } catch (e) {
      // Non-fatal — key stays in prefs, will retry next app open
      debugPrint('⚠️ _flushPendingSyncOnAppOpen error (non-fatal): $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Persistence
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> saveWomenHealthToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('periodDays', periodDays.value);
      await prefs.setString('periodCycleDays', periodCycleDays.value);
      await prefs.setString('periodLastPeriodDay', periodLastPeriodDay.value);
      await prefs.setString('nextPeriodDay', nextPeriodDay.value);
      await prefs.setString('nextFertilityDay', nextFertilityDay.value);
      await prefs.setString('nextOvulationDay', nextOvulationDay.value);
      await prefs.setString('dayLeftNextPeriod', dayLeftNextPeriod.value);

      await prefs.setBool('is_first_time_women', isFirstTimeWomen.value);
      await prefs.setBool('hasPeriodData', hasPeriodData.value);
      await prefs.setInt('periodDataStartDay', periodDataStartDay.value);
      await prefs.setInt('periodDataStartMonth', periodDataStartMonth.value);
      await prefs.setInt('periodDataStartYear', periodDataStartYear.value);

      debugPrint('✅ Women Health Data saved to local storage');
    } catch (e) {
      debugPrint('❌ Error saving Women Health Data: $e');
    }
  }

  Future<void> loadWomenHealthFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      periodDays.value = prefs.getString('periodDays') ?? '5';
      periodCycleDays.value = prefs.getString('periodCycleDays') ?? '28';
      periodLastPeriodDay.value = prefs.getString('periodLastPeriodDay') ?? '';
      nextPeriodDay.value = prefs.getString('nextPeriodDay') ?? 'Enter data';
      nextFertilityDay.value = prefs.getString('nextFertilityDay') ?? '';
      nextOvulationDay.value = prefs.getString('nextOvulationDay') ?? '';
      dayLeftNextPeriod.value = prefs.getString('dayLeftNextPeriod') ?? '0';

      isFirstTimeWomen.value = prefs.getBool('is_first_time_women') ?? true;
      hasPeriodData.value = prefs.getBool('hasPeriodData') ?? false;
      periodDataStartDay.value = prefs.getInt('periodDataStartDay') ?? 0;
      periodDataStartMonth.value = prefs.getInt('periodDataStartMonth') ?? 0;
      periodDataStartYear.value = prefs.getInt('periodDataStartYear') ?? 0;

      if (periodLastPeriodDay.value.isNotEmpty) {
        final date =
            DateFormat("dd/MM/yyyy").parse(periodLastPeriodDay.value);
        periodDay = date.day;
        periodMonth = date.month;
        periodYear = date.year;
        // Will auto-write pending sync if a new cycle is detected
        _calculateNextDates();
      }

      debugPrint('🟢 isFirstTimeWomen = ${isFirstTimeWomen.value}');
      debugPrint('🟢 hasPeriodData = ${hasPeriodData.value}');
    } catch (e) {
      debugPrint('❌ Error loading Women Health Data: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // API calls
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> lastPeriodDatafromAPI() async {
    try {
      final response = await ApiService.post(
        lastPeriodData,
        null,
        withAuth: true,
        encryptionRequired: true,
      );

      final parsedData = jsonDecode(jsonEncode(response));
      debugPrint("Parsed last period data: $parsedData");

      final data = parsedData['data'];
      final womenHealth = data?['WomenHealthData'];
      final periodData = data?['PeriodData'];

      if (womenHealth != null || periodData != null) {
        isFirstTimeWomen.value = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_first_time_women', false);
      }

      if (womenHealth != null) {
        periodDays.value = womenHealth['PeroidsDuration']?.toString() ?? '5';
        periodCycleDays.value =
            womenHealth['PeroidsCycleCount']?.toString() ?? '28';

        final int startDay = womenHealth['PeriodDay'] ?? 1;
        final int startMonth = womenHealth['PeriodMonth'] ?? 1;
        final int startYear = womenHealth['PeriodYear'] ?? DateTime.now().year;

        periodLastPeriodDay.value =
            "$startDay/${startMonth.toString().padLeft(2, '0')}/$startYear";
      }

      if (periodData != null) {
        periodDataStartDay.value = periodData['StartDay'] ?? 1;
        periodDataStartMonth.value = periodData['StartMonth'] ?? 1;
        periodDataStartYear.value =
            periodData['StartYear'] ?? DateTime.now().year;
        hasPeriodData.value = true;

        periodLastPeriodDay.value =
            "${periodDataStartDay.value.toString().padLeft(2, '0')}/"
            "${periodDataStartMonth.value.toString().padLeft(2, '0')}/"
            "${periodDataStartYear.value}";

        _calculateNextDates();
        await saveWomenHealthToLocalStorage();
        return;
      }

      if (womenHealth != null) {
        _calculateNextDates();
        await saveWomenHealthToLocalStorage();
      }
    } catch (e) {
      debugPrint("❌ Error fetching period data: $e");
    }
  }

  /// Local-first period sync.
  ///
  /// 1. Writes the payload to SharedPreferences BEFORE touching the network.
  /// 2. Attempts a direct API call.
  /// 3. Clears the pending key on success; leaves it on failure so
  ///    [_flushPendingSyncOnAppOpen] retries it on next launch.
  Future<void> editperioddatatoAPI({
    required DateTime startDate,
    required DateTime predictedDate,
    required bool isMatched,
    required BuildContext context,
  }) async {
    final payload = {
      "StartDay": startDate.day,
      "StartMonth": startDate.month,
      "StartYear": startDate.year,
      "PredictedDay": predictedDate.day,
      "PredictedMonth": predictedDate.month,
      "PredictedYear": predictedDate.year,
      "IsMatched": isMatched,
    };

    // ── 1. Persist locally first — never loses the data even if app dies.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_period_sync', jsonEncode(payload));
    debugPrint('📝 pending_period_sync written before API call');

    // ── 2. Attempt direct API call.
    try {
      final response = await ApiService.post(
        addperioddata,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        // Server error — keep pending key, flush on next open
        debugPrint(
          '⚠️ editperioddatatoAPI failed (${response.statusCode}) — pending key kept for retry',
        );
        return;
      }

      // ── 3. Success — clear pending key so next app open skips the flush.
      await prefs.remove('pending_period_sync');
      debugPrint('✅ Period data synced & pending key cleared');

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Period data updated successfully!',
      );
    } catch (e) {
      // Network down / timeout — pending key stays, retried on next open
      debugPrint('⚠️ editperioddatatoAPI exception (non-fatal, will retry): $e');
    }
  }

  Future<void> saveWomenHealthDatatoAPI(
    int periodDays,
    int periodCycleDays,
    int periodDay,
    int periodMonth,
    int periodYear,
    BuildContext context,
  ) async {
    try {
      final payload = {
        'PeroidsDuration': periodDays,
        'PeroidsCycleCount': periodCycleDays,
        'PeriodDay': periodDay,
        'PeriodMonth': periodMonth,
        'PeriodYear': periodYear,
        'Disorder': null,
      };

      final response = await ApiService.post(
        womenhealth,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Women Health Data: ${response.statusCode}',
        );
        return;
      }

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Women Health Data saved successfully!',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_time_women', false);
      isFirstTimeWomen.value = false;

      debugPrint("✅ Women Health Data saved successfully: $response");
    } catch (e) {
      debugPrint(e.toString());
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving Women Health Data',
      );
    }
  }

  Future<void> getWomenHealthQuotes(
    BuildContext context, {
    bool loadMore = false,
  }) async {
    if (loadMore && (isTipsLoadingMore.value || !hasMoreTipsData.value)) {
      return;
    }

    final targetPage = loadMore ? tipsPageIndex + 1 : 1;
    if (loadMore) {
      isTipsLoadingMore.value = true;
    } else {
      tipsPageIndex = 1;
      hasMoreTipsData.value = true;
      womenHealthTips.clear();
    }

    try {
      final payload = {
        'Tags': ["Female", "Women Health", "Pre-Period Nudges"],
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
      };

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );
      debugPrint("women health tips : $response", wrapWidth: 1024);

      final parsedData = jsonDecode(jsonEncode(response));
      final List list = parsedData['data'] ?? [];
      final fetchedTips = list.map((e) => TipData.fromJson(e)).toList();

      if (fetchedTips.isEmpty) {
        hasMoreTipsData.value = false;
        return;
      }

      tipsPageIndex = targetPage;
      if (loadMore) {
        womenHealthTips.addAll(fetchedTips);
      } else {
        womenHealthTips.assignAll(fetchedTips);
      }
      hasMoreTipsData.value = fetchedTips.length == _pageSize;
    } catch (e) {
      if (!loadMore) womenHealthTips.value = [];
      debugPrint(e.toString());
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load women health tips',
      );
    } finally {
      if (loadMore) isTipsLoadingMore.value = false;
    }
  }
}