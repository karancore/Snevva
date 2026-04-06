class MoodQuestion {
  final String id;
  final String questionText;
  final List<MoodAnswerOption> options;
  final Map<String, String?> nextQuestionId; // 👈 key change

  MoodQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.nextQuestionId,
  });
}
class MoodAnswerOption {
  final String heading;
  final String subHeading;

  MoodAnswerOption({required this.heading, required this.subHeading});
}
