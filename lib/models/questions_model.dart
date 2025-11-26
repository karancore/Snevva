class Question {
  final String questionText;
  final List<AnswerOption> options;

  Question({required this.questionText, required this.options});
}

class AnswerOption {
  final String text;
  final String iconPath;
  final bool multipleSelection;

  AnswerOption(
      {this.multipleSelection = false, required this.text, required this.iconPath});
}
