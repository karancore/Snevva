import 'app_initializer.dart';

class TrackingServiceManager {
  TrackingServiceManager._();

  static final TrackingServiceManager instance = TrackingServiceManager._();

  Future<void> start() async {
    await createServiceNotificationChannel();
    await initBackgroundService();
  }
}
