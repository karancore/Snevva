import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class OEMSettingsHelper {
  static const MethodChannel _channel = MethodChannel('com.coretegra.snevva/oem_settings');

  static Future<void> requestBackgroundPermissions() async {
    // Request Ignore Battery Optimizations
    final status = await Permission.ignoreBatteryOptimizations.request();

    // Check OEM and auto-redirect to Autostart screen if necessary
    try {
      final String manufacturer = await _channel.invokeMethod('getManufacturer');
      final String lower = manufacturer.toLowerCase();

      final aggressiveOEMs = ['xiaomi', 'redmi', 'poco', 'oppo', 'realme', 'oneplus', 'vivo', 'iqoo', 'huawei', 'honor', 'samsung'];
      
      if (aggressiveOEMs.any((oem) => lower.contains(oem))) {
        await _channel.invokeMethod('openAutostartSettings');
      }
    } catch (e) {
      print("Failed to invoke OEM settings channel: $e");
    }
  }
}
