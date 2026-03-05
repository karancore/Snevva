import 'dart:convert';
import 'package:snevva/consts/consts.dart';
import 'package:http/http.dart' as http;
import '../../common/custom_snackbar.dart';
import '../../env/env.dart';
import '../../services/api_service.dart';
import '../local_storage_manager.dart';

class BmiController extends GetxService {
  static const int _pageSize = 8;

  RxInt age = 0.obs;
  RxString bmi_text = "Great-Shape".obs;
  var customTips = <dynamic>[].obs;
  var randomTips = <dynamic>[].obs;

  final RxDouble height = 0.0.obs; // in cm
  final RxDouble weight = 0.0.obs; // in kg
  final RxDouble bmi = 0.0.obs;

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

  Future<void> loadUserBMI() async {
    // // final prefs = await SharedPreferences.getInstance();
    // final savedHeight = prefs.getDouble('height') ?? 0.0; // cm
    // final savedWeight = prefs.getDouble('weight') ?? 0.0; // kg

    final localStorageManager = Get.find<LocalStorageManager>();
    final savedHeight =
        localStorageManager.userGoalDataMap['HeightData'] != null
            ? double.tryParse(
                  localStorageManager.userGoalDataMap['HeightData']['Value']
                      .toString(),
                ) ??
                0.0
            : 0.0;
    final savedWeight =
        localStorageManager.userGoalDataMap['WeightData'] != null
            ? double.tryParse(
                  localStorageManager.userGoalDataMap['WeightData']['Value']
                      .toString(),
                ) ??
                0.0
            : 0.0;

    height.value = savedHeight;
    weight.value = savedWeight;

    print('Loaded Height: ${height.value} cm, Weight: ${weight.value} kg');

    if (height.value > 0 && weight.value > 0) {
      final heightInMeters = height.value / 100;
      bmi.value = double.parse(
        (weight.value / (heightInMeters * heightInMeters)).toStringAsFixed(2),
      );

      if (bmi.value < 18.5) {
        bmi_text.value = "Underweight";
      } else if (bmi.value >= 18.5 && bmi.value < 24.9) {
        bmi_text.value = "Great-Shape";
      } else if (bmi.value >= 25 && bmi.value < 29.9) {
        bmi_text.value = "Overweight";
      } else {
        bmi_text.value = "Obese";
      }
    }

    print('Calculated BMI: ${bmi.value}');
  }

  void _loadMockData() {
    isLoading.value = true;
    hasError.value = false;

    try {
      customTips.assignAll([
        {
          "Id": 10,
          "Heading": "Healthy Eating",
          "Title": "Fuel your body with balanced meals and leafy greens.",
          "ShortDescription":
              "Nourish your body with whole foods and nutrient-rich meals.",
          "ThumbnailMedia": {
            "CdnUrl":
                "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
          },
          "Steps": [
            "Add vegetables to every meal.",
            "Limit processed and sugary foods.",
            "Choose whole grains over refined carbs.",
          ],
        },
        {
          "Id": 11,
          "Heading": "Sleep Well",
          "Title": "Aim for 7–9 hours of sleep for better mood and focus.",
          "ShortDescription":
              "Quality sleep helps regulate hormones, memory, and recovery.",
          "ThumbnailMedia": {
            "CdnUrl":
                "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
          },
          "Steps": [
            "Stick to a consistent sleep schedule.",
            "Avoid screens at least 30 minutes before bed.",
            "Create a relaxing bedtime routine.",
          ],
        },
        {
          "Id": 12,
          "Heading": "Mental Health",
          "Title": "Take regular breaks and manage stress mindfully.",
          "ShortDescription":
              "Taking care of your mental well-being is just as important as physical health.",
          "ThumbnailMedia": {
            "CdnUrl":
                "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
          },
          "Steps": [
            "Practice deep breathing or meditation for 5 minutes.",
            "Go for a short walk during work breaks.",
            "Talk to a friend or journal your thoughts.",
          ],
        },
      ]);

      final List<dynamic> allTips = List.from(customTips);
      allTips.shuffle();
      randomTips.assignAll(allTips.take(2).toList());
    } catch (e) {
      hasError.value = true;
      randomTips.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAllHealthTips(BuildContext context) async {
    isLoading.value = true;
    hasError.value = false;
    try {
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

  Future<void> GetCustomHealthTips({bool loadMore = false}) async {
    if (loadMore && (isLoadingMore.value || !hasMoreData.value)) return;

    final targetPage = loadMore ? pageIndex + 1 : 1;
    if (loadMore) {
      isLoadingMore.value = true;
    } else {
      hasMoreData.value = true;
      pageIndex = 1;
      customTips.clear();
      randomTips.clear();
    }

    try {
      List<String> tags = ['BMI', bmi_text.value];
      if (age.value >= 13 && age.value <= 18) {
        tags.add("Age 13 to 18");
      } else if (age.value >= 19 && age.value <= 25) {
        tags.add("Age 19 to 25");
      } else if (age.value > 25 && age.value <= 60) {
        tags.add("Age 25 to 60");
      }
      // print(localStorageManager.userGoalDataMap['HeightData']['Value']);
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
