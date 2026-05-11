import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
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

  // ── MethodChannel to trigger PeriodSyncWorker from Kotlin ───────────────
  static const _periodSyncChannel =
      MethodChannel('com.coretegra.snevvaa/period_sync');

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

  void onDateChanged(DateTime newDate) {
    int year = newDate.year;
    int month = newDate.month;
    int day = newDate.day;

    periodDay = day;
    periodMonth = month;
    periodYear = year;

    // 🔥 Update PeriodData values for calendar
    periodDataStartDay.value = day;
    periodDataStartMonth.value = month;
    periodDataStartYear.value = year;
    hasPeriodData.value = true;

    final formattedDate =
        "${day.toString().padLeft(2, '0')}/"
        "${month.toString().padLeft(2, '0')}/"
        "$year";

    periodLastPeriodDay.value = formattedDate;

    _calculateNextDates();
    saveWomenHealthToLocalStorage();
    final lastPeriodDate = DateTime(periodYear, periodMonth, periodDay);

    // ✅ Use the rolled-forward nextPeriodDay that _calculateNextDates already
    // computed, so the API prediction always matches what is shown in the UI.
    DateTime predictedDate;
    try {
      predictedDate = DateFormat("d MMM")
          .parse(nextPeriodDay.value)
          .copyWith(year: DateTime.now().year);
      // Handle year rollover (e.g. next period is in January next year)
      if (predictedDate.isBefore(DateTime.now())) {
        predictedDate = DateTime(
            predictedDate.year + 1, predictedDate.month, predictedDate.day);
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
  /// If the cycle had to roll forward (meaning a new cycle started since the
  /// last saved period date), we queue a background sync via [_enqueuePeriodSync]
  /// so the server is updated with the new cycle's start date and predicted date —
  /// without blocking the UI or requiring the user to do anything.
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

      // ✅ Roll forward until we find the NEXT upcoming period start.
      // Track whether we actually advanced (= new cycle started).
      bool cycleRolledForward = false;
      DateTime nextPeriod = cycleStart.add(Duration(days: cycleLength));
      while (nextPeriod.isBefore(today) || nextPeriod.isAtSameMomentAs(today)) {
        cycleStart = nextPeriod;
        nextPeriod = cycleStart.add(Duration(days: cycleLength));
        cycleRolledForward = true;
      }

      // Ovulation & fertile window are relative to the CURRENT cycle start
      final ovulationDay = cycleStart.add(Duration(days: cycleLength - 14));
      final fertilityStart = ovulationDay.subtract(const Duration(days: 5));

      final format = DateFormat("d MMM");

      nextPeriodDay.value = format.format(nextPeriod);
      nextOvulationDay.value = format.format(ovulationDay);
      nextFertilityDay.value = format.format(fertilityStart);
      dayLeftNextPeriod.value = nextPeriod.difference(today).inDays.toString();

      // 🔔 New cycle detected — queue background API sync with the new values.
      if (cycleRolledForward) {
        debugPrint(
          '🔄 New cycle detected — queueing background period sync. '
          'cycleStart=${format.format(cycleStart)}, nextPeriod=${format.format(nextPeriod)}',
        );
        _enqueuePeriodSync(
          startDate: cycleStart,
          predictedDate: nextPeriod,
        );
      }
    } catch (e) {
      debugPrint('❌ _calculateNextDates error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background period sync
  // ─────────────────────────────────────────────────────────────────────────

  /// Writes the pending payload to SharedPreferences and kicks off
  /// [PeriodSyncWorker] via MethodChannel. The worker handles network
  /// availability, retries, and auth — exactly like ApiSyncWorker.
  ///
  /// Safe to call from [_calculateNextDates] because it's fire-and-forget;
  /// any exception is caught so it never breaks the UI flow.
  Future<void> _enqueuePeriodSync({
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

      // 1. Persist payload so PeriodSyncWorker can read it even after a restart.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'pending_period_sync', // worker reads "flutter.pending_period_sync"
        jsonEncode(payload),
      );

      debugPrint('📝 Pending period sync written to prefs: $payload');

      // 2. Signal Kotlin to enqueue PeriodSyncWorker.
      //    If the Flutter engine is not the active one (e.g. background isolate),
      //    the MethodChannel call will fail silently — that's fine because
      //    BootReceiver / ConnectivityReceiver can also call PeriodSyncWorker.enqueue().
      await _periodSyncChannel.invokeMethod('enqueuePeriodSync');
      debugPrint('✅ PeriodSyncWorker enqueue triggered via MethodChannel');
    } catch (e) {
      // Non-fatal: the prefs payload is already written so the worker
      // will be picked up the next time enqueue() is called (boot, connectivity, etc.)
      debugPrint('⚠️ _enqueuePeriodSync channel error (non-fatal): $e');
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

      debugPrint('✅ Women Health Data saved successfully!');
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
        // _calculateNextDates will detect a new cycle and auto-queue sync if needed
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
            "${periodDataStartDay.value.toString().padLeft(2, '0')}/${periodDataStartMonth.value.toString().padLeft(2, '0')}/${periodDataStartYear.value}";

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

  Future<void> editperioddatatoAPI({
    required DateTime startDate,
    required DateTime predictedDate,
    required bool isMatched,
    required BuildContext context,
  }) async {
    try {
      final payload = {
        "StartDay": startDate.day,
        "StartMonth": startDate.month,
        "StartYear": startDate.year,
        "PredictedDay": predictedDate.day,
        "PredictedMonth": predictedDate.month,
        "PredictedYear": predictedDate.year,
        "IsMatched": isMatched,
      };

      final response = await ApiService.post(
        addperioddata,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to update period data',
        );
        return;
      }

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Period data updated successfully!',
      );
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Something went wrong',
      );
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
      Map<String, dynamic> payload = {
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
      Map<String, dynamic> payload = {
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
      debugPrint(" women health tips : $parsedData", wrapWidth: 1024);

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
      debugPrint("general tips : $womenHealthTips", wrapWidth: 1024);
    } catch (e) {
      if (!loadMore) {
        womenHealthTips.value = [];
      }
      debugPrint(e.toString());
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load women health tips',
      );
    } finally {
      if (loadMore) {
        isTipsLoadingMore.value = false;
      }
    }
  }
}