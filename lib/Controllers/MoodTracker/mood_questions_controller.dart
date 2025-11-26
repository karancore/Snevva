
import 'package:get/get.dart';

class MoodQuestionController extends GetxController {

  final selectedAnswers = <int, String?>{}.obs;

  void selectAnswer(int questionIndex, String heading) {

    if (selectedAnswers[questionIndex] == heading) {
      selectedAnswers[questionIndex] = null;
    } else {
      selectedAnswers[questionIndex] = heading;
    }
  }

  String? getSelectedAnswer(int questionIndex) {
    return selectedAnswers[questionIndex];
  }
}
