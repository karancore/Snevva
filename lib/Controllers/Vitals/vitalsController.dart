import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

import '../../common/custom_snackbar.dart';

class VitalsController extends GetxController {
  var bpm = 0.obs;
  var sys = 0.obs; // Observable for SYS
  var dia = 0.obs; // Observable for DIA
  var bloodGlucose = 0.obs; // Observable for BloodGlucose

  @override
  void onInit() {
    super.onInit();
    loadVitalsFromLocalStorage(); // Load vitals when the controller is initialized
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

    print(
      'Loaded BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}',
    );
  }

  // Save vitals (BPM, SYS, DIA, BloodGlucose) to local storage
  Future<void> saveVitalsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('bpm', bpm.value); // Save BPM
    await prefs.setInt('sys', sys.value); // Save SYS
    await prefs.setInt('dia', dia.value); // Save DIA
    await prefs.setInt('bloodGlucose', bloodGlucose.value); // Save BloodGlucose

    print(
      'Vitals saved: BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}',
    );
  }

  Future<void> loadvitalsfromAPI({required int month, required int year}) async {
  try {
    final payload = {
      "Month": month,
      "Year": year,
    };

    final response = await ApiService.post(
      fetchBloodPressureHistory,
      payload,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response) {
      print(
        'Error fetching vitals data: ${response.statusCode} - ${response.body}',
      );
      return;
    }

    final resbody = jsonDecode(jsonEncode(response));

    print('Vitals data fetched: $resbody');

    // Assuming the response structure is:
    // { "status": true, "statusType": "success", "message": "Create Success", "data": { "BloodPressureData": [...] } }

    if (resbody['status'] == true) {
      List bloodPressureData = resbody['data']['BloodPressureData'];

      int n = bloodPressureData.length;

      // Get the first blood pressure data item or any specific logic you need
      var latestRecord = bloodPressureData.isNotEmpty ? bloodPressureData[n-1] : null;

      if (latestRecord != null) {
        // Map the response to your reactive variables
        bpm.value = latestRecord['HeartRate'] ?? 0;
        sys.value = latestRecord['SYS'] ?? 0;
        dia.value = latestRecord['DIA'] ?? 0;
        bloodGlucose.value = latestRecord['BloodGlucose'] ?? 0;

        // Optional: You could also save these values to local storage here
        saveVitalsToLocalStorage();

        print(
          'Fetched and updated BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}',
        );
      }
    } else {
      print('Error: ${resbody['message']}');
    }
  } catch (e) {
    print('Error fetching vitals data: $e');
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

      print(
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
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Vitals record: ${response.statusCode}',
        );
        return false;
      }

      // On success, show success message
      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Vitals record saved successfully!',
      );
      return true;
    } catch (e) {
      // Handle error and show error message
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving Vitals record',
      );
      return false;
    }
  }
}
