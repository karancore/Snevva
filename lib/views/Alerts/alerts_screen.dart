import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controllers/alerts/alerts_controller.dart';
import '../../consts/colors.dart';
import '../../consts/images.dart';
import '../../models/alerts.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late FirebaseMessaging messaging;

  final alertsController = Get.find<AlertsController>();
  final List<Alerts> _alerts = [];

  @override
  void initState() {
    super.initState();

    messaging = FirebaseMessaging.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      alertsController.hitAlertsNotifications();
      // alertsController.scheduleAllAlerts(_alerts);
    });
  }

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
    Widget content = GestureDetector(
  onTap: () {
    if (!isAnimatedList) {
      alertsController.readNotifications(item.dataCode);
    }
  },
      child: Container(
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
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        ),
    );

    // If this is from AnimatedList, wrap with SizeTransition (animation supplied)
    if (animation != null) {
      content = SizeTransition(sizeFactor: animation, child: content);
    }

    return Dismissible(
      key: ValueKey('${item.dataCode}_$index'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (isAnimatedList) {
          final idx = underlyingList.indexWhere(
            (a) => a.dataCode == item.dataCode,
          );

          if (idx != -1) {
            _removeAnimatedItem(idx, key, underlyingList);
          }
        } else {
          await alertsController.markAsDeleted(item.dataCode);

          alertsController.notifications.removeWhere(
            (a) => a.dataCode == item.dataCode,
          );
        }

        return false;
      },
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
                _alerts.isEmpty
                    ? null
                    : () => _clearAll(_dummyListKey, _alerts),
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
            if (_alerts.isNotEmpty) {
              return AnimatedList(
                key: _dummyListKey,
                padding: const EdgeInsets.all(16),
                initialItemCount: _alerts.length,
                itemBuilder: (context, index, animation) {
                  final item = _alerts[index];
                  return _buildDismissibleItem(
                    item,
                    index,
                    _dummyListKey,
                    isAnimatedList: true,
                    underlyingList: _alerts,
                    animation: animation,
                  );
                },
              );
            }

            if (_showEmptyState || _alerts.isEmpty || apiList.isEmpty) {
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
    return Center(child: Image.asset(noNotif, scale: 3.5));
  }
}
