import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:linear_progress_bar/linear_progress_bar.dart';
import 'package:snevva/Controllers/MoodTracker/mood_questions_controller.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../Widgets/MoodTracker/mood_answer_selection_widget.dart';
import '../../consts/consts.dart';
import '../../models/mood_questionnaire_model.dart';

class MoodQuestionnaire extends StatefulWidget {
  const MoodQuestionnaire({super.key});

  @override
  State<MoodQuestionnaire> createState() => _MoodQuestionnaireState();
}

class _MoodQuestionnaireState extends State<MoodQuestionnaire> {
  final MoodQuestionController moodController = Get.put(
    MoodQuestionController(),
  );
  final CardSwiperController _controller = CardSwiperController();

  final List<MoodQuestion> questions = [
    MoodQuestion(
      questionText: "How often do you forget to drink water?",
      options: [
        MoodAnswerOption(
          heading: '😄 Not often',
          subHeading: 'I never forget to drink water',
        ),
        MoodAnswerOption(
          heading: '😫 Often',
          subHeading: 'I only remember sometimes',
        ),
        MoodAnswerOption(
          heading: '😭 Always',
          subHeading: 'I always forget to drink.',
        ),
      ],
    ),
    MoodQuestion(
      questionText: "When you drink water last time ?",
      options: [
        MoodAnswerOption(
          heading: '😤 15 min ago',
          subHeading: 'I drink water frequently',
        ),
        MoodAnswerOption(
          heading: '🙄 3 hour ago',
          subHeading: 'Three hours? Pfft, I’m fine!',
        ),
        MoodAnswerOption(
          heading: '😭 6 hour ago',
          subHeading: 'I always forget to drink.',
        ),
      ],
    ),
    MoodQuestion(
      questionText: "How often do you workout ?",
      options: [
        MoodAnswerOption(
          heading: '😗 Never',
          subHeading: 'I don’t need workout.',
        ),
        MoodAnswerOption(
          heading: '😊 45 min',
          subHeading: 'I know I am doing good.',
        ),
        MoodAnswerOption(
          heading: '🥱 2 hour',
          subHeading: 'It’s my daily routine.',
        ),
      ],
    ),
    MoodQuestion(questionText: "Completed", options: []),
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Mood Tracker"),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let\'s Start......',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                LinearProgressBar(
                  maxSteps: questions.length,
                  progressType: LinearProgressBar.progressTypeLinear,
                  currentStep: _currentIndex + 1,
                  progressColor: AppColors.primaryColor,
                  backgroundColor: mediumGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
          ),
          Expanded(
            child: CardSwiper(
              controller: _controller,
              isLoop: false,
              cardsCount: questions.length,
              numberOfCardsDisplayed: 1,
              backCardOffset: const Offset(40, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              cardBuilder: (context, index, hThreshold, vThreshold) {
                final question = questions[index];
                return Card(
                  color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            question.questionText,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (question.options.isNotEmpty)
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.start,
                            children:
                                question.options
                                    .map(
                                      (option) => Obx(
                                        () => MoodAnswerSelectionWidget(
                                          onTap: () {
                                            moodController.selectAnswer(
                                              _currentIndex,
                                              option.heading,
                                            );
                                          },
                                          isDarkMode: isDarkMode,
                                          height: height,
                                          isSelected:
                                              moodController.getSelectedAnswer(
                                                _currentIndex,
                                              ) ==
                                              option.heading,
                                          heading: option.heading,
                                          subHeading: option.subHeading,
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        const Spacer(),
                        Row(
                          children: [
                            if (_currentIndex != 0)
                              SizedBox(
                                height: 40,
                                width: width / 3,
                                child: OutlinedButton(
                                  onPressed: () {
                                    _controller.undo();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    side: BorderSide(
                                      color: AppColors.primaryColor,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  child: const AutoSizeText(
                                    '<  Previous',
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: AppColors.primaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            SizedBox(
                              height: 40,
                              width: width / 3,
                              child: OutlinedButton(
                                onPressed: () {
                                  if (_currentIndex == questions.length - 1) {
                                    Get.to(() => HomeWrapper());
                                  } else {
                                    _controller.swipe(CardSwiperDirection.left);
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
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              threshold: 10,
              duration: const Duration(milliseconds: 400),
              onSwipe: (previousIndex, currentIndex, direction) {
                setState(() {
                  _currentIndex = currentIndex ?? _currentIndex;
                });
                return true;
              },
              onUndo: (previousIndex, currentIndex, direction) {
                setState(() {
                  _currentIndex = previousIndex ?? _currentIndex;
                });
                return true;
              },
            ),
          ),
        ],
      ),
    );
  }
}
