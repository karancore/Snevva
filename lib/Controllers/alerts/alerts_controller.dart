import 'dart:convert';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/models/alerts.dart';
import 'package:snevva/services/notification_service.dart';
import '../../common/global_variables.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../models/app_notification.dart';
import '../../services/api_service.dart';

class AlertsController extends GetxService {
  RxList<Alerts> notifications = <Alerts>[].obs;
  static const deletedKey = 'deleted_notifications';

  final RxSet<String> deletedCodes = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    // _loadNotifications();
    _loadDeletedNotifications();
  }

  Future<void> _loadDeletedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(deletedKey) ?? [];

    deletedCodes.clear();
    deletedCodes.addAll(stored);
  }

  Future<void> markAsDeleted(String code) async {
    deletedCodes.add(code);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(deletedKey, deletedCodes.toList());
  }

  Future<List<Alerts>> hitAlertsNotifications() async {
    try {
      final response = await ApiService.post(
        alertsnotification,
        null,
        withAuth: true,
        encryptionRequired: true,
      );

      final decoded = jsonDecode(jsonEncode(response));
      final responseModel = AlertsResponse.fromJson(decoded);

      var activeAlerts = responseModel.alerts.where((a) => a.isActive).toList();
      final Map<String, Alerts> uniqueMap = {};
      for (var alert in activeAlerts) {
        uniqueMap[alert.dataCode] = alert;
      }

      final filtered =
          responseModel.alerts
              .where((alert) => !deletedCodes.contains(alert.dataCode))
              .toList();

      notifications.assignAll(filtered);

      return filtered;
    } catch (e) {
      debugPrint("❌ error: $e");
      return [];
    }
  }

  Future<void> scheduleAllAlerts(List<Alerts> alerts) async {
    final notificationService = NotificationService();
    await notificationService.notificationsPlugin.cancelAll();
    for (final alert in alerts) {
      for (final timeString in alert.times) {
        final parsed = parse24Hour(timeString);
        final id = generateNotificationId(alert.dataCode, timeString);
        await notificationService.scheduleAlertNotification(
          id: id,
          title: alert.heading,
          body: alert.title,
          hour: parsed.hour,
          minute: parsed.minute,
        );
      }
    }
  }
}
