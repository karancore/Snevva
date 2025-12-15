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
  final PageController _controller = PageController();
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
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Let\'s Setup your profile 😊',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
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
          Expanded(
            child: SizedBox(
              height: height * 0.55,
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final question = questions[index];

                  return Padding(
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                    ),
                    child: Card(
                      color:
                          isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            question.questionText,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children:
                                question.options.map((option) {
                                  return Obx(
                                    () => AnswerSelectionWidget(
                                      widgetText: option.text,
                                      img: option.iconPath,
                                      multipleSelection:
                                          option.multipleSelection,
                                      isSelected: questionScreenController
                                          .isSelected(index, option.text),
                                      questionIndex: index,
                                      onTap: () {
                                        questionScreenController.selection(
                                          index,
                                          option.text,
                                          option.multipleSelection,
                                        );
                                      },
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (_currentIndex == 0) SizedBox.shrink(),
              if (_currentIndex > 0)
                SizedBox(
                  height: 40,
                  width: width / 3,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: BorderSide(color: AppColors.primaryColor, width: 2),
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
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    side: BorderSide(color: AppColors.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  ),
                  onPressed: () async {
                    final isLast = _currentIndex == questions.length - 1;

                    // if (!isLast) {
                    final hasSelected = questionScreenController
                        .hasAnySelection(_currentIndex);

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
                      await questionScreenController.saveAnswer(
                        _currentIndex,
                        context,
                      );
                      _controller.nextPage(
                        duration: Duration(milliseconds: 400),
                        curve: Curves.ease,
                      );

                      Get.offAll(HomeWrapper());
                    } else {
                      await questionScreenController.saveAnswer(
                        _currentIndex,
                        context,
                      );
                      _controller.nextPage(
                        duration: Duration(milliseconds: 400),
                        curve: Curves.ease,
                      );
                    }
                  },
                  child: Text(
                    _currentIndex == questions.length - 1
                        ? 'All Done'
                        : 'Next  >',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
