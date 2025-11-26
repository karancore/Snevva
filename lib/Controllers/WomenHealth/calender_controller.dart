import 'package:get/get.dart';

class CalendarController extends GetxController {
  var currentMonth = DateTime.now().obs;

  void nextMonth() {
    currentMonth.value = DateTime(
      currentMonth.value.year,
      currentMonth.value.month + 1,
    );
  }

  void prevMonth() {
    currentMonth.value = DateTime(
      currentMonth.value.year,
      currentMonth.value.month - 1,
    );
  }
}
