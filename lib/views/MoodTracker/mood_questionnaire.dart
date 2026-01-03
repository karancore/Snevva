import 'dart:math';

import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:linear_progress_bar/linear_progress_bar.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../Widgets/MoodTracker/exercise_bubbles.dart';
import '../../Widgets/MoodTracker/mood_answer_selection_widget.dart';
import '../../consts/consts.dart';
import '../../models/mood_questionnaire_model.dart';

class MoodQuestionnaire extends StatefulWidget {
  const MoodQuestionnaire({super.key});

  @override
  State<MoodQuestionnaire> createState() => _MoodQuestionnaireState();
}

class _MoodQuestionnaireState extends State<MoodQuestionnaire> {
  late final MoodQuestionController moodController;

  @override
  void initState() {
    super.initState();
    moodController = Get.put(MoodQuestionController());
  }

  final PageController _controller = PageController();

  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  final List<MoodQuestion> questions = [
    MoodQuestion(
      questionText: "How would you describe your daily water intake?",
      options: [
        MoodAnswerOption(
          heading: '🚰 Low',
          subHeading: 'I drink very little water',
        ),
        MoodAnswerOption(
          heading: '🥤 Moderate',
          subHeading: 'I drink water occasionally',
        ),
        MoodAnswerOption(
          heading: '💦 High',
          subHeading: 'I drink water regularly',
        ),
      ],
    ),
    MoodQuestion(
      questionText: "How active are you during the day?",
      options: [
        MoodAnswerOption(
          heading: '🛋 Mostly inactive',
          subHeading: 'Little to no physical activity',
        ),
        MoodAnswerOption(
          heading: '🚶 Moderately active',
          subHeading: 'Some walking or light exercise',
        ),
        MoodAnswerOption(
          heading: '🏃 Very active',
          subHeading: 'Regular workouts or sports',
        ),
      ],
    ),
    MoodQuestion(
      questionText: "How often do you work out?",
      options: [
        MoodAnswerOption(heading: '😴 Rarely', subHeading: 'Almost never'),
        MoodAnswerOption(
          heading: '🙂 Sometimes',
          subHeading: '1–3 times a week',
        ),
        MoodAnswerOption(
          heading: '🔥 Regularly',
          subHeading: '4+ times a week',
        ),
      ],
    ),
    MoodQuestion(
      questionText: "Choose type of exercise.",
      options: [
        MoodAnswerOption(heading: '😴 Rarely', subHeading: 'Almost never'),
        MoodAnswerOption(
          heading: '🙂 Sometimes',
          subHeading: '1–3 times a week',
        ),
        MoodAnswerOption(
          heading: '🔥 Regularly',
          subHeading: '4+ times a week',
        ),
      ],
    ),
  ];
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
                  headings[_currentIndex],
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                LinearProgressBar(
                  maxSteps: questions.length - 1,
                  progressType: LinearProgressBar.progressTypeLinear,
                  currentStep: (_currentIndex).clamp(0, questions.length),
                  progressColor: AppColors.primaryColor,
                  backgroundColor: mediumGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: questions.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final question = questions[index];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            question.questionText,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,

                            ),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 20),

                          if (question.options.isNotEmpty)
                            Obx(() {
                              final selected =
                              moodController.getSelectedAnswer(_currentIndex);

                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: question.options.map((option) {
                                  return MoodAnswerSelectionWidget(
                                    onTap: () {
                                      moodController.selectAnswer(
                                        _currentIndex,
                                        option.heading,
                                      );
                                    },
                                    isDarkMode: isDarkMode,
                                    height: height,
                                    isSelected: selected == option.heading,
                                    heading: option.heading,
                                    subHeading: option.subHeading,
                                    index: _currentIndex,
                                  );
                                }).toList(),
                              );
                            }),

                          const Spacer(),
                          SafeArea(
                            child: Row(
                              children: [
                                if (_currentIndex == 0) SizedBox.shrink(),
                                if (_currentIndex > 0)
                                  SizedBox(
                                    height: min(
                                      MediaQuery.of(context).size.height * 0.1,
                                      48,
                                    ),
                                    width: width / 2.5,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        side: BorderSide(
                                          color: AppColors.primaryColor,
                                          width: 2,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                      ),
                                      onPressed: () {
                                        _controller.previousPage(
                                          duration: Duration(milliseconds: 10),
                                          curve: Curves.ease,
                                        );
                                      },
                                      child: const Text(
                                        '<  Previous',
                                        style: TextStyle(
                                          color: AppColors.primaryColor,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                const Spacer(),

                                SizedBox(
                                  height: min(
                                    MediaQuery.of(context).size.height * 0.1,
                                    48,
                                  ),
                                  width: width / 2.5,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (_currentIndex == questions.length - 1) {
                                        Get.to(() => HomeWrapper());
                                      } else {
                                        _controller.nextPage(
                                          duration: Duration(milliseconds: 400),
                                          curve: Curves.ease,
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: AppColors.primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      side: BorderSide(
                                        color: AppColors.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: AutoSizeText(
                                      _currentIndex == questions.length - 1
                                          ? 'Submit'
                                          : 'Next  >',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // 👇 SHOW ONLY ON LAST PAGE
                  if (_currentIndex == questions.length - 1)
                    Positioned.fill(
                      child: ExerciseBubbles(isDarkMode: isDarkMode,),
                    ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}
