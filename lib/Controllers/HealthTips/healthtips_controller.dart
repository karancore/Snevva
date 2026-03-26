import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:snevva/consts/consts.dart';

import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class HealthTipsController extends GetxService {
  static const int _pageSize = 8;

  /// ✅ Reactive variables
  var generalTips = <dynamic>[];
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;
  dynamic randomTip; // can be null

  var isLoading = true.obs;
  var hasError = false.obs;
  var isLoadingMore = false.obs;
  var hasMoreData = true.obs;
  int pageIndex = 1;

  final ScrollController scrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels >= position.maxScrollExtent - 200) {
      GetCustomHealthTips(loadMore: true);
    }
  }

  // @override
  // void onInit() {
  //   super.onInit();
  //   loadAllHealthTips();
  // }

  Future<void> loadAllHealthTips(BuildContext context) async {
    isLoading.value = true;
    hasError.value = false;
    try {
      await GetGeneralhealthtips(context);
      await GetCustomHealthTips();
    } catch (e) {
      hasError.value = true;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load health tips',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> GetGeneralhealthtips(BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'Tags': ["Health Tips", "General"],
        'FetchAll': false,
        'Count': _pageSize,
        'Index': 1,
      };

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load general tips: ${response.statusCode}',
        );
        generalTips = [];
        randomTip = null;
        return;
      }

      final parsedData = jsonDecode(jsonEncode(response));
      generalTips = List<dynamic>.from(parsedData['data'] ?? []);

      // ✅ Check if list has elements before picking random
      if (generalTips.isNotEmpty) {
        final random = Random();
        randomTip = generalTips[random.nextInt(generalTips.length)];
      } else {
        randomTip = null;
      }
    } catch (e) {
      generalTips = <dynamic>[];
      randomTip = null;
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load general tips',
      );
    }
  }

  Future<void> GetCustomHealthTips({bool loadMore = false}) async {
    if (loadMore && (isLoadingMore.value || !hasMoreData.value)) return;

    final targetPage = loadMore ? pageIndex + 1 : 1;
    if (loadMore) {
      isLoadingMore.value = true;
    } else {
      hasMoreData.value = true;
      pageIndex = 1;
      isLoading.value = true;
      hasError.value = false;
      customTips.clear();
      randomTips.clear();
    }

    try {
      List<String> tags = ['Health Tips'];
      debugPrint("call2");

      final localStorageManager = Get.find<LocalStorageManager>();
      final day = localStorageManager.userMap['DayOfBirth'];
      final month = localStorageManager.userMap['MonthOfBirth'];
      final year = localStorageManager.userMap['YearOfBirth'];

      // final bmitext = prefs.getString('bmi_text');
      // final activitylevel = prefs.getString('ActivityLevel');
      // final healthgoal = prefs.getString('HealthGoal');
      final storedGender = localStorageManager.userMap['Gender'];

      // if (bmitext != null && bmitext.isNotEmpty) tags.add(bmitext);
      // if (activitylevel != null && activitylevel.isNotEmpty) tags.add(activitylevel);
      // if (healthgoal != null && healthgoal.isNotEmpty) tags.add(healthgoal);
      if (storedGender != null && storedGender.toString().isNotEmpty) {
        tags.add(storedGender);
      }

      if (day != null && month != null && year != null) {
        DateTime today = DateTime.now();
        DateTime birthDate = DateTime(year, month, day);
        int age = today.year - birthDate.year;
        if (today.month < birthDate.month ||
            (today.month == birthDate.month && today.day < birthDate.day)) {
          age--;
        }
        if (age >= 13 && age <= 18) {
          tags.add("Age 13 to 18");
        } else if (age >= 19 && age <= 25) {
          tags.add("Age 19 to 25");
        } else if (age > 25 && age <= 60) {
          tags.add("Age 25 to 60");
        }
      }
      // debugPrint(localStorageManager.userGoalDataMap['HeightData']['Value']);
      // debugPrint(tags);
      final payload = {
        'Tags': tags,
        'FetchAll': false,
        'Count': _pageSize,
        'Index': targetPage,
      };

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final parsedData = jsonDecode(jsonEncode(response));
      final fetchedTips = List<dynamic>.from(parsedData['data'] ?? []);

      if (fetchedTips.isEmpty) {
        hasMoreData.value = false;
        return;
      }

      pageIndex = targetPage;
      if (loadMore) {
        customTips.addAll(fetchedTips);
        randomTips.addAll(fetchedTips);
      } else {
        customTips.assignAll(fetchedTips);
        randomTips.assignAll(fetchedTips);
      }
      if (fetchedTips.length < _pageSize) {
        hasMoreData.value = false;
      }
    } catch (e) {
      if (!loadMore) {
        customTips.clear();
        randomTips.clear();
      }
      hasError.value = true;
      debugPrint('Error fetching custom health tips: $e');
    } finally {
      if (loadMore) {
        isLoadingMore.value = false;
      } else {
        isLoading.value = false;
      }
    }
  }

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    super.onClose();
  }
}
