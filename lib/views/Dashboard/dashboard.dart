import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import 'package:snevva/Controllers/StepCounter/step_counter_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Controllers/MoodTracker/mood_controller.dart';
import 'package:snevva/Widgets/Dashboard/dashboard_services_widget.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Alerts/alerts.dart';
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import '../../Controllers/Hydration/hydration_stat_controller.dart';
import '../../Widgets/Dashboard/dashboard_ads_carousel_slider.dart';
import '../../Widgets/Dashboard/dashboard_header_widget.dart';
import '../../Widgets/Dashboard/dashboard_service_overview_dynamic_widgets.dart';
import '../../services/notification_service.dart';

class Dashboard extends StatefulWidget {
  final Function(int)? onTabSelected;

  const Dashboard({super.key, this.onTabSelected});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  bool switchValue = false;
  String? username;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1), // Slide from slightly below
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    // Existing controllers
    Get.put(HydrationStatController());
    Get.put(MoodController());
    Get.put(EditprofileController());
    // Get.put(StepCounterController().loadtodaySteps());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    final localStorageManager = Get.put(LocalStorageManager());
    final notificationController = Get.put(NotificationService());

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🖐🏻 Hello', style: TextStyle(fontSize: 16)),
                  Text(
                    localStorageManager.userMap['Name']?.toString() ?? 'User',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              )),
              const Spacer(),
              Obx(() {
                bool hasNewNotif = notificationController.hasNewNotification.value;
                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, size: 28, color: AppColors.primaryColor),
                      onPressed: () {
                        Get.to(() => Alerts());
                        notificationController.hasNewNotification.value = false;
                      },
                    ),
                    if (hasNewNotif)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          height: 10,
                          width: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
        leading: IconButton(
          icon: SvgPicture.asset(drawerIcon),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 10) {
            _scaffoldKey.currentState?.openDrawer();
          } else if (details.delta.dx < -10) {
            if (_scaffoldKey.currentState?.isDrawerOpen == true) {
              Navigator.of(context).pop();
            }
          }
        },
        child: SafeArea(
          child: ScrollConfiguration(
            behavior: ScrollBehavior().copyWith(scrollbars: false, overscroll: false),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 15),
                      DashboardHeaderWidget(),
                      const SizedBox(height: 24),
                      DashboardServiceOverviewDynamicWidgets(
                        width: width,
                        height: height,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 24),
                      DashboardServicesWidget(),
                      DashboardAdsCarouselSlider(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
