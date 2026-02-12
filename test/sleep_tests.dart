import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:snevva/Controllers/SleepScreen/sleep_controller.dart';

// ══════════════════════════════════════════════════════════════════
// QUICK FIX VERSION - Minimal setup for immediate testing
// ══════════════════════════════════════════════════════════════════

void main() {
  // Initialize test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Initialize Hive with temp directory for tests
    final tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Set GetX to test mode
    Get.testMode = true;
  });

  tearDownAll(() async {
    await Hive.close();
  });
}
