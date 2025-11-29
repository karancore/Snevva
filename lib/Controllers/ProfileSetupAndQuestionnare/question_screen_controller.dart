import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

class QuestionScreenController extends GetxController {
  final selectedAnswers = <int, List<String>>{}.obs;

  /// Update selection (multi/single choice)
  void selection(
    int questionIndex,
    String optionText,
    bool isMultipleSelection,
  ) {
    final currentSelection = selectedAnswers[questionIndex] ?? [];

    if (isMultipleSelection) {
      if (currentSelection.contains(optionText)) {
        currentSelection.remove(optionText);
      } else {
        currentSelection.add(optionText);
      }
    } else {
      currentSelection
        ..clear()
        ..add(optionText);
    }
    selectedAnswers[questionIndex] = List.from(currentSelection);
  }

  /// Check if an option is selected
  bool isSelected(int questionIndex, String optionText) {
    return selectedAnswers[questionIndex]?.contains(optionText) ?? false;
  }

  /// Save data question by question
Future<void> saveAnswer(int questionIndex) async {
  try {
    final answers = selectedAnswers[questionIndex];
    if (answers == null || answers.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one option.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
      return;
    }

    String endpoint;
    Map<String, dynamic> payload;

    switch (questionIndex) {
      case 0: // Health goals
        endpoint = appactivityGoal;
        payload = { 'Value': answers[0] };
        break;

      case 1: // Hobbies
        endpoint = apphealthGoal;
        payload = { 'Value': answers[0] };
        break;

      // case 2: // Occupation
      //   endpoint = appOccupation;
      //   payload = { 'Occupation': answers };
      //   break;

      default:
        Get.snackbar('Error', 'Unknown question index: $questionIndex');
        return;
    }

    final response = await ApiService.post(
      endpoint,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response) {
      Get.snackbar('Error', 'Failed to save Q${questionIndex + 1}');
      return;
    }

    print("✅ Q${questionIndex + 1} saved → $answers");

  } catch (e) {
    Get.snackbar('Error', 'Failed saving Q${questionIndex + 1}');
  }
}

Future<void> saveFinalStep() async {
  // Handle last question’s API OR summary save
  print("🎯 Final step reached, do summary save here...");
}

bool hasAnySelection(int questionIndex) {
  return selectedAnswers.containsKey(questionIndex) &&
         selectedAnswers[questionIndex]!.isNotEmpty;
}
}