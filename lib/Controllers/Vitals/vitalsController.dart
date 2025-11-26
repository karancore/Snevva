import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

class VitalsController extends GetxController {
  var bpm = 0.obs;
  var sys = 0.obs;  // Observable for SYS
  var dia = 0.obs;  // Observable for DIA
  var bloodGlucose = 0.obs;  // Observable for BloodGlucose

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
    bloodGlucose.value = prefs.getInt('bloodGlucose') ?? 0; // Load BloodGlucose, default to 0 if not found
    
    print('Loaded BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}');
  }

  // Save vitals (BPM, SYS, DIA, BloodGlucose) to local storage
  Future<void> saveVitalsToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('bpm', bpm.value); // Save BPM
    await prefs.setInt('sys', sys.value); // Save SYS
    await prefs.setInt('dia', dia.value); // Save DIA
    await prefs.setInt('bloodGlucose', bloodGlucose.value); // Save BloodGlucose
    
    print('Vitals saved: BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}');
  }

  // Function to update vitals and save to local storage
  Future<bool> submitVitals(BloodPressureData bloodPressureData) async {
    try {
      // Update the values from the incoming data
      bpm.value = bloodPressureData.heartRate?.toInt() ?? 0;
      sys.value = bloodPressureData.sys?.toInt() ?? 0;
      dia.value = bloodPressureData.dia?.toInt() ?? 0;
      bloodGlucose.value = bloodPressureData.bloodGlucose?.toInt() ?? 0;

      print('Updated BPM: ${bpm.value}, SYS: ${sys.value}, DIA: ${dia.value}, BloodGlucose: ${bloodGlucose.value}');
      
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
        Get.snackbar(
          'Error',
          'Failed to save Vitals record: ${response.statusCode}',
        );
        return false;
      }

      // On success, show success message
      Get.snackbar('Success', 'Vitals record saved successfully!');
      return true;
    } catch (e) {
      // Handle error and show error message
      Get.snackbar('Error', 'Failed saving Vitals record');
      return false;
    }
  }
}
