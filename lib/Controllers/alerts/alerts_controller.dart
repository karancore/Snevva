import 'dart:convert';
import 'package:get/get_connect/http/src/response/response.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/models/alerts.dart';
import 'package:snevva/services/notification_service.dart';
import '../../common/global_variables.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import 'package:get/get_connect/http/src/response/response.dart' as http;

class AlertsController extends GetxService {
  RxList<Alerts> notifications = <Alerts>[].obs;
  static const deletedKey = 'deleted_notifications';

  final RxSet<String> deletedCodes = <String>{}.obs;
  final RxSet<String> readCodes = <String>{}.obs;
  final bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    // _loadNotifications();
    // _loadDeletedNotifications();
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

      final Map<String, Alerts> uniqueMap = {};
      for (var alert in responseModel.alerts.where((a) => a.isActive)) {
        uniqueMap[alert.dataCode] = alert;
      }

      final filtered =
          uniqueMap.values
              .where((alert) => !deletedCodes.contains(alert.dataCode))
              .toList();

      notifications.assignAll(filtered);

      return filtered;
    } catch (e) {
      debugPrint("❌ error: $e");
      return [];
    }
  }

  List<Alerts> get unreadNotifications =>
      notifications.where((a) => !readCodes.contains(a.id)).toList(); // ✅

  List<Alerts> get readNotifications_ =>
      notifications.where((a) => readCodes.contains(a.id)).toList(); // ✅
  Future<void> readNotifications(String id) async {
    try {

      debugPrint("🚀 readNotifications() called");

      final payload = {
        "DataCode": id
      };

      final response = await ApiService.post(
        dnd,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint(
          "❌ HTTP ${response.statusCode}",
        );

        return;
      }

    } catch (e, stackTrace) {
      debugPrint("❌ Error: $e");
      debugPrint("$stackTrace");
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
