import 'package:modern_form_line_awesome_icons/modern_form_line_awesome_icons.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/views/WomenHealth/women_health_history.dart';
import '../../Widgets/Hydration/floating_button_bar.dart';
import '../../Widgets/WomenHealth/calender.dart';
import '../../Widgets/WomenHealth/period_cycle_phase_cont.dart';
import '../../Widgets/WomenHealth/women_health_quotes_widget.dart';
import '../../Widgets/WomenHealth/women_health_top_cont.dart';
import '../../consts/consts.dart';
import '../Reminder/reminder.dart';

class WomenHealthScreen extends StatelessWidget {
  WomenHealthScreen({super.key});

  final WomenHealthController womenController =
      Get.find<WomenHealthController>();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: 'Women Health'),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: WomenHealthTopCont(
                    isDarkMode: isDarkMode,
                    height: height,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      AutoSizeText(
                        "Cycle Phase",
                        minFontSize: 20,
                        maxFontSize: 24,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: Icon(LineAwesomeIcons.angle_right, size: 24),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 20),
                    child: Obx(
                      () => Row(
                        children: [
                          PeriodCyclePhaseCont(
                            height: height,
                            width: width,
                            heading: womenController.nextPeriodDay.value,
                            subHeading: 'Next Period',
                            img: cyclePhaseIcon1,
                            borderColor: periodHighlighted.withValues(
                              alpha: 0.4,
                            ),
                            contColor: periodHighlighted.withValues(alpha: 0.2),
                          ),

                          PeriodCyclePhaseCont(
                            height: height,
                            width: width,
                            heading: womenController.nextFertilityDay.value,
                            subHeading: 'Next Fertile',
                            img: cyclePhaseIcon2,
                            borderColor: green.withValues(alpha: 0.4),
                            contColor: green.withValues(alpha: 0.2),
                          ),
                          PeriodCyclePhaseCont(
                            height: height,
                            width: width,
                            heading: womenController.nextOvulationDay.value,
                            subHeading: 'Ovulation',
                            img: cyclePhaseIcon3,
                            borderColor: yellow.withValues(alpha: 0.4),
                            contColor: yellow.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                CalendarWidget(),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 20,
                      ),
                      child: Row(
                        children: [
                          AutoSizeText(
                            "For You",
                            minFontSize: 20,
                            maxFontSize: 24,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(LineAwesomeIcons.angle_right, size: 24),
                          ),
                        ],
                      ),
                    ),
                    WomenHealthQuotesWidget(
                      contColor: periodHighlighted,
                      img: quoteIcon1,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Divider(color: mediumGrey, thickness: border04px),
                    ),

                    WomenHealthQuotesWidget(contColor: yellow, img: quoteIcon2),
                  ],
                ),
                SizedBox(height: 120),
              ],
            ),
          ),

          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SafeArea(
                child: FloatingButtonBar(
                  onStatBtnTap: () => Get.to(() => WomenHealthHistory()),
                  onReminderBtnTap: () {
                    Get.to(() => Reminder());
                  },
                  onAddBtnTap: () async {
                    DateTime now = DateTime.now();

                    DateTime? selectedDate = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(Duration(days: 30)),
                      // allow up to 1 month back
                      lastDate: DateTime(2050),
                      builder: (BuildContext context, Widget? child) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;

                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme:
                                isDark
                                    ? ColorScheme.dark(
                                      primary: AppColors.primaryColor,
                                      onPrimary: white,
                                      onSurface: white,
                                    )
                                    : ColorScheme.light(
                                      primary: AppColors.primaryColor,
                                      onPrimary: white,
                                      onSurface: black,
                                    ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primaryColor,
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (selectedDate != null) {
                      womenController.onDateChanged(selectedDate);
                    }
                  },

                  onAddBtnLongTap: () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
