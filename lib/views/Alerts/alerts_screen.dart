import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../Controllers/alerts/alerts_controller.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';
import '../../models/alerts.dart';
import '../../services/notification_service.dart';
import '../../widgets/CommonWidgets/custom_appbar.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  final alertsController = Get.find<AlertsController>();
  List<Alerts> _alerts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      alertsController.hitAlertsNotifications();
      // alertsController.scheduleAllAlerts(_dummyAlerts);
    });
  }

  final List<Alerts> _dummyAlerts = [
    Alerts(
      dataCode: "N001",
      heading: "Fitness Motivation",
      title: "Workout Reminder",
      times: ["12:20" , "08:00"],
      isActive: true
    ),
    Alerts(
      dataCode: "N002",
      heading: "General Info",
      title: "Stay Safe!",
      times: ["08:30" , "08:15"],
      isActive: true
    ),
    Alerts(
      dataCode: "N003",
      heading: "Fitness Motivation",
      title: "Workout Reminder",
      times: ["07:30" , "08:30"],
      isActive: true
    ),
  ];

  bool _isClearing = false;
  final GlobalKey<AnimatedListState> _dummyListKey =
      GlobalKey<AnimatedListState>();
  final GlobalKey<AnimatedListState> _apiListKey =
      GlobalKey<AnimatedListState>();

  Future<void> _clearAll(
    GlobalKey<AnimatedListState> key,
    List<Alerts> list,
  ) async {
    if (_isClearing || list.isEmpty) return;

    _isClearing = true;

    for (int i = list.length - 1; i >= 0; i--) {
      await Future.delayed(const Duration(milliseconds: 120));
      // use the general remove helper
      if (key == _dummyListKey) {
        _removeAnimatedItem(i, key, list);
      } else {
        // for non-animated lists, just remove normally
        setState(() {
          list.removeAt(i);
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 350));

    setState(() {
      _showEmptyState = true;
    });

    _isClearing = false;
  }

  bool _showEmptyState = false;

  // Removes an item from an AnimatedList safely.
  void _removeAnimatedItem(
    int index,
    GlobalKey<AnimatedListState> key,
    List<Alerts> list,
  ) {
    if (index < 0 || index >= list.length) return;
    final removedItem = list.removeAt(index);

    key.currentState?.removeItem(
      index,
      (context, animation) => _buildDismissibleItem(
        removedItem,
        index,
        key,
        isAnimatedList: true,
        underlyingList: list,
        animation: animation,
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  // General builder for both AnimatedList (dummy) and ListView (API)
  Widget _buildDismissibleItem(
    Alerts item,
    int index,
    GlobalKey<AnimatedListState> key, {
    required bool isAnimatedList,
    required List<Alerts> underlyingList,
    Animation<double>? animation,
  }) {
    final dismissibleKey = ValueKey(item.dataCode ?? item.title);

    Widget content = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications, color: AppColors.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.heading,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // If this is from AnimatedList, wrap with SizeTransition (animation supplied)
    if (animation != null) {
      content = SizeTransition(sizeFactor: animation, child: content);
    }

    return Dismissible(
      key: dismissibleKey,
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Icon(Icons.delete_outline, color: Colors.white, size: 26),
            SizedBox(width: 8),
            Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (direction) async {
        if (isAnimatedList) {
          // remove via AnimatedList helper
          final idx = underlyingList.indexWhere(
            (a) => a.dataCode == item.dataCode,
          );
          if (idx != -1) {
            _removeAnimatedItem(idx, key, underlyingList);
          }
        } else {
          // API list: update controller (make sure controller has method to persist deletion)
          await alertsController.markAsDeleted(item.dataCode);
          // remove from the controller list (GetX will rebuild)
          alertsController.notifications.removeWhere(
            (a) => a.dataCode == item.dataCode,
          );
        }
      },
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDarkMode ? black : white,
        centerTitle: true,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: isDarkMode ? black : white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            size: 24,
            color: isDarkMode ? white : black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Alerts",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? white : black,
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _dummyAlerts.isEmpty
                    ? null
                    : () => _clearAll(_dummyListKey, _dummyAlerts),
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: SafeArea(
        child: GetX<AlertsController>(
          builder: (controller) {
            final apiList = controller.notifications;

            // 1️⃣ If API has data -> use ListView to avoid AnimatedList coordination issues
            if (apiList.isNotEmpty) {
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: apiList.length,
                itemBuilder: (context, index) {
                  final item = apiList[index];
                  return _buildDismissibleItem(
                    item,
                    index,
                    _apiListKey,
                    isAnimatedList: false,
                    underlyingList: apiList,
                  );
                },
              );
            }

            // 2️⃣ If dummy has data -> use AnimatedList
            if (_dummyAlerts.isNotEmpty) {
              return AnimatedList(
                key: _dummyListKey,
                padding: const EdgeInsets.all(16),
                initialItemCount: _dummyAlerts.length,
                itemBuilder: (context, index, animation) {
                  final item = _dummyAlerts[index];
                  return _buildDismissibleItem(
                    item,
                    index,
                    _dummyListKey,
                    isAnimatedList: true,
                    underlyingList: _dummyAlerts,
                    animation: animation,
                  );
                },
              );
            }

            if (_showEmptyState || _dummyAlerts.isEmpty || apiList.isEmpty) {
              return _noNotificationsWidget(
                Theme.of(context).brightness == Brightness.dark,
              );
            }

            return _noNotificationsWidget(
              Theme.of(context).brightness == Brightness.dark,
            );
          },
        ),
      ),
    );
  }

  Widget _noNotificationsWidget(bool isDarkMode) {
    return Center(child: Image.asset(noNotif, scale: 3.5,));
  }
}
