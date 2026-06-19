import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';
import 'package:snevva/services/api_service.dart';

import '../../common/custom_snackbar.dart';
import '../../models/glucose_reading_model.dart';

class VitalsController extends GetxController {
  var bpm = 0.obs;
  var sys = 0.obs; // Observable for SYS
  var dia = 0.obs; // Observable for DIA
  var bloodGlucose = 0.obs; // Observable for BloodGlucose

  final glucoseController = TextEditingController();
  @override
  void onInit() {
    super.onInit();
    loadGlucoseReadings();
    loadVitalsFromLocalStorage(); // Load vitals when the controller is initialized
  }

  // Reactive list — GlucoseScreen rebuilds automatically via Obx
  final RxList<GlucoseReading> glucoseReadings = <GlucoseReading>[].obs;

  static const _prefKey = 'glucose_readings';

  @override
  void onClose() {
    glucoseController.dispose();
    super.onClose();
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> loadGlucoseReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_prefKey) ?? [];
    glucoseReadings.assignAll(
      raw.map((e) => GlucoseReading.fromJson(e)).toList(),
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefKey,
      glucoseReadings.map((r) => r.toJson()).toList(),
    );
  }

  // ── CRUD ─────────────────────────────────────────────────────────────────

  Future<void> addGlucoseReading(String level, String type) async {
    final reading = GlucoseReading(
      glucoseLevel: level,
      time: DateTime.now().toIso8601String(),
      type: type,
    );
    glucoseReadings.insert(0, reading); // newest first
    await _persist();
  }

  Future<void> deleteGlucoseReading(int index) async {
    glucoseReadings.removeAt(index);
    await _persist();
  }

  String getBpmStatus(int bpm) {
    if (bpm <= 0) return '';

    if (bpm < 40) return 'Low';
    if (bpm < 60) return 'Excellent';
    if (bpm < 80) return 'Good';
    if (bpm <= 100) return 'Normal';
    return 'High';
  }

  // Load vitals (BPM, SYS, DIA, BloodGlucose) from local storage when the app starts
  Future<void> loadVitalsFromLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    bpm.value = prefs.getInt('bpm') ?? 0; // Load BPM, default to 0 if not found
    sys.value = prefs.getInt('sys') ?? 0; // Load SYS, default to 0 if not found
    dia.value = prefs.getInt('dia') ?? 0; // Load DIA, default to 0 if not found
    bloodGlucose.value =
        prefs.getInt('bloodGlucose') ??
        0; // Load BloodGlucose, default to 0 if not found

    debugPrint(
      'Loaded BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}',
    );
  }

  // Save vitals (BPM, SYS, DIA, BloodGlucose) to local storage
  Future<void> saveVitalsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('bpm', bpm.value); // Save BPM
    await prefs.setInt('sys', sys.value); // Save SYS
    await prefs.setInt('dia', dia.value); // Save DIA
    await prefs.setBool('isFirstTime', false);

    debugPrint(
      'Vitals saved: BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}',
    );
  }

  Future<void> loadvitalsfromAPI({
    required int month,
    required int year,
  }) async {
    try {
      final payload = {"Month": month, "Year": year};

      final response = await ApiService.post(
        fetchBloodPressureHistory,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        debugPrint(
          'Error fetching vitals data: ${response.statusCode} - ${response.body}',
        );
        return;
      }

      final resbody = jsonDecode(jsonEncode(response));

      debugPrint('Vitals data fetched: $resbody');

      // Assuming the response structure is:
      // { "status": true, "statusType": "success", "message": "Create Success", "data": { "BloodPressureData": [...] } }

      if (resbody['status'] == true) {
        List bloodPressureData = resbody['data']['BloodPressureData'];

        int n = bloodPressureData.length;

        // Get the first blood pressure data item or any specific logic you need
        var latestRecord =
            bloodPressureData.isNotEmpty ? bloodPressureData[n - 1] : null;

        if (latestRecord != null) {
          // Map the response to your reactive variables
          bpm.value = latestRecord['HeartRate'] ?? 0;
          sys.value = latestRecord['SYS'] ?? 0;
          dia.value = latestRecord['DIA'] ?? 0;

          // Optional: You could also save these values to local storage here
          saveVitalsToLocalStorage();

          debugPrint(
            'Fetched and updated BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}',
          );
        }
      } else {
        debugPrint('Error: ${resbody['message']}');
      }
    } catch (e) {
      debugPrint('Error fetching vitals data: $e');
    }
  }

  // Function to update vitals and save to local storage
  Future<bool> submitVitals(
    BloodPressureData bloodPressureData,
    BuildContext context,
  ) async {
    try {
      // Update the values from the incoming data
      bpm.value = bloodPressureData.heartRate?.toInt() ?? 0;
      sys.value = bloodPressureData.sys?.toInt() ?? 0;
      dia.value = bloodPressureData.dia?.toInt() ?? 0;
      bloodGlucose.value = bloodPressureData.bloodGlucose?.toInt() ?? 0;

      debugPrint(
        'Updated BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}',
      );

      // Save the updated vitals to local storage
      saveVitalsToLocalStorage();

      // Prepare payload for API request
      Map<String, dynamic> payload = {
        'HeartRate': bloodPressureData.heartRate,
        'SYS': bloodPressureData.sys,
        'DIA': bloodPressureData.dia,
        'BloodGlucose': bloodPressureData.bloodGlucose,
        'Day': bloodPressureData.day,
        'Month': bloodPressureData.month,
        'Year': bloodPressureData.year,
        'Time': bloodPressureData.time,
      };

      // Send data to the API service
      final response = await ApiService.post(
        bloodpressure,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      // Handle response
      if (response is http.Response) {
        debugPrint("Error submitting vitals: ${response.body}");
        return false;
      }

      // On success, show success message
      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Vitals record saved successfully!',
      );
      return true;
    } catch (e, st) {
      // Handle error and show error message
      debugPrint("Error submitting vitals: $e");
      debugPrint("Stack Trace for vitals $st");

      return false;
    }
  }

  // ── Blood Glucose Submit ──────────────────────────────────────────────────

  Future<bool> submitBloodGlucose({
    required double glucoseValue,
    required String type, // 'Fasting', 'Post Meal', 'Random'
    required BuildContext context,
  }) async {
    try {
      // Validate range (mmol/L: 1.0 – 33.3)
      // if (glucoseValue < 1.0 || glucoseValue > 33.3) {
      //   CustomSnackbar.showError(
      //     context: context,
      //     title: 'Invalid Value',
      //     message: 'Glucose must be between 1.0 and 33.3 mmol/L.',
      //   );
      //   return false;
      // }

      // 1️⃣ Save locally in the readings list (persisted via SharedPreferences)
      await addGlucoseReading(glucoseValue.toString(), type);

      // 2️⃣ Update reactive var so other screens react
      bloodGlucose.value = glucoseValue.toInt();

      // 3️⃣ Persist bloodGlucose scalar separately (for VitalScreen tile etc.)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bloodGlucose', bloodGlucose.value);

      debugPrint('Blood Glucose submitted: $glucoseValue mmol/L [$type]');

      // 4️⃣ Hit the API
      final now = DateTime.now();

      // Map display label → API value
      final typeMap = {
        'Fasting': 'Fasting',
        'Post Meal': 'PostMeal',
        'Random': 'Random',
      };

      final payload = {
        'BloodGlucose': glucoseValue,
        'TypeOfSugar': typeMap[type] ?? type,
        'Day': now.day,
        'Month': now.month,
        'Year': now.year,
        'Time': now.toIso8601String(),
      };

      debugPrint('API payload: $payload');

      try {
        final response = await ApiService.post(
          bloodglucoseapi,
          payload,
          withAuth: true,
          encryptionRequired: true,
        );
        if (response is http.Response) {
          debugPrint('API sync failed, but saved locally');
        }
      } catch (e) {
        debugPrint('API error: $e');
      }
      return true;

    } catch (e) {
      debugPrint('submitBloodGlucose error: $e');
      // CustomSnackbar.showError(
      //   context: context,
      //   title: 'Error',
      //   message: 'Failed to save blood glucose record.',
      // );
      return false;
    }
  }
}
