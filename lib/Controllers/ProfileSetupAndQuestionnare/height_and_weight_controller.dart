import 'package:http/http.dart' as http;
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/height_vm.dart';
import 'package:snevva/models/queryParamViewModels/weight_vm.dart';
import 'package:snevva/services/api_service.dart';

import '../../views/ProfileAndQuestionnaire/questionnaire_screen.dart';

class HeightWeightController extends GetxController {
  // height

  RxDouble heightInCm = 140.0.obs;

  double get heightInFeet => heightInCm.value / 30.48;

  int get feet => (heightInCm.value / 30.48).floor();

  int get inches {
    final remainingCm = heightInCm.value - (feet * 30.48);
    final inch = (remainingCm / 2.54).round();
    if (inch == 12) {
      return 0;
    }
    return inch;
  }

  int get correctedFeet {
    final remainingCm = heightInCm.value - (feet * 30.48);
    final inch = (remainingCm / 2.54).round();
    if (inch == 12) {
      return feet + 1;
    }
    return feet;
  }

  final localStorageManager = Get.find<LocalStorageManager>();

  void updateFromFeet(double feet) {
    // Snap to nearest inch to avoid "5.999" floating point issues
    // Convert feet (e.g. 5.3) to total inches (63.6), round to nearest whole inch (64)
    final totalInches = (feet * 12).round();
    // distinct inches = 64. Convert back to CM
    final cm = totalInches * 2.54;
    heightInCm.value = cm;
  }

  void updateFromCm(double cm) {
    heightInCm.value = cm;
  }


  var weightInKg = 0.0.obs;

  void setWeight(double weightValue) {
    weightInKg.value = weightValue;
  }

  Future<void> saveData(
    HeightVM height,
    WeightVM weight,
    BuildContext context,
  ) async {
    debugPrint('🟢 saveData() CALLED');

    if(height.value == null || weight.value == null) {
      debugPrint('⚠️ Height or Weight value is null. Aborting save.');
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Height and Weight values cannot be null.',
      );
      return;
    }
    if(height.value! <= 0 || weight.value! <= 0) {
      debugPrint('⚠️ Height or Weight value is non-positive. Aborting save.');
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Height and Weight values must be greater than zero.',
      );
      return;
    }

    try {
      debugPrint('📥 Incoming HeightVM: ${height.toString()}');
      debugPrint('📥 Incoming WeightVM: ${weight.toString()}');

      final heightValue = (height.value ?? 0).toDouble();
      final weightValue = (weight.value ?? 0).toDouble();

      debugPrint('📏 heightValue: $heightValue');
      debugPrint('⚖️ weightValue: $weightValue');

      /// -----------------------------
      /// LOCAL STORAGE DEBUG + FIX
      /// -----------------------------
      debugPrint(
        '🗂.userGoalDataMap BEFORE init: ${localStorageManager.userGoalDataMap}',
      );

      // Ensure base map
      localStorageManager.userGoalDataMap.value ??= {};
      debugPrint('✅.userGoalDataMap initialized');

      // Ensure Height map
      localStorageManager.userGoalDataMap['HeightData'] ??= {};
      debugPrint('✅ Height map initialized');

      // Ensure Weight map
      localStorageManager.userGoalDataMap['WeightData'] ??= {};
      debugPrint('✅ Weight map initialized');

      // Save values
      localStorageManager.userGoalDataMap['HeightData']['Value'] = double.parse(
        heightValue.toStringAsFixed(2),
      );

      localStorageManager.userGoalDataMap['WeightData']['Value'] = double.parse(
        weightValue.toStringAsFixed(2),
      );

      debugPrint(
        '💾.userGoalDataMap AFTER save: ${localStorageManager.userGoalDataMap}',
      );

      // Sync controller state
      heightInCm.value = heightValue;
      weightInKg.value = weightValue;

      debugPrint(
        '🔄 Controller updated → '
        'heightInCm=${heightInCm.value}, '
        'weightInKg=${weightInKg.value}',
      );

      /// -----------------------------
      /// API CALLS DEBUG
      /// -----------------------------
      bool allSuccessful = true;

      final fields = [
        {
          'endpoint': userHeightApi,
          'payload': {
            'Day': height.day,
            'Month': height.month,
            'Year': height.year,
            'Time': height.time,
            'Value': heightValue,
          },
        },
        {
          'endpoint': userWeightApi,
          'payload': {
            'Day': weight.day,
            'Month': weight.month,
            'Year': weight.year,
            'Time': weight.time,
            'Value': weightValue,
          },
        },
      ];

      for (final item in fields) {
        final endpoint = item['endpoint'] as String;
        final payload = item['payload'] as Map<String, dynamic>;

        debugPrint('🌐 API CALL → $endpoint');
        debugPrint('📤 Payload → $payload');

        final response = await ApiService.post(
          endpoint,
          payload,
          withAuth: true,
          encryptionRequired: true,
        );

        if (response is http.Response && response.statusCode >= 400) {
          debugPrint(
            '❌ Save to $endpoint failed with status ${response.statusCode}',
          );
          allSuccessful = false;
        } else {
          debugPrint('✅ Save to $endpoint successful');
        }
      }

      if (allSuccessful) {
        debugPrint('🎉 ALL SAVES SUCCESSFUL');
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Profile data saved successfully.',
        );
        if (context.mounted) {
          Get.to(() => QuestionnaireScreen());
        }
      }
    } catch (e, stack) {
      debugPrint('❌ EXCEPTION IN saveData');
      debugPrint(e.toString());
      debugPrint(stack.toString());

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to save profile data',
      );
    }
  }
}
