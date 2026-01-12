import 'dart:convert';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/day_symptoms.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

class BottomSheetController extends GetxController {
  var pageIndex = 0.obs;

  final RxSet<String> selectedSymptoms = <String>{}.obs;

  final Rx<DateTime> selectedDate = DateTime.now().obs;

  final RxList<String> symptoms = <String>[].obs;
  final RxString note = ''.obs;

  final RxMap<DateTime, DaySymptoms> symptomsByDate =
      <DateTime, DaySymptoms>{}.obs;

  /// 🔹 Set the selected date and load symptoms/note
  void setSelectedDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    selectedDate.value = key;

    final dayData = symptomsByDate[key];

    print("Selected date: $key, Data: $dayData");

    if (dayData != null) {
      symptoms.value = List.from(dayData.symptoms);
      note.value = dayData.note;
    } else {
      symptoms.clear();
      note.value = '';
    }
  }

  /// 🔹 Update symptoms & note locally
  void updateSymptoms({
    required List<String> newSymptoms,
    required String newNote,
  }) {
    symptoms.value = List.from(newSymptoms);
    note.value = newNote;

    // Update the map
    symptomsByDate[selectedDate.value] = DaySymptoms(
      date: selectedDate.value,
      symptoms: newSymptoms,
      note: newNote,
    );

    saveSymptomsToPrefs();
  }

  /// 🔹 Load symptoms from SharedPreferences
  Future<void> loadSymptomsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('women_symptoms');
    if (raw == null) return;

    final List decoded = jsonDecode(raw);
    final map = <DateTime, DaySymptoms>{};

    for (final item in decoded) {
      final data = DaySymptoms.fromJson(item);
      map[data.date] = data;
    }

    symptomsByDate.value = map;
  }

  /// 🔹 Load Women Health data from API
  Future<void> loaddatafromAPI() async {
    try {
      final response = await ApiService.post(
        fetchWomenhealthHistory,
        null,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to load Women Health Data: ${response.statusCode}',
        );
        return;
      }

      final parsedData = jsonDecode(jsonEncode(response));
      final data = parsedData['data'];
      final List<dynamic> apiSymptoms =
          data['WomenHealthData']?['SymptomsData'] ?? [];

      print("✅ Women Health Data loaded successfully: $data");
      print("✅ Symptoms Data loaded successfully: $apiSymptoms");

      final Map<DateTime, DaySymptoms> tempMap = {};

      for (final item in apiSymptoms) {
        final date = DateTime(item['Year'], item['Month'], item['Day']);
        final List<String> daySymptoms = List<String>.from(
          item['Symptoms'] ?? [],
        );
        final String dayNote = item['Note'] ?? '';

        if (tempMap.containsKey(date)) {
          // Merge symptoms
          final mergedSymptoms =
              {...tempMap[date]!.symptoms, ...daySymptoms}.toList();
          final mergedNote = dayNote.isNotEmpty ? dayNote : tempMap[date]!.note;

          tempMap[date] = DaySymptoms(
            date: date,
            symptoms: mergedSymptoms,
            note: mergedNote,
          );

          print("Merging symptoms for date $date: ${tempMap[date]!.symptoms}");
        } else {
          tempMap[date] = DaySymptoms(
            date: date,
            symptoms: daySymptoms,
            note: dayNote,
          );
        }
      }

      symptomsByDate.value = tempMap;
      await saveSymptomsToPrefs();
    } catch (e) {
      print(e);
      CustomSnackbar.showError(
        context: Get.context!,
        title: 'Error',
        message: 'Failed loading Women Health Data',
      );
    }
  }

  /// 🔹 Save symptoms to SharedPreferences
  Future<void> saveSymptomsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = symptomsByDate.values.map((e) => e.toJson()).toList();
    prefs.setString('women_symptoms', jsonEncode(jsonList));
  }

  /// 🔹 Navigate pages
  void nextPage(int totalPages) {
    if (pageIndex.value < totalPages - 1) {
      pageIndex.value++;
    } else {
      Get.back();
    }
  }

  /// 🔹 Toggle selected symptom
  void toggleSymptom(String symptom) {
    if (selectedSymptoms.contains(symptom)) {
      selectedSymptoms.remove(symptom);
    } else {
      selectedSymptoms.add(symptom);
    }
  }

  /// 🔹 Add symptoms to API
  Future<void> addsymptoAPI(List<String> symptoms, String note) async {
    try {
      
      final payload = {
        'Day': selectedDate.value.day,
        'Month': selectedDate.value.month,
        'Year': selectedDate.value.year,
        'Symptoms': symptoms,
        'Note': note,
      };

      print("Payload: $payload");

      final response = await ApiService.post(
        periodsymptomps,
        payload,
        encryptionRequired: true,
        withAuth: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to update period data',
        );
        return;
      }

      updateSymptoms(newSymptoms: symptoms, newNote: note);
    } catch (e) {
      CustomSnackbar.showError(
        context: Get.context!,
        title: 'Error',
        message: 'An error occurred while updating period data',
      );
    }
  }
}
