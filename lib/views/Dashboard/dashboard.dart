import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:snevva/Controllers/alerts/alerts_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/global_variables.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Alerts/alerts_screen.dart';

import '../../Controllers/ProfileSetupAndQuestionnare/editprofile_controller.dart';
import '../../services/notification_service.dart';
import '../../widgets/Drawer/drawer_menu_wigdet.dart';
import '../../widgets/dashboard/dashboard_ads_carousel_slider.dart';
import '../../widgets/dashboard/dashboard_header_widget.dart';
import '../../widgets/dashboard/dashboard_service_overview_dynamic_widgets.dart';
import '../../widgets/dashboard/dashboard_services_widget.dart';
import '../../widgets/dashboard/health_score_card.dart';
import '../../widgets/incomplete_profile_card.dart';

class Dashboard extends StatefulWidget {
  final Function(int)? onTabSelected;

  const Dashboard({super.key, this.onTabSelected});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  bool switchValue = false;
  String? username;
  bool isVisible = true;
  final localStorageManager = Get.find<LocalStorageManager>();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final notificationController = NotificationService();
  late final AlertsController alertsController;

  final scrollController = ScrollController();
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();

    alertsController = Get.find<AlertsController>();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    scrollController.addListener(() {
      if (scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_showAppBar) {
          setState(() => _showAppBar = false);
        }
      } else if (scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        if (!_showAppBar) {
          setState(() => _showAppBar = true);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await alertsController.hitAlertsNotifications();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool get _isPhoneMissing {
    final phone = localStorageManager.userMap['PhoneNumber']?.toString().trim();
    return phone == null || phone.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_showAppBar ? kToolbarHeight : 0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _showAppBar ? 1.0 : 0.0,
          child: AppBar(
            title: Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Obx(
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: Transform.rotate(
                                angle: -45 * math.pi / 180,
                                child: Lottie.asset(
                                  handWaveLottie,
                                  fit: BoxFit.contain,
                                  animate: TickerMode.of(context),
                                ),
                              ),
                            ),
                            const Text('Hello', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                        Text(
                          localStorageManager.userMap['Name']?.toString() ??
                              'User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Obx(() {
                    final unreadCount =
                        alertsController.unreadNotifications.length;
                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_none,
                            size: 28,
                            color: AppColors.primaryColor,
                          ),
                          onPressed: () {
                            Get.to(() => AlertsScreen());
                            notificationController.hasNewNotification.value =
                                false;
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: IconButton(
                icon: SvgPicture.asset(drawerIcon),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
          ),
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
            behavior: ScrollBehavior().copyWith(
              scrollbars: false,
              overscroll: false,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 24,
                top: 4,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Single card declaration handling both cases ──
                      if (isVisible)
                        Obx(() {
                          final bool showCard =
                              _isPhoneMissing ||
                              !isProfileDisplayComplete(
                                localStorageManager.userMap,
                              );

                          return showCard
                              ? Column(
                                children: [
                                  const SizedBox(height: 16),
                                  IncompleteProfileCard(
                                    onTapComplete: () {
                                      final ctrl =
                                          Get.find<EditprofileController>();
                                      ctrl.openNextMissingFieldDialog(context);
                                    },
                                    isExpanded: true,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              )
                              : const SizedBox(height: 32);
                        }),

                      DashboardHeaderWidget(),
                      const SizedBox(height: 16),
                      HealthScoreCard(isDarkMode: isDarkMode),
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
