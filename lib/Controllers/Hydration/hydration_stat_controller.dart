import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/water_goal_vm.dart';
import 'package:snevva/services/api_service.dart';
import '../../common/custom_snackbar.dart';
import '../../common/global_variables.dart';
import '../../models/water_history_model.dart';
import 'package:http/http.dart' as http;

class HydrationStatController extends GetxService {
  RxBool checkVisibility = false.obs;
  RxBool masterCheck = false.obs;
  var addWaterValue = 250.obs;
  RxDouble waterIntake = 0.0.obs;

  RxInt waterGoal = 2000.obs;

  RxList<WaterHistoryModel> waterHistoryList = <WaterHistoryModel>[].obs;
  final RxMap<String, int> waterHistoryByDate = <String, int>{}.obs;
  final RxList<FlSpot> waterSpots = <FlSpot>[].obs;
  var isLoading = true.obs;

  @override
  void onReady() {
    super.onReady();
    loadWaterIntake();
  }

  String getHydrationStatus(double intakeMl) {
    if (intakeMl <= 0) return '';

    if (intakeMl < 500) return 'Very Low';
    if (intakeMl < 1200) return 'Low';
    if (intakeMl < 2000) return 'Okay';
    if (intakeMl < 3000) return 'Good';
    return 'Amazing';
  }

  // Save water intake value locally
  Future<void> saveWaterIntakeLocally() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setDouble('waterIntake', waterIntake.value);
    print('💾 Water intake saved locally: ${waterIntake.value}');
    prefs.setString(
      'lastUpdatedDate',
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    print('💾 Water intake saved locally: ${waterIntake.value}');
  }

  Future<void> loadWaterIntake() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    double savedIntake = prefs.getDouble('waterIntake') ?? 0;
    print(savedIntake);
    String? lastUpdated = prefs.getString('lastUpdatedDate');
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastUpdated == today) {
      waterIntake.value = savedIntake;
      print("Restored today's water intake: ${waterIntake.value}");
    } else {
      waterIntake.value = 0;
      prefs.setDouble('waterIntake', 0.0);
      prefs.setString('lastUpdatedDate', today);
      print("🔄 New day detected, resetting water intake.");
    }
  }

  void toggleCheckVisibility() {
    checkVisibility.value = !checkVisibility.value;
  }

  void toggleCheckbox(int index, bool? value) {
    waterHistoryList[index].isChecked.value = value ?? false;
    updateMasterCheckbox();
  }

  void toggleMasterCheckbox(bool? value) {
    masterCheck.value = value ?? false;
    for (var item in waterHistoryList) {
      item.isChecked.value = masterCheck.value;
    }
  }

  /// Call this after any item checkbox is toggled
  void updateMasterCheckbox() {
    masterCheck.value = waterHistoryList.every(
      (item) => item.isChecked.value == true,
    );
  }

  void deleteSelectedItems() {
    waterHistoryList.removeWhere((item) => item.isChecked.value);
    updateMasterCheckbox(); // Update state after delete
  }

  int getWaterInMl(int value) {
    addWaterValue.value = value;
    return addWaterValue.value;
  }

  Future<void> updateWaterGoal(int value, BuildContext context) async {
    waterGoal.value = value;
    print("UPDATED GOAL = $value");
    print("RX VALUE = ${waterGoal.value}"); // Update water goal
    await saveWatergoal(
      WaterGoalVM(
        day: DateTime.now().day,
        month: DateTime.now().month,
        year: DateTime.now().year,
        time: TimeOfDay.now().format(Get.context!),
        value: value,
      ),
      context,
    );
  }

  List<FlSpot> getMonthlyWaterSpots(DateTime month) {


    final int totalDays =
        (month.year == now.year && month.month == now.month)
            ? now
                .day // only till today
            : DateTime(month.year, month.month + 1, 0).day;

    List<FlSpot> spots = [];

    for (int day = 1; day <= totalDays; day++) {
      final key = "${month.year}-${month.month}-$day";
      final ml = waterHistoryByDate[key] ?? 0;

      spots.add(FlSpot((day - 1).toDouble(), ml / 1000));
    }

    return spots;
  }

  Future<void> saveWatergoal(WaterGoalVM water, BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Day': water.day,
        'Month': water.month,
        'Year': water.year,
        'Time': water.time,
        'Value': water.value,
      };
      final response = await ApiService.post(
        waterGoalfinal,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Water goal: ${response.statusCode}',
        );
        return;
      }

      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: 'Water goal saved successfully!',
      );

      print("Water goal saved successfully");
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving Water goal',
      );
    }
  }

  Future<void> saveWaterRecord(int count, BuildContext context) async {
    try {

      final payload = {
        "Day": now.day,
        "Month": now.month,
        "Year": now.year,
        "Time": TimeOfDay.now().format(Get.context!),
        "Value": count,
      };

      // Optimistically add to local list and update graph
      final newRecord = WaterHistoryModel(
        day: now.day,
        month: now.month,
        year: now.year,
        time: TimeOfDay.now().format(Get.context!),
        value: count,
      );
      waterHistoryList.add(newRecord);
      buildWaterHistoryMap();

      final response = await ApiService.post(
        waterRecord,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save Water record: ${response.statusCode}',
        );
      } else {
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Water record saved successfully',
        );
      }
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Exception while saving Water record',
      );
    }
  }

  void calculateTodayIntakeFromList(List intakeList) {


    int todayTotal = 0;

    for (var item in intakeList) {
      if (item['Day'] == now.day &&
          item['Month'] == now.month &&
          item['Year'] == now.year) {
        todayTotal += (item['Value'] as int);
      }
    }

    waterIntake.value = todayTotal.toDouble();

    print("Calculated today's water intake: ${waterIntake.value} ml");
  }

  Future<void> loadWaterIntakefromAPI({
    required int month,
    required int year,
  }) async {
    try {
      isLoading.value = true;

      final payload = {"Month": month, "Year": year};

      final response = await ApiService.post(
        waterrecords,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response && response.statusCode >= 400) {
        CustomSnackbar.showError(
          context: Get.context!,
          title: 'Error',
          message: 'Failed to fetch Water records: ${response.statusCode}',
        );
        return;
      }

      final resbody = jsonDecode(jsonEncode(response));
      print("Water records fetched: $resbody");

      // Safely access WaterGoalData
      final waterGoalData = resbody['data']['WaterGoalData'];
      if (waterGoalData != null && waterGoalData['Value'] != null) {
        waterGoal.value = waterGoalData['Value'];
      } else {
        waterGoal.value = 0; // or keep previous value, or handle as needed
      }

      // WaterIntakeData is a List, not a Map with 'Value'
      final intakeList = resbody['data']['WaterIntakeData'] ?? [];

      waterHistoryList.clear();

      for (var item in intakeList) {
        DateTime intakeTime = DateFormat('h:mm a').parse(item['Time']);
        waterHistoryList.add(WaterHistoryModel.fromJson(item));
      }
      for (var water in waterHistoryList) {
        print(water.value);
      }

      calculateTodayIntakeFromList(intakeList);

      await saveWaterIntakeLocally();

      print("Fetched ${waterHistoryList.length} Water records");
      buildWaterHistoryMap();
    } catch (e) {
      print("Error fetching water records: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void buildWaterHistoryMap() {
    waterHistoryByDate.clear();
    for (final item in waterHistoryList) {
      final key = "${item.year}-${item.month}-${item.day}";
      waterHistoryByDate.update(
        key,
        (v) => v + (item.value ?? 0),
        ifAbsent: () => item.value ?? 0,
      );
    }
    // syncTodayIntakeFromMap();
    updateWaterSpots();
  }

  void syncTodayIntakeFromMap() {
    final key = DateFormat('yyyy-MM-dd').format(DateTime.now());
    waterIntake.value = (waterHistoryByDate[key] ?? 0).toDouble();
  }

  void updateWaterSpots() {
    waterSpots.clear();
    DateTime now = DateTime.now();
    // Monday = 1, Sunday = 7. Find Monday of current week.
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));

    for (int i = 0; i < 7; i++) {
      DateTime date = monday.add(Duration(days: i));
      String key = "${date.year}-${date.month}-${date.day}";
      int ml = waterHistoryByDate[key] ?? 0;
      waterSpots.add(FlSpot(i.toDouble(), ml / 1000.0));
    }
  }
}
