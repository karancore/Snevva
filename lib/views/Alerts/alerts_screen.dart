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
      ),
      duration: const Duration(milliseconds: 300),
    );
  }/ General builder for both AnimatedList (dummy) and ListView (API)
  Widget _buildDismissibleItem(Alerts item, {bool isRead = false}) {
    rreturn Dismissible(
      key: ValueKey('${item.dataCode}_${isRead ? "read" : "unread"}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await alertsController.readNotifications(item.dataCode);
        return false; // don't auto-remove; reactive list rebuilds
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: AppColors.greenGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.mark_chat_read, color: Colors.white, size: 26),
            SizedBox(width: 8),
            Text(
              "Mark Read",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (!isRead) alertsController.readNotifications(item.dataCode);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme
                .of(context)
                .brightness == Brightness.dark
                ? Colors.grey.shade900
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            // ✅ Unread items get a left accent border
            border: isRead
                ? null
                : Border(
              left: BorderSide(
                color: AppColors.greenGradient.colors.first,
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Unread dot indicator
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 10),
                  child: CircleAvatar(
                    radius: 5,
                    backgroundColor: AppColors.greenGradient.colors.first,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.heading,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                        isRead ? FontWeight.normal : FontWeight.bold,
                        color: isRead ? Colors.grey.shade600 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.greenGradient.colors.first.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.greenGradient.colors.first,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: isDark ? black : white,
        centerTitle: true,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: isDark ? black : white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 24, color: isDark ? white : black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Alerts",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? white : black,
          ),
        ),
      ),
      body: SafeArea(
        child: GetX<AlertsController>(
          builder: (controller) {
            final unread = controller.unreadNotifications;
            final read = controller.readNotifications_;

            if (unread.isEmpty && read.isEmpty) {
              return _noNotificationsWidget();
            }

            // Build a flat list of widgets:
            // [Unread header] + unread tiles + [Read header] + read tiles
            final List<Widget> items = [];

            if (unread.isNotEmpty) {
              items.add(_sectionHeader("NEW", unread.length));
              for (final alert in unread) {
                items.add(_buildDismissibleItem(alert, isRead: false));
              }
            }

            if (read.isNotEmpty) {
              items.add(_sectionHeader("EARLIER", read.length));
              for (final alert in read) {
                items.add(_buildDismissibleItem(alert, isRead: true));
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: items,
            );
          },
        ),
      ),
    );
  }

  Widget _noNotificationsWidget() {
    return Center(child: Image.asset(noNotif, scale: 3.5));
  }
}
