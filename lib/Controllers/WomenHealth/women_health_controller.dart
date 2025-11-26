import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

class WomenHealthController extends GetxController {
  var periodDays = "5".obs;
  var periodCycleDays = "28".obs;
  var periodLastPeriodDay = "".obs;
  var nextPeriodDay = "".obs;
  var nextFertilityDay = "".obs;
  var nextOvulationDay = "".obs;
  var dayLeftNextPeriod = "".obs;
  var formattedCurrentDate = "".obs;

  var periodDay = 0;
  var periodMonth = 0;
  var periodYear = 0;

  DateTime _selectedDate = DateTime.now();
  final DateTime _currentDate = DateTime.now();

  @override
  void onInit() {
    super.onInit();
    formattedDate();
  }

  void formattedDate() {
    formattedCurrentDate.value =
        DateFormat('EEE dd MMM').format(_currentDate);
  }

  void onDateChanged(DateTime newDate) {
    int year = newDate.year;
    int month = newDate.month;
    int day = newDate.day;
    int lastDay = DateTime(year, month + 1, 0).day;

    periodDay = day;
    periodMonth = month;
    periodYear = year;

    if (day > lastDay) {
      newDate = DateTime(year, month, lastDay);
    }

    if (_selectedDate != newDate) {
      _selectedDate = newDate;

      final formattedDate =
          "${day.toString().padLeft(2, '0')}/"
          "${month.toString().padLeft(2, '0')}/"
          "$year";

      periodLastPeriodDay.value = formattedDate;

      _calculateNextDates();
    }
  }

  void getPeriodDays(String day) {
    periodDays.value = day;
    _calculateNextDates();
  }

  void getPeriodCycleDays(String day) {
    periodCycleDays.value = day;
    _calculateNextDates();
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
      // final periodLength = int.tryParse(periodDays.value) ?? 5;

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

  Future<void> saveWomenHealthData(int periodDays, int periodCycleDays, int periodDay, int periodMonth, int periodYear) async {
  try {
    Map<String, dynamic> payload = {
          'PeroidsDuration': periodDays,
          'PeroidsCycleCount': periodCycleDays,
          'PeriodDay': periodDay,
          'PeriodMonth': periodMonth,
          'PeriodYear': periodYear,
          'Disorder' : null,
        };
    final response = await ApiService.post(
      womenhealth,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response) {
      Get.snackbar('Error', 'Failed to save Women Health Data: ${response.statusCode}');
      return;
    }

    // Get.snackbar('Success', 'Women Health Data saved successfully!');

    print("✅ Women Health Data saved successfully: $response");

  } catch (e) {
    Get.snackbar('Error', 'Failed saving Women Health Data');
  }
}
}
