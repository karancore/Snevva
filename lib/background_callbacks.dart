import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

@pragma('vm:entry-point')
void startSleepTrackingTask() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();
  await service.startService();
}

@pragma('vm:entry-point')
void stopSleepTrackingTask() async {
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();
  service.invoke('stopService');
}
