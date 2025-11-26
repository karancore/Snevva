import 'package:get/get.dart';

class BottomSheetController extends GetxController {
  var pageIndex = 0.obs;
  final RxSet<String> selectedSymptoms = <String>{}.obs;
  final RxSet<String> selectedSymptomsLevel = <String>{}.obs;


  void nextPage(int totalPages) {
    if (pageIndex.value < totalPages - 1) {
      pageIndex.value++;
    } else {
      Get.back();
    }
  }

  void toggleSymptom(String symptom) {
    if (selectedSymptoms.contains(symptom)) {
      selectedSymptoms.remove(symptom);
    } else {
      selectedSymptoms.add(symptom);
    }
  }

  void toggleSymptomLevel(String level) {
    if (selectedSymptomsLevel.contains(level)) {
      selectedSymptomsLevel.clear();
    } else {
      selectedSymptomsLevel
        ..clear()
        ..add(level);
    }
  }

}
