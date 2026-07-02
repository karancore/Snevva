import '../../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../../consts/consts.dart';

class _Trait {
  final String name;
  final String description;
  final IconData icon;

  const _Trait({
    required this.name,
    required this.description,
    required this.icon,
  });
}

class _Question {
  final String text;
  final int traitIndex;

  const _Question({required this.text, required this.traitIndex});
}

enum _Stage { intro, quiz, result }

class PsychometricTestScreen extends StatefulWidget {
  const PsychometricTestScreen({super.key});

  @override
  State<PsychometricTestScreen> createState() =>
      _PsychometricTestScreenState();
}

class _PsychometricTestScreenState extends State<PsychometricTestScreen> {
  _Stage _stage = _Stage.intro;
  int _currentQuestion = 0;
  final Map<int, int> _answers = {}; // question index -> score (1-5)

  static const List<_Trait> _traits = [
    _Trait(
      name: 'Openness',
      description: 'How curious and open you are to new ideas & experiences.',
      icon: Icons.lightbulb_outline_rounded,
    ),
    _Trait(
      name: 'Conscientiousness',
      description: 'How organized, disciplined and goal-driven you are.',
      icon: Icons.checklist_rounded,
    ),
    _Trait(
      name: 'Extraversion',
      description: 'How energized you feel in social situations.',
      icon: Icons.groups_outlined,
    ),
    _Trait(
      name: 'Agreeableness',
      description: 'How considerate, trusting and cooperative you are.',
      icon: Icons.favorite_border_rounded,
    ),
    _Trait(
      name: 'Emotional Stability',
      description: 'How calm and composed you stay under pressure.',
      icon: Icons.self_improvement_rounded,
    ),
  ];

  static const List<_Question> _questions = [
    _Question(
      text: 'I enjoy exploring new ideas and creative activities.',
      traitIndex: 0,
    ),
    _Question(
      text: "I like trying new experiences even if they're unfamiliar.",
      traitIndex: 0,
    ),
    _Question(
      text: 'I pay attention to details and complete tasks thoroughly.',
      traitIndex: 1,
    ),
    _Question(
      text: 'I plan ahead and stick to a schedule.',
      traitIndex: 1,
    ),
    _Question(
      text: "I feel energized when I'm around other people.",
      traitIndex: 2,
    ),
    _Question(
      text: 'I enjoy being the centre of attention in social settings.',
      traitIndex: 2,
    ),
    _Question(
      text: 'I try to be considerate and kind to others.',
      traitIndex: 3,
    ),
    _Question(
      text: 'I find it easy to trust people.',
      traitIndex: 3,
    ),
    _Question(
      text: 'I stay calm and composed under pressure.',
      traitIndex: 4,
    ),
    _Question(
      text: 'I rarely feel anxious or worried about things.',
      traitIndex: 4,
    ),
  ];

  static const List<String> _likertLabels = [
    'Strongly Disagree',
    'Disagree',
    'Neutral',
    'Agree',
    'Strongly Agree',
  ];

  void _selectAnswer(int score) {
    setState(() {
      _answers[_currentQuestion] = score;
    });

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_currentQuestion < _questions.length - 1) {
        setState(() => _currentQuestion++);
      } else {
        setState(() => _stage = _Stage.result);
      }
    });
  }

  void _restart() {
    setState(() {
      _stage = _Stage.intro;
      _currentQuestion = 0;
      _answers.clear();
    });
  }

  Map<int, double> get _traitScores {
    final Map<int, List<int>> grouped = {};
    for (int i = 0; i < _questions.length; i++) {
      final traitIndex = _questions[i].traitIndex;
      final score = _answers[i] ?? 3;
      grouped.putIfAbsent(traitIndex, () => []).add(score);
    }
    return grouped.map((traitIndex, scores) {
      final total = scores.reduce((a, b) => a + b);
      final maxTotal = scores.length * 5;
      final minTotal = scores.length * 1;
      final percent = (total - minTotal) / (maxTotal - minTotal) * 100;
      return MapEntry(traitIndex, percent.clamp(0, 100));
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(appbarText: 'Psychometric Test'),
      body: SafeArea(
        child: switch (_stage) {
          _Stage.intro => _buildIntro(isDarkMode),
          _Stage.quiz => _buildQuiz(isDarkMode),
          _Stage.result => _buildResult(isDarkMode),
        },
      ),
    );
  }

  Widget _buildIntro(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_outlined, color: white, size: 36),
                const SizedBox(height: 12),
                const Text(
                  'What is a Psychometric Test?',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'A psychometric test is a standardized, evidence-based '
                  'assessment used to measure psychological attributes such '
                  'as personality traits, cognitive ability and behaviour. '
                  "It doesn't diagnose anything — it simply gives you "
                  'objective insight into how you think, feel and interact '
                  'with the world, so you can better understand yourself.',
                  style: TextStyle(
                    color: white.withOpacity(0.92),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'This quick test measures',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDarkMode ? white : black,
            ),
          ),
          const SizedBox(height: 12),
          ..._traits.map(
            (trait) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? darkGray : white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDarkMode
                          ? Colors.white12
                          : Colors.grey.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.black26
                            : Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      trait.icon,
                      color: AppColors.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trait.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? white : black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trait.description,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDarkMode ? Colors.white60 : mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Takes about 2 minutes • ${_questions.length} quick questions',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.white54 : mediumGrey,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed:
                    () => setState(() {
                      _stage = _Stage.quiz;
                      _currentQuestion = 0;
                      _answers.clear();
                    }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Start Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuiz(bool isDarkMode) {
    final question = _questions[_currentQuestion];
    final progress = (_currentQuestion + 1) / _questions.length;
    final selected = _answers[_currentQuestion];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Question ${_currentQuestion + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white60 : mediumGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor:
                  isDarkMode
                      ? Colors.white.withOpacity(0.12)
                      : Colors.black.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            question.text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? white : black,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(_likertLabels.length, (index) {
            final score = index + 1;
            final isSelected = selected == score;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _selectAnswer(score),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color:
                        isSelected
                            ? null
                            : (isDarkMode ? darkGray : white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? Colors.transparent
                              : AppColors.primaryColor.withOpacity(0.25),
                    ),
                    boxShadow:
                        isSelected
                            ? []
                            : [
                              BoxShadow(
                                color:
                                    isDarkMode
                                        ? Colors.black26
                                        : Colors.grey.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                  ),
                  child: Text(
                    _likertLabels[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected
                              ? white
                              : (isDarkMode ? white : black),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_currentQuestion > 0)
            TextButton.icon(
              onPressed: () => setState(() => _currentQuestion--),
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 14,
                color: AppColors.primaryColor,
              ),
              label: const Text(
                'Previous',
                style: TextStyle(color: AppColors.primaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResult(bool isDarkMode) {
    final scores = _traitScores;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_events_outlined, color: white, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Your Results Are In!',
                  style: TextStyle(
                    color: white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Here's a quick snapshot of your personality profile "
                  'based on your answers.',
                  style: TextStyle(color: white.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_traits.length, (index) {
            final trait = _traits[index];
            final score = scores[index] ?? 0;
            final label = score >= 70 ? 'High' : (score >= 40 ? 'Moderate' : 'Low');

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDarkMode ? darkGray : white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDarkMode
                          ? Colors.white12
                          : Colors.grey.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDarkMode
                            ? Colors.black26
                            : Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(trait.icon, color: AppColors.primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trait.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? white : black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 7,
                      backgroundColor:
                          isDarkMode
                              ? Colors.white.withOpacity(0.12)
                              : Colors.black.withOpacity(0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    trait.description,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.white60 : mediumGrey,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Text(
            'Note: This is a lightweight self-reflection tool, not a '
            'clinical diagnostic instrument.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDarkMode ? Colors.white54 : mediumGrey,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _restart,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Retake Test',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
