import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/views/WomenHealth/women_health_screen.dart';
import 'package:wheel_picker/wheel_picker.dart';
import '../../Controllers/WomenHealth/women_health_controller.dart';
import '../../Widgets/CommonWidgets/common_question_bottom_sheet.dart';
import '../../consts/consts.dart';

class WomenBottomSheets extends StatefulWidget {
  final bool isDarkMode;
  final double width;
  final double height;

  const WomenBottomSheets({
    super.key,
    required this.isDarkMode,
    required this.width,
    required this.height,
  });

  @override
  State<WomenBottomSheets> createState() => _WomenBottomSheetsState();
}


class _WomenBottomSheetsState extends State<WomenBottomSheets> {
  final WomenHealthController womenController = Get.find<WomenHealthController>();

  final PageController _pageController = PageController();
  final WheelPickerController _wheelController = WheelPickerController(
    itemCount: 90,
    initialIndex: 4,
  );
  final WheelPickerController _wheelController2 = WheelPickerController(
    itemCount: 90,
    initialIndex: 27,
  );

  late final List<Widget> _pages;

  Future<void> toggleWomenBottomCard() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_first_time_women', false);
  }

  @override
  void initState() {
    super.initState();
    // toggleWomenBottomCard();

    _pages = [
      CommonQuestionBottomSheet(
        img: bottomSheetImg,
        wheel: _wheelController,
        unit: "Days",
        topPosition: 15,
        isDarkMode: widget.isDarkMode,
        width: widget.width,
        questionHeading: 'How many days does your period usually last?',
        questionSubHeading: 'Bleeding usually lasts between 4‑7 days',
        onNext: _goToNextPage,
        setDay: womenController.getPeriodDays,
        isSizedBoxReq: true,
      ),
      CommonQuestionBottomSheet(
        img: bottomSheetImg,
        wheel: _wheelController2,
        isDarkMode: widget.isDarkMode,
        width: widget.width,
        unit: "Days",
        topPosition: 15.0,
        questionHeading: 'How many days does your cycle usually last?',
        questionSubHeading: 'The days between 2 periods, usually 23-35 days',
        onNext: _goToNextPage,
        setDay: womenController.getPeriodCycleDays,
        isSizedBoxReq: true,
      ),
      CommonQuestionBottomSheet(
        img: bottomSheetImg,
        wheel: _wheelController,
        unit: "Days",
        isDarkMode: widget.isDarkMode,
        width: widget.width,
        topPosition: 15.0,
        questionHeading: 'What’s the start date of your last period?',
        questionSubHeading: 'The days between 2 periods, usually 23-35 days',
        isDatePickerReq: true,
        onNext: _goToNextPage,
        setDate: womenController.onDateChanged,
        isSizedBoxReq: true,
      ),
    ];
  }

  void _goToNextPage() {
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;

      if (currentPage < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        womenController.saveWomenHealthDatatoAPI(
          int.tryParse(womenController.periodDays.value) ?? 0,
          int.tryParse(womenController.periodCycleDays.value) ?? 0,
          womenController.periodDay,
          womenController.periodMonth,
          womenController.periodYear,
          context,
        );

        womenController.saveWomenHealthToLocalStorage();

        // ✅ Save the flag that user has completed setup
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('women_health_questions_completed', true);
        });

        toggleWomenBottomCard();

        Navigator.pop(context, true);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height * 0.52,
      child: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: _pages,
      ),
    );
  }
}

Future<bool?> showWomenBottomSheetsModal(
  BuildContext context,
  bool isDarkMode,
  double width,
  double height,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (_) => WomenBottomSheets(
          isDarkMode: isDarkMode,
          width: width,
          height: height,
        ),
  );
}
