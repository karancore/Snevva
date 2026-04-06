import 'package:linear_progress_bar/linear_progress_bar.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';

import '../../consts/consts.dart';
import '../../models/mood_questionnaire_model.dart';
import '../../widgets/CommonWidgets/custom_appbar.dart';
import '../../widgets/MoodTracker/mood_answer_selection_widget.dart';

class MoodQuestionnaire extends StatefulWidget {
  const MoodQuestionnaire({super.key});

  @override
  State<MoodQuestionnaire> createState() => _MoodQuestionnaireState();
}

class _MoodQuestionnaireState extends State<MoodQuestionnaire> {
  late final MoodQuestionController moodQuestionController;
  final moodController = Get.find<MoodController>();

  @override
  void initState() {
    super.initState();

    moodQuestionController =
        Get.isRegistered<MoodQuestionController>()
            ? Get.find<MoodQuestionController>()
            : Get.put(MoodQuestionController());
  }


  final Map<String, Map<String, MoodQuestion>> questions = {
    'Unpleasant': {
      'q1': MoodQuestion(
        id: 'q1',
        questionText: "How would you describe your daily water intake?",
        options: [
          MoodAnswerOption(heading: '🚰 Low', subHeading: 'Very little water'),
          MoodAnswerOption(heading: '🥤 Moderate', subHeading: 'Occasionally'),
          MoodAnswerOption(heading: '💦 High', subHeading: 'Regularly'),
        ],
        nextQuestionId: {
          '🚰 Low': 'q2a',
          '🥤 Moderate': 'q2b',
          '💦 High': 'q2b',
        },
      ),

      'q2a': MoodQuestion(
        id: 'q2a',
        questionText: "Are you feeling headaches or fatigue?",
        options: [
          MoodAnswerOption(heading: '🤕 Yes', subHeading: 'Often tired'),
          MoodAnswerOption(heading: '🙂 No', subHeading: 'Not really'),
        ],
        nextQuestionId: {'🤕 Yes': 'q3', '🙂 No': 'q3'},
      ),

      'q2b': MoodQuestion(
        id: 'q2b',
        questionText: "How active are you during the day?",
        options: [
          MoodAnswerOption(heading: '🛋 Inactive', subHeading: 'No movement'),
          MoodAnswerOption(heading: '🚶 Moderate', subHeading: 'Some activity'),
          MoodAnswerOption(heading: '🏃 Active', subHeading: 'Very active'),
        ],
        nextQuestionId: {
          '🛋 Inactive': 'q3',
          '🚶 Moderate': 'q3',
          '🏃 Active': null, // 👈 early end
        },
      ),

      'q3': MoodQuestion(
        id: 'q3',
        questionText: "How balanced is your diet?",
        options: [
          MoodAnswerOption(heading: '🍔 Poor', subHeading: 'Mostly junk'),
          MoodAnswerOption(heading: '🥗 Moderate', subHeading: 'Some healthy'),
          MoodAnswerOption(heading: '🍎 Good', subHeading: 'Balanced'),
        ],
        nextQuestionId: {'🍔 Poor': null, '🥗 Moderate': null, '🍎 Good': null},
      ),
    },

    'Pleasant': {
      'q1': MoodQuestion(
        id: 'q1',
        questionText: "How relaxed do you feel?",
        options: [
          MoodAnswerOption(heading: '😟 Stressed', subHeading: 'Tense'),
          MoodAnswerOption(heading: '🙂 Calm', subHeading: 'Okay'),
          MoodAnswerOption(heading: '😌 Very relaxed', subHeading: 'Peaceful'),
        ],
        nextQuestionId: {
          '😟 Stressed': 'q2a',
          '🙂 Calm': 'q2b',
          '😌 Very relaxed': 'q2b',
        },
      ),

      'q2a': MoodQuestion(
        id: 'q2a',
        questionText: "What’s causing stress?",
        options: [
          MoodAnswerOption(heading: '💼 Work', subHeading: 'Job pressure'),
          MoodAnswerOption(
            heading: '👨‍👩‍👧 Personal',
            subHeading: 'Life issues',
          ),
        ],
        nextQuestionId: {'💼 Work': 'q3', '👨‍👩‍👧 Personal': 'q3'},
      ),

      'q2b': MoodQuestion(
        id: 'q2b',
        questionText: "How social are you feeling?",
        options: [
          MoodAnswerOption(heading: '😶 Reserved', subHeading: 'Alone'),
          MoodAnswerOption(
            heading: '😊 Friendly',
            subHeading: 'Some interaction',
          ),
          MoodAnswerOption(heading: '🥳 Social', subHeading: 'Very social'),
        ],
        nextQuestionId: {
          '😶 Reserved': 'q3',
          '😊 Friendly': null,
          '🥳 Social': null,
        },
      ),

      'q3': MoodQuestion(
        id: 'q3',
        questionText: "How motivated are you?",
        options: [
          MoodAnswerOption(heading: '😔 Low', subHeading: 'Hard to start'),
          MoodAnswerOption(heading: '🙂 Moderate', subHeading: 'Manageable'),
          MoodAnswerOption(heading: '💪 High', subHeading: 'Driven'),
        ],
        nextQuestionId: {'😔 Low': null, '🙂 Moderate': null, '💪 High': null},
      ),
    },

    'Good': {
      'q1': MoodQuestion(
        id: 'q1',
        questionText: "How productive do you feel?",
        options: [
          MoodAnswerOption(heading: '😴 Low', subHeading: 'Struggling'),
          MoodAnswerOption(heading: '🙂 Moderate', subHeading: 'Some work'),
          MoodAnswerOption(heading: '🏆 High', subHeading: 'Very productive'),
        ],
        nextQuestionId: {
          '😴 Low': 'q2a',
          '🙂 Moderate': 'q2b',
          '🏆 High': 'q2b',
        },
      ),

      'q2a': MoodQuestion(
        id: 'q2a',
        questionText: "How well did you sleep?",
        options: [
          MoodAnswerOption(heading: '😴 Poor', subHeading: 'Bad sleep'),
          MoodAnswerOption(heading: '🙂 Average', subHeading: 'Okay'),
        ],
        nextQuestionId: {'😴 Poor': 'q3', '🙂 Average': 'q3'},
      ),

      'q2b': MoodQuestion(
        id: 'q2b',
        questionText: "How energetic are you?",
        options: [
          MoodAnswerOption(heading: '😪 Low', subHeading: 'Tired'),
          MoodAnswerOption(heading: '⚡ High', subHeading: 'Full energy'),
        ],
        nextQuestionId: {'😪 Low': 'q3', '⚡ High': null},
      ),

      'q3': MoodQuestion(
        id: 'q3',
        questionText: "How is your self-care today?",
        options: [
          MoodAnswerOption(heading: '😔 Low', subHeading: 'Neglecting'),
          MoodAnswerOption(heading: '💖 High', subHeading: 'Taking care'),
        ],
        nextQuestionId: {'😔 Low': null, '💖 High': null},
      ),
    },
  };

  String currentQuestionId = 'q1';
  List<String> questionFlow = ['q1']; // for progress
  late final Map<String, MoodQuestion>? filteredQuestions =
      questions[moodController.selectedUserMood];

  final List<String> headings = [
    "Let's Start",
    "You are very close...",
    "One More",
    "And we are done",
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mood Tracker"),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headings[(questionFlow.length - 1).clamp(
                      0, headings.length - 1)],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                LinearProgressBar(
                  maxSteps: 4,
                  progressType: LinearProgressBar.progressTypeLinear,
                  currentStep: questionFlow.length,
                  progressColor: AppColors.primaryColor,
                  backgroundColor: mediumGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Builder(
                builder: (context) {
                  final question = filteredQuestions![currentQuestionId]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.questionText,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Obx(() {
                        final selected = moodQuestionController
                            .getSelectedAnswer(questionFlow.length - 1);

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children:
                          question.options.map((option) {
                            return MoodAnswerSelectionWidget(
                              onTap: () {
                                moodQuestionController.selectAnswer(
                                  questionFlow.length - 1,
                                  option.heading,
                                );

                                final nextId =
                                question.nextQuestionId[option.heading];

                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                      () {
                                    if (nextId == null) {
                                      Get.until((route) => route.isFirst);
                                    } else {
                                      setState(() {
                                        currentQuestionId = nextId;
                                        questionFlow.add(nextId);
                                      });
                                    }
                                  },
                                );
                              },
                              isDarkMode: isDarkMode,
                              height: height,
                              isSelected: selected == option.heading,
                              // ✅ FIXED
                              heading: option.heading,
                              subHeading: option.subHeading,
                              index: questionFlow.length - 1,
                            );
                          }).toList(),
                        );
                      }),

                      const Spacer(),

                      /// 🔙 BACK BUTTON
                      if (questionFlow.length > 1)
                        SafeArea(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(

                              onPressed: () {
                                setState(() {
                                  questionFlow.removeLast();
                                  currentQuestionId = questionFlow.last;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),

                              child: const Text('< Previous'),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
