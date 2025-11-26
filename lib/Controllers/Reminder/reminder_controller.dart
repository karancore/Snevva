import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';

class ReminderController extends GetxController {
  // Define your variables and controllers here
  final titleController = TextEditingController();
  final medicineController = TextEditingController();
  final timeController = TextEditingController();
  final notesController = TextEditingController();
  
  String selectedCategory = 'Medicine'; // Example default value
  DateTime? startDate;
  DateTime? endDate;
  
  int waterReminderOption = 0; // 0 for every X hours, 1 for Y times a day
  final everyHourController = TextEditingController();
  final timesPerDayController = TextEditingController();
  
  bool enableNotifications = true;
  bool soundVibrationToggle = true;

  // var reminders = <ReminderModel>[].obs;
 var reminders = <Map<String, dynamic>>[].obs;  // Observable list of maps

  var isLoading = false.obs;

  

  @override
  void onInit() {
    super.onInit();
    getReminders(); // Load data on init
  }

  Future<void> getReminders() async {
    try {
      isLoading(true);
      var result = await getReminder(); // Replace with your actual service
      var reminders = result as List<Map<String, dynamic>>;
      this.reminders.assignAll(reminders);
      // print(result);
      print(reminders);
    } catch (e) {
      print("Error fetching reminders");
      // Optionally show error message with Get.snackbar or similar
    } finally {
      isLoading(false);
    }
  }

  @override
  void onClose() {
    titleController.dispose();
    medicineController.dispose();
    timeController.dispose();
    notesController.dispose();
    everyHourController.dispose();
    timesPerDayController.dispose();
    super.onClose();
  }

Future<void> addReminder(Map<String, dynamic> reminderData) async {

 try {
  
    final response = await ApiService.post(
      addreminderApi,
      reminderData,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response && response.statusCode >= 400) {
      Get.snackbar('Error','❌ Failed to save Reminder record: ${response.statusCode}');
    } else {
      // Get.snackbar('Success','✅ Reminder record saved successfully');
      // Get.offAll(Reminder());
      // Navigator.pop(context);
      getReminders(); // Refresh the list after adding a new reminder

    }
  } catch (e) {
    Get.snackbar('Error','❌ Exception while saving Reminder record');
  }

}


Future <dynamic> getReminder() async {
  try {
    final response = await ApiService.post(
      getreminderApi,
      null,
      withAuth: true,
      encryptionRequired: false,
    );
    // print(response);

    if (response is http.Response && response.statusCode >= 400) {
      Get.snackbar('Error', '❌ Failed to fetch reminders: ${response.statusCode}');
      return [];
    } 

    final enc = jsonEncode(response);
    final decbody = jsonDecode(enc);
    // print(decbody['data']['Reminders']);
    final List remindersList = decbody['data']['Reminders'] as List;
    return remindersList.map((e) => e as Map<String, dynamic>).toList();
  } catch (e) {
    Get.snackbar('Error', '❌ Exception while fetching reminders');
    return [];
  }
}

Future<void> updateReminder(Map<String, dynamic> reminderData) async {
 try {
  
    final response = await ApiService.post(
      editreminderApi,
      reminderData,
      withAuth: true,
      encryptionRequired: true,
    );

    if (response is http.Response && response.statusCode >= 400) {
      Get.snackbar('Error','❌ Failed to update Reminder record: ${response.statusCode}');
    } else {
      // Get.snackbar('Success','✅ Reminder record updated successfully');
      // Get.offAll(Reminder());
      // Navigator.pop(context);
      getReminders(); // Refresh the list after update

    }
  } catch (e) {
    Get.snackbar('Error','❌ Exception while updating Reminder record');
  }
}
}