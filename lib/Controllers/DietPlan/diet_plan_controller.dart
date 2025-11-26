
import '../../consts/consts.dart';

class DietPlanController extends GetxController {
  final selectedDayIndex = 0.obs;
  late PageController pageController;

  @override
  void onInit() {
    pageController = PageController(initialPage: selectedDayIndex.value);
    super.onInit();
  }

  void changeDay(int index) {
    selectedDayIndex.value = index;
    pageController.jumpToPage(index);
  }

  void onPageChanged(int index) {
    selectedDayIndex.value = index;
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
