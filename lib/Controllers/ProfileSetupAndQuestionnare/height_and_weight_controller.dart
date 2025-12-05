import 'package:get/get.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/height_vm.dart';
import 'package:snevva/models/queryParamViewModels/weight_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;

class HeightWeightController extends GetxController {
  // height

  RxDouble heightInCm = 140.0.obs;

  double get heightInFeet => heightInCm.value / 30.48;

  int get feet => (heightInCm.value / 30.48).floor();

  int get inches => (((heightInCm.value / 30.48) - feet) * 11).round();
  final localStorageManager = Get.put(LocalStorageManager());

  void updateFromFeet(double feet) {
    heightInCm.value = feet * 30.48;
  }

  void updateFromCm(double cm) {
    heightInCm.value = cm;
  }

  // Weight

  // var weight = 52.0.obs;

  var weightInKg = 52.0.obs;

  void setWeight(double weightValue) {
    weightInKg.value = weightValue;
  }

  Future<void> saveData(
    HeightVM height,
    WeightVM weight,
    BuildContext context,
  ) async {
    final List<Map<String, dynamic>> fields = [
      {
        'endpoint': userHeightApi,
        'payload': {
          'Day': height.day,
          'Month': height.month,
          'Year': height.year,
          'Time': height.time,
          'Value': height.value,
        },
      },
      {
        'endpoint': userWeightApi,
        'payload': {
          'Day': weight.day,
          'Month': weight.month,
          'Year': weight.year,
          'Time': weight.time,
          'Value': weight.value,
        },
      },
    ];

    try {
      localStorageManager.userMap['Height']['Value'] = double.parse(
        height.value!.toStringAsFixed(2),
      );
      heightInCm.value = double.parse(height.value!.toStringAsFixed(2));

      localStorageManager.userMap['Weight']['Value'] = double.parse(
        weight.value!.toStringAsFixed(2),
      );
      weightInKg.value = double.parse(weight.value!.toStringAsFixed(2));

      print(
        "🔄 Updating local storage with height and weight data: ${localStorageManager.userMap}",
      );

      bool allSuccessful = true;
      for (final item in fields) {
        final String endpoint = item['endpoint'] as String;
        final Map<String, dynamic> payload =
            item['payload'] as Map<String, dynamic>;

        final response = await ApiService.post(
          endpoint,
          payload,
          withAuth: true,
          encryptionRequired: true,
        );

        if (response is http.Response) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to save ${payload.keys.first}.',
          );
          return;
        }
      }
      if (allSuccessful) {
        CustomSnackbar.showSuccess(
          title: 'Success',
          message: 'Profile data saved successfully.',
          context: context
        );
      }
    } catch (e , stack) {
      print("❌ Exception during profile save: $e");
      print(stack);
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to save profile data',
      );
    }
  }
}
