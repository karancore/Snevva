import 'package:modern_form_line_awesome_icons/modern_form_line_awesome_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/WomenHealth/women_health_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/models/tips_response.dart';
import 'package:snevva/views/WomenHealth/women_health_history.dart';
import 'package:snevva/widgets/Hydration/floating_button_bar.dart';

import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import '../../widgets/WomenHealth/calender.dart';
import '../../widgets/WomenHealth/period_cycle_phase_cont.dart';
import '../../widgets/WomenHealth/women_health_quotes_widget.dart';
import '../../widgets/WomenHealth/women_health_top_cont.dart';
import '../Reminder/reminder_screen.dart';

class WomenHealthScreen extends StatefulWidget {
  const WomenHealthScreen({super.key});

  @override
  State<WomenHealthScreen> createState() => _WomenHealthScreenState();
}

class _WomenHealthScreenState extends State<WomenHealthScreen> {
  final WomenHealthController womenController =
      Get.find<WomenHealthController>();

  @override
  void initState() {
    super.initState();
    toggleWomenBottomCard();
    fetchWomenTips(context);
  }

  Future<void> toggleWomenBottomCard() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('is_first_time_women', false);
  }

  Future<void> fetchWomenTips(BuildContext ctx) async {
    await womenController.getWomenHealthQuotes(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

                // FIX: Wrap in Obx to make it reactive
                Obx(() {
                  // FIX: Add debug print to check list length
                  print(
                    "Tips count: ${womenController.womenHealthTips.length}",
                  );

                  // FIX: Show loading or empty state
                  if (womenController.womenHealthTips.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              LineAwesomeIcons.heart,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "Loading tips...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20, // FIX: Add top padding for spacing
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,

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
                            // Spacer(),
                            // IconButton(
                            //   onPressed: () {},
                            //   icon: Icon(LineAwesomeIcons.angle_right, size: 24),
                            // ),
                          ],
                        ),
                      ),
                      // FIX: Add padding around ListView
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: womenController.womenHealthTips.length,
                        separatorBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 20, right: 20),
                            child: Divider(
                              color: mediumGrey,
                              thickness: border04px,
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final tip = womenController.womenHealthTips[index];
                          print("Rendering tip $index: ${tip.title}");

                          // FIX: Add null check for thumbnailMedia
                          return WomenHealthQuotesWidget(
                            title: tip.title,
                            shortDescription: tip.shortDescription,
                            imageUrl: tip.thumbnailMedia?.cdnUrl ?? '',
                          );
                        },
                      ),
                    ],
                  );
                }),

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
                    Get.toNamed('/reminder');
                  },
                  onAddBtnTap: () async {
                    DateTime now = DateTime.now();

                    DateTime? selectedDate = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(Duration(days: 30)),
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
