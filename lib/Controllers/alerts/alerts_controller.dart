import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_notification.dart';

class AlertsController extends GetxService {
  final RxList<AppNotification> notifications = <AppNotification>[].obs;

  static const _storageKey = 'notifications_list';

  // @override
  // void onInit() {
  //   super.onInit();
  //   _loadNotifications();
  // }

  @override
  void onReady() {
    super.onReady();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(_storageKey);

    if (stored != null) {
      final List list = jsonDecode(stored);
      notifications.assignAll(
        list.map((e) => AppNotification.fromJson(e)).toList(),
      );
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(notifications.map((e) => e.toJson()).toList()),
    );
  }

  void addNotification(AppNotification notification) {
    notifications.insert(0, notification);
    _saveNotifications();
  }

  void clearNotifications() {
    notifications.clear();
    _saveNotifications();
  }
}
