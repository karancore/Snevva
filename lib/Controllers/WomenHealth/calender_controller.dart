import 'package:flutter/widgets.dart';

class CalendarController {
  static const int initialPage = 1200;

  var currentMonth = DateTime.now();
  var pageIndex = initialPage;

  late final PageController pageController;

  void onInit() {
    pageController = PageController(initialPage: initialPage);
  }

  void onDispose() {
    pageController.dispose();
  }

  void onPageChanged(int index) {
    pageIndex = index;
    final offset = index - initialPage;
    currentMonth = DateTime(DateTime.now().year, DateTime.now().month + offset);
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
    currentMonth = DateTime(DateTime.now().year, DateTime.now().month + offset);
  }
}