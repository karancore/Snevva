import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linear_progress_bar/linear_progress_bar.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/question_screen_controller.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/common/custom_snackbar.dart';
import '../../Widgets/ProfileSetupAndQuestionnaire/answer_selection_widget.dart';
import '../../Widgets/ProfileSetupAndQuestionnaire/custom_dialog.dart';
import '../../consts/consts.dart';
import '../../models/questions_model.dart';

class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final CardSwiperController _controller = CardSwiperController();
  late final QuestionScreenController questionScreenController;

  List<Question> healthQuestions = [];
  List<Question> hobbyQuestions = [];
  List<Question> finalStepQuestions = [];

  void _loadHealthQuestions() {
    healthQuestions = [
      Question(
        questionText: "Select your activity level?",
        options: [
          AnswerOption(text: 'Couch Explorer', iconPath: studentIcon),
          AnswerOption(text: 'Casual Walker', iconPath: bagIcon),
          AnswerOption(text: 'Active Adventurer', iconPath: counsellorIcon),
          AnswerOption(text: 'Fitness Enthusiast', iconPath: otherIcon),
          AnswerOption(text: 'Athletic Pro', iconPath: otherIcon),
        ],
      ),
    ];
  }

  void _loadHobbyQuestions() {
    hobbyQuestions = [
      Question(
        questionText: "Select your health goal?",
        options: [
          AnswerOption(text: 'Get Stronger', iconPath: cookingIcon),
          AnswerOption(text: 'Boost Energy', iconPath: gamerIcon),
          AnswerOption(text: 'Lose Weight', iconPath: bookIcon),
          AnswerOption(text: 'Stay Healthy', iconPath: gardeningIcon),
          AnswerOption(text: 'Feel Better & Balanced', iconPath: otherIcon),
        ],
      ),
    ];
  }

  List<Question> get questions {
    return [...healthQuestions, ...hobbyQuestions, ...finalStepQuestions];
  }

  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    questionScreenController = Get.put(QuestionScreenController());

    _loadHealthQuestions();
    _loadHobbyQuestions();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: height / 3,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(questionImg),
                fit: BoxFit.fill,
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Let\'s Setup your profile 😊',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
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
                    const SizedBox(height: 32),
                    SizedBox(
                      height: height * 0.55,
                      child: CardSwiper(
                        controller: _controller,
                        isLoop: false,
                        cardsCount: questions.length,
                        numberOfCardsDisplayed: 1,
                        backCardOffset: const Offset(40, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        cardBuilder: (context, index, hThreshold, vThreshold) {
                          final question = questions[index];
                          return Card(
                            color:
                                isDarkMode
                                    ? scaffoldColorDark
                                    : scaffoldColorLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.questionText,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.start,
                                    children:
                                        question.options.map((option) {
                                          return Obx(
                                            () => AnswerSelectionWidget(
                                              widgetText: option.text,
                                              img: option.iconPath,
                                              multipleSelection:
                                                  option.multipleSelection,
                                              isSelected:
                                                  questionScreenController
                                                      .isSelected(
                                                        index,
                                                        option.text,
                                                      ),
                                              questionIndex: index,
                                              onTap: () {
                                                questionScreenController
                                                    .selection(
                                                      index,
                                                      option.text,
                                                      option.multipleSelection,
                                                    );
                                              },
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                  const Spacer(),
                                  SafeArea(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        if (_currentIndex >
                                            0) // Only show 'Previous' button if not on first page
                                          SizedBox(
                                            height: 40,
                                            width: width / 3,
                                            child: OutlinedButton(
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                side: BorderSide(
                                                  color: AppColors.primaryColor,
                                                  width: 2,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 4,
                                                    ),
                                              ),
                                              onPressed: () {
                                                _controller.undo();
                                              },
                                              child: const Text(
                                                '<  Previous',
                                                style: TextStyle(
                                                  color: AppColors.primaryColor,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        const Spacer(),
                                        SizedBox(
                                          height: 40,
                                          width: width / 3,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryColor,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              side: BorderSide(
                                                color: AppColors.primaryColor,
                                                width: 2,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 4,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              final isLast =
                                                  _currentIndex ==
                                                  questions.length - 1;

                                              // if (!isLast) {
                                              final hasSelected =
                                                  questionScreenController
                                                      .hasAnySelection(
                                                        _currentIndex,
                                                      );

                                              if (!hasSelected) {
                                                CustomSnackbar.showError(
                                                  context: context,
                                                  title: 'Oops!',
                                                  message:
                                                      'Please select at least one option before continuing.',
                                                );
                                                return; // stop here if no option
                                              }
                                              // }

                                              if (isLast) {
                                                // await questionScreenController
                                                //     .saveFinalStep();
                                                // Get.dialog(
                                                //   MyDialogWidget(
                                                //     title: 'Scan your report?',
                                                //     message:
                                                //         'Sed ut perspiciatis unde omnis iste natus error sit volum dolor.',
                                                //   ),
                                                //   barrierDismissible: false,
                                                // );
                                                await questionScreenController
                                                    .saveAnswer(
                                                      _currentIndex,
                                                      context,
                                                    );
                                                _controller.swipe(
                                                  CardSwiperDirection.left,
                                                );
                                                Get.offAll(HomeWrapper());
                                              } else {
                                                await questionScreenController
                                                    .saveAnswer(
                                                      _currentIndex,
                                                      context,
                                                    );
                                                _controller.swipe(
                                                  CardSwiperDirection.left,
                                                );
                                              }
                                            },
                                            child: Text(
                                              _currentIndex ==
                                                      questions.length - 1
                                                  ? 'All Done'
                                                  : 'Next  >',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
