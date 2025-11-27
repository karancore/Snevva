import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/localStorageManager.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/date_of_birth.dart';
import 'package:snevva/models/queryParamViewModels/occupation_vm.dart';
import 'package:snevva/models/queryParamViewModels/string_value_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../../consts/consts.dart';

class ProfileSetupController extends GetxController {
  RxString userNameText = ''.obs;
  var userDob = ''.obs;
  var userGenderIcon = ''.obs;
  final RxString userGenderValue = ''.obs;
  DateTime _selectedDate = DateTime.now();
  var selectedOccupation = ''.obs;
  final localStorageManager = Get.put(LocalStorageManager());

  var pickedImage = Rx<File?>(null);
  final ImagePicker _imgPicker = ImagePicker();

  RxBool isFormValid = false.obs;

  void validateForm() {
    isFormValid.value =
        userNameText.value.trim().isNotEmpty &&
            userGenderValue.value.trim().isNotEmpty &&
            userDob.value.trim().isNotEmpty &&
            selectedOccupation.value.trim().isNotEmpty;
  }


  List<String> occupationList = [
    'Student',
    'Employed',
    'Self-Employed',
    'Unemployed',
    'Retired',
    'Other',
  ];

  final userNameController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadSavedImage();
    userNameController.addListener(() {
      userNameText.value = userNameController.text;
      initialProfileController.userGenderIcon;
      validateForm();
    });

    ever(userGenderValue, (_) => validateForm());
    ever(userDob, (_) => validateForm());
    ever(selectedOccupation, (_) => validateForm());
  }

  @override
  void onClose() {
    userNameController.dispose();
    super.onClose();
  }

  /// ✅ Pick image and save it locally
  Future<void> pickImageFromGallery() async {
    final XFile? image = await _imgPicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      pickedImage.value = File(image.path);
      await saveImagePath(image.path); // Save for persistence
    }
  }

  /// ✅ Save image path to SharedPreferences
  Future<void> saveImagePath(String path) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path);
    print("💾 Image path saved locally: $path");
  }

  /// ✅ Load saved image path from SharedPreferences
  Future<void> loadSavedImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString('profileImagePath');

    if (savedPath != null && File(savedPath).existsSync()) {
      pickedImage.value = File(savedPath);
      print("✅ Loaded image from local storage: $savedPath");
    } else {
      print("⚠️ No saved image found or file missing.");
    }
  }

  // Optional helper — clear image
  Future<void> clearImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImagePath');
    pickedImage.value = null;
  }

  void selectGender(String gender) {
    userGenderValue.value = gender;
  }

  void setGender(String gender) {
    print("Gender set to: $gender");
    userGenderValue.value = gender;
    switch (gender) {
      case 'Male':
        userGenderIcon.value = maleIcon;
        break;
      case 'Female':
        userGenderIcon.value = femaleIcon;
        break;
      default:
        userGenderIcon.value = genderIcon;
        break;
    }
  }

  void onDateChanged(DateTime newDate) {
    int year = newDate.year;
    int month = newDate.month;
    int day = newDate.day;
    int lastDay = DateTime(year, month + 1, 0).day;

    if (day > lastDay) {
      newDate = DateTime(year, month, lastDay);
    }

    if (_selectedDate != newDate) {
      _selectedDate = newDate;

      final formattedDate =
          "${day.toString().padLeft(2, '0')}/"
          "${month.toString().padLeft(2, '0')}/"
          "$year";
      userDob.value = formattedDate;
    }
  }



  // Future<void> saveData(String name, String gender, String dob) async {
  //   ApiService.post(userNameApi, {'name': name});
  //   ApiService.post(userGenderApi, {'gender': gender});
  //   ApiService.post(userDobApi, {'dob': dob});
  // }

  Future<void> saveData(
    StringValueVM name,
    StringValueVM gender,
    DateOfBirthVM dob,
    OccupationVM occupation,
  ) async {
    final List<Map<String, dynamic>> fields = [
      {
        'endpoint': userNameApi,
        'payload': {'Value': name.value},
      },
      {
        'endpoint': userGenderApi,
        'payload': {'Value': gender.value},
      },
      {
        'endpoint': userDobApi,
        'payload': {
          'DayOfBirth': dob.dayOfBirth,
          'MonthOfBirth': dob.monthOfBirth,
          'YearOfBirth': dob.yearOfBirth,
          'BirthTime': dob.birthTime,
        },
      },
      {
        'endpoint': userOccupationApi,
        'payload': {
          'Day': occupation.day,
          'Month': occupation.month,
          'Year': occupation.year,
          'Time': occupation.time,
          'Name': occupation.name,
        },
      },
    ];

    try {

      localStorageManager.userMap['Name'] = name.value;
      localStorageManager.userMap['Gender'] = gender.value;
      localStorageManager.userMap['DayOfBirth'] = dob.dayOfBirth;
      localStorageManager.userMap['MonthOfBirth'] = dob.monthOfBirth;
      localStorageManager.userMap['YearOfBirth'] = dob.yearOfBirth;
      localStorageManager.userMap['Occupation'] = occupation.name;

      // print("🔄 Updating local storage with profile data: ${localStorageManager.userMap}");
      
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
          Get.snackbar(
            'Error',
            'Failed to save ${payload.keys.first}.',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return;
        }
      }
      if(allSuccessful) {
        // Get.snackbar(
        //   'Success',
        //   'Profile data saved successfully.',
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.all(20),
        // );
      }
    } catch (e) {
      // print("❌ Exception during profile save: $e");
      // print(stack);
      Get.snackbar(
        'Error',
        'Failed to save profile data',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
    }
  }

}
