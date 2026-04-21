import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class CalendarController extends GetxController {
  static const int initialPage = 1200; // Large enough to scroll far back/forward

  var currentMonth = DateTime.now().obs;
  var pageIndex = initialPage.obs;

  late final PageController pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController(initialPage: initialPage);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  /// Called when the user swipes to a new page.
  void onPageChanged(int index) {
    pageIndex.value = index;
    final offset = index - initialPage;
    final now = DateTime.now();
    currentMonth.value = DateTime(now.year, now.month + offset);
  }

  void nextMonth() {
    pageIndex.value = pageIndex.value + 1;
    final offset = pageIndex.value - initialPage;
    final now = DateTime.now();
    currentMonth.value = DateTime(now.year, now.month + offset);
  }

  void prevMonth() {
    pageIndex.value = pageIndex.value - 1;
    final offset = pageIndex.value - initialPage;
    final now = DateTime.now();
    currentMonth.value = DateTime(now.year, now.month + offset);
  }
}
