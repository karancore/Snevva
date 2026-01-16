import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/tips_response.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../../common/custom_snackbar.dart';

class WomenHealthController extends GetxController {
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
  dynamic randomTip;
  var periodDay = 0;
  var periodMonth = 0;
  var periodYear = 0;

  // 🔥 PeriodData from API (priority over WomenHealthData)
  var periodDataStartDay = 0.obs;
  var periodDataStartMonth = 0.obs;
  var periodDataStartYear = 0.obs;
  var hasPeriodData = false.obs;

  DateTime _selectedDate = DateTime.now();
  final DateTime _currentDate = DateTime.now();

  @override
  void onInit() {
    super.onInit();
    formattedDate();
    loadWomenHealthFromLocalStorage();
  }

  @override
  void onClose() {
    // Save data when controller is disposed
    saveWomenHealthToLocalStorage();
    super.onClose();
  }

  void formattedDate() {
    formattedCurrentDate.value = DateFormat('EEE dd MMM').format(_currentDate);
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

    final cycleLength = int.parse(periodCycleDays.value);
    final predictedDate = lastPeriodDate.add(Duration(days: cycleLength));

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
    saveWomenHealthToLocalStorage(); // Auto-save
  }

  void getPeriodCycleDays(String day) {
    periodCycleDays.value = day;
    _calculateNextDates();
    saveWomenHealthToLocalStorage(); // Auto-save
  }

  void _calculateNextDates() {
    if (periodLastPeriodDay.value.isEmpty ||
        periodCycleDays.value.isEmpty ||
        periodDays.value.isEmpty) {
      return;
    }

    try {
      final lastPeriodDate = DateFormat(
        "dd/MM/yyyy",
      ).parse(periodLastPeriodDay.value);
      final cycleLength = int.tryParse(periodCycleDays.value) ?? 28;

      final nextPeriod = lastPeriodDate.add(Duration(days: cycleLength));
      final ovulationDay = nextPeriod.subtract(const Duration(days: 14));
      final fertilityStart = ovulationDay.subtract(const Duration(days: 5));

      final format = DateFormat("d MMM");

      nextPeriodDay.value = format.format(nextPeriod);
      nextOvulationDay.value = format.format(ovulationDay);
      nextFertilityDay.value = format.format(fertilityStart);
      dayLeftNextPeriod.value =
          _currentDate.difference(nextPeriod).inDays.abs().toString();
    } catch (e) {
      // parsing failed
    }
  }

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

      // 🔥 NEW - Save PeriodData if available
      await prefs.setBool('is_first_time_women', isFirstTimeWomen.value);
      await prefs.setBool('hasPeriodData', hasPeriodData.value);
      await prefs.setInt('periodDataStartDay', periodDataStartDay.value);
      await prefs.setInt('periodDataStartMonth', periodDataStartMonth.value);
      await prefs.setInt('periodDataStartYear', periodDataStartYear.value);

      print('✅ Women Health Data saved successfully!');
    } catch (e) {
      print('❌ Error saving Women Health Data: $e');
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

      // 🔥 NEW - Load PeriodData if available
      isFirstTimeWomen.value = prefs.getBool('is_first_time_women') ?? true;
      hasPeriodData.value = prefs.getBool('hasPeriodData') ?? false;
      periodDataStartDay.value = prefs.getInt('periodDataStartDay') ?? 0;
      periodDataStartMonth.value = prefs.getInt('periodDataStartMonth') ?? 0;
      periodDataStartYear.value = prefs.getInt('periodDataStartYear') ?? 0;

      if (periodLastPeriodDay.value.isNotEmpty) {
        final date = DateFormat("dd/MM/yyyy").parse(periodLastPeriodDay.value);
        periodDay = date.day;
        periodMonth = date.month;
        periodYear = date.year;
        _calculateNextDates();
      }

      print('🟢 isFirstTimeWomen = ${isFirstTimeWomen.value}');
      print('🟢 hasPeriodData = ${hasPeriodData.value}');
    } catch (e) {
      print('❌ Error loading Women Health Data: $e');
    }
  }

  // Future<void> loaddatafromAPI() async {
  //   try {
  //     final response = await ApiService.post(
  //       fetchWomenhealthHistory,
  //       null,
  //       withAuth: true,
  //       encryptionRequired: true,
  //     );
  //     if (response is http.Response) {
  //       CustomSnackbar.showError(
  //         context: Get.context!,
  //         title: 'Error',
  //         message: 'Failed to save Women Health Data: ${response.statusCode}',
  //       );
  //       return;
  //     }
  //     final parsedData = jsonDecode(jsonEncode(response));
  //     print("women health data from api : $parsedData");
  //     final data = parsedData['data'];
  //     final womenHealthData = data['WomenHealthData'];
  //     print("women health data extracted : $womenHealthData");
  //     if (womenHealthData != null) {
  //       isFirstTimeWomen.value = false;
  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.setBool('is_first_time_women', false);
  //       String periodDaysFromAPI =
  //           womenHealthData['PeroidsDuration']?.toString() ?? '5';
  //       String periodCycleDaysFromAPI =
  //           womenHealthData['PeroidsCycleCount']?.toString() ?? '28';
  //       int periodDayFromAPI = womenHealthData['PeriodDay'] ?? 1;
  //       int periodMonthFromAPI = womenHealthData['PeriodMonth'] ?? 12;
  //       int periodYearFromAPI = womenHealthData['PeriodYear'] ?? 2025;
  //       periodDays.value = periodDaysFromAPI;
  //       periodCycleDays.value = periodCycleDaysFromAPI;
  //       periodLastPeriodDay.value =
  //           "$periodDayFromAPI/${periodMonthFromAPI.toString().padLeft(2, '0')}/$periodYearFromAPI";
  //       _calculateNextDates();
  //       await saveWomenHealthToLocalStorage();
  //     } else {
  //       isFirstTimeWomen.value = true;
  //     }
  //     print("✅ Women Health Data loaded successfully: $response");
  //   } catch (e) {
  //     print(e);
  //     CustomSnackbar.showError(
  //       context: Get.context!,
  //       title: 'Error',
  //       message: 'Failed loading Women Health Data',
  //     );
  //   }
  // }

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

      // ✅ User is not first-time if any data exists
      if (womenHealth != null || periodData != null) {
        isFirstTimeWomen.value = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_first_time_women', false);
      }

      // 🔹 1. Load women health settings
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

      // 🔹 2. Use PeriodData as priority for next period & calendar
      if (periodData != null) {
        // 🔥 Store PeriodData start date for calendar
        periodDataStartDay.value = periodData['StartDay'] ?? 1;
        periodDataStartMonth.value = periodData['StartMonth'] ?? 1;
        periodDataStartYear.value =
            periodData['StartYear'] ?? DateTime.now().year;
        hasPeriodData.value = true;

        final DateTime predictedDate = DateTime(
          periodData['PredictedYear'],
          periodData['PredictedMonth'],
          periodData['PredictedDay'],
        );

        final DateFormat format = DateFormat("d MMM");
        nextPeriodDay.value = format.format(predictedDate);

        // Optional derived values
        final ovulationDay = predictedDate.subtract(const Duration(days: 14));
        final fertilityStart = ovulationDay.subtract(const Duration(days: 5));

        nextOvulationDay.value = format.format(ovulationDay);
        nextFertilityDay.value = format.format(fertilityStart);

        dayLeftNextPeriod.value =
            DateTime.now().difference(predictedDate).inDays.abs().toString();

        // 🚫 Skip _calculateNextDates() because PeriodData is accurate
        await saveWomenHealthToLocalStorage();
        return;
      }

      // 🔹 3. Fallback: Calculate next dates from WomenHealthData if no PeriodData
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

      print("✅ Women Health Data saved successfully: $response");
    } catch (e) {
      print(e);
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving Women Health Data',
      );
    }
  }

  Future<void> getWomenHealthQuotes(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["Female", "Women Health", "Pre-Period Nudges"],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
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
      womenHealthTips.value = list.map((e) => TipData.fromJson(e)).toList();
      debugPrint("general tips : $womenHealthTips", wrapWidth: 1024);
    } catch (e) {
      womenHealthTips.value = [];
      print(e);
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load women health tips',
      );
    }
    return null;
  }
}
