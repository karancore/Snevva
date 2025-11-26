class MoodQuestion {
  final String questionText;
  final List<MoodAnswerOption> options;

  MoodQuestion({required this.questionText, required this.options});
}

class MoodAnswerOption {
  final String heading;
  final String subHeading;

  MoodAnswerOption({required this.heading, required this.subHeading});
}
