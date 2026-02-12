import 'dart:convert';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../common/global_variables.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../models/app_notification.dart';
import '../../services/api_service.dart';

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

  Future<void> loadAlerts() async {
    debugPrint(" Loading alerts...");

    try {
      final payload = {
        'Tags': ['General'],
        'FetchAll': true,
        'Count': 0,
        'Index': 0,
      };

      final response = await ApiService.post(
        genralmusicAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint("❌ HTTP error: ${response.statusCode}");
        return null;
      }

      final decoded = jsonDecode(jsonEncode(response));

      debugPrint("🔍 General Music Raw JSON: $decoded");

    } catch (e, s) {
      debugPrint("❌ loadGeneralMusic() error: $e");
      debugPrintStack(stackTrace: s);

      return null;
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
