import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class CalendarController extends GetxController {
  static const int initialPage = 1200;

  // ✅ Observable — any change automatically rebuilds Obx widgets
  final currentMonth = DateTime.now().obs;
  int pageIndex = initialPage;

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

  /// Called when the user SWIPES to a new page.
  void onPageChanged(int index) {
    pageIndex = index;
    final offset = index - initialPage;
    final now = DateTime.now();
    // Writing to .value triggers Obx rebuild → header updates on swipe
    currentMonth.value = DateTime(now.year, now.month + offset);
  }

  void nextMonth() {
    pageIndex++;
    _syncMonth();
    pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void prevMonth() {
    pageIndex--;
    _syncMonth();
    pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _syncMonth() {
    final offset = pageIndex - initialPage;
    final now = DateTime.now();
    currentMonth.value = DateTime(now.year, now.month + offset);
  }
}