import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/models/queryParamViewModels/date_of_birth.dart';
import 'package:snevva/models/queryParamViewModels/occupation_vm.dart';
import 'package:snevva/models/queryParamViewModels/string_value_vm.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import '../../consts/consts.dart';

import 'dart:convert';

class ProfileSetupController extends GetxService {
  // ================= TEXT + ERRORS =================
  final userNameController = TextEditingController();
  RxString userNameText = ''.obs;
  RxString nameError = ''.obs; // 🔴 NEW

  // ================= OTHER FIELDS =================
  var userDob = ''.obs;
  var userGenderIcon = ''.obs;
  final RxString userGenderValue = ''.obs;
  var selectedOccupation = ''.obs;
  RxBool hasAttemptedSubmit = false.obs;

  DateTime _selectedDate = DateTime.now();

  final localStorageManager = Get.find<LocalStorageManager>();

  var pickedImage = Rx<File?>(null);
  final ImagePicker _imgPicker = ImagePicker();

  RxBool isFormValid = false.obs;

  // ================= OCCUPATIONS =================
  List<String> occupationList = [
    'Student',
    'Employed',
    'Self-Employed',
    'Unemployed',
    'Retired',
    'Other',
  ];

  // ================= VALIDATION =================
  void validateForm() {
    final name = userNameText.value.trim();

    // ---- NAME VALIDATION ----
    if (name.isEmpty) {
      nameError.value = 'Name is required';
    } else if (!RegExp(r'^[A-Z]').hasMatch(name)) {
      nameError.value = 'Name must start with a capital letter';
    } else {
      nameError.value = '';
    }

    // ---- FINAL FORM VALIDITY ----
    isFormValid.value =
        nameError.value.isEmpty &&
        name.isNotEmpty &&
        userGenderValue.value.trim().isNotEmpty &&
        userDob.value.trim().isNotEmpty &&
        selectedOccupation.value.trim().isNotEmpty;
  }

  // ================= LIFECYCLE =================
  @override
  void onInit() {
    super.onInit();
    loadSavedImage();

    userNameController.addListener(() {
      userNameText.value = userNameController.text.trim();
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

  // ================= IMAGE =================
  Future<void> pickImageFromGallery() async {
    final XFile? image = await _imgPicker.pickImage(
      source: ImageSource.gallery,
    );

    if (image != null) {
      pickedImage.value = File(image.path);
      await saveImagePath(
        filename: image.name,
        path: image.path,
        type: image.path,
      );
    }
  }

  Future<void> uploadFileToUrl({
    required String uploadUrl,
    required File file,
    required String contentType,
  }) async {
    final bytes = await file.readAsBytes();

    final response = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        "Content-Type": contentType,
        "x-ms-blob-type": "BlockBlob",
      },
      body: bytes,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print("✅ File uploaded to storage");
    } else {
      print("❌ Storage upload failed: ${response.statusCode}");
      print(response.body);
    }
  }

  Future<void> saveImagePath({
    required String path,
    required String type,
    required String filename,
  }) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('profileImagePath', path);

    try {
      File file = File(path);

      // STEP 1️⃣ — Call API to get UploadUrl
      final payload = {
       "Title" : filename ,
        "Description" : filename ,
        "isExternalLink" : false ,
        "OriginalFilename" : filename ,
        "ContentType" : type ,
        "IsProfilePicture" : true
      };

      final response = await ApiService.post(
        uploadprofilepic,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      print("🔄 Initial upload response: $response");

      if (response is http.Response) {
        print("❌ Failed to get upload URL: ${response.statusCode}");
        print(response.body);
        return;
      }

      final res = jsonDecode(jsonEncode(response));

      debugPrint("res upload image $res");

      // 🔴 Adjust this according to your API response structure
      final uploadUrl = res['data']['UploadUrl'];
      final contentType = res['data']['ContentType'];

      // STEP 2️⃣ — Upload file directly to storage
      await uploadFileToUrl(
        uploadUrl: uploadUrl,
        file: file,
        contentType: contentType ?? "image/jpeg",
      );

      print("✅ Upload completed successfully");
    } catch (e) {
      print("❌ Upload failed: $e");
    }
  }

  Future<void> loadSavedImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedPath = prefs.getString('profileImagePath');

    if (savedPath != null && File(savedPath).existsSync()) {
      pickedImage.value = File(savedPath);
    }
  }

  Future<void> clearImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImagePath');
    pickedImage.value = null;
  }

  // ================= GENDER =================
  void setGender(String gender) {
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
    }
  }

  // ================= DOB =================
  void onDateChanged(DateTime newDate) {
    int year = newDate.year;
    int month = newDate.month;
    int day = newDate.day;

    int lastDay = DateTime(year, month + 1, 0).day;
    if (day > lastDay) {
      day = lastDay;
    }

    final formattedDate =
        "${day.toString().padLeft(2, '0')}/"
        "${month.toString().padLeft(2, '0')}/"
        "$year";

    userDob.value = formattedDate;
  }

  // Future<void> saveData(String name, String gender, String dob) async {
  //   ApiService.post(userNameApi, {'name': name});
  //   ApiService.post(userGenderApi, {'gender': gender});
  //   ApiService.post(userDobApi, {'dob': dob});
  // }

  Future<bool> saveData(
    StringValueVM name,
    StringValueVM gender,
    DateOfBirthVM dob,
    OccupationVM occupation,
    BuildContext context,
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

      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('user_gender', gender.value);

      print(
        "🔄 Updating local storage with profile data: ${localStorageManager.userMap}",
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
          allSuccessful = false;
          print(
            "❌ Failed to save ${payload.keys.first}: ${response.statusCode}",
          );
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to save ${payload.keys.first}.',
          );
          return false;
        }
      }
      if (allSuccessful) {
        CustomSnackbar.showSuccess(
          context: context,
          title: 'Success',
          message: 'Profile data saved successfully.',
        );
        return true;
      }
      return true;
    } catch (e, stack) {
      print("Exception during profile save: $e");
      print(stack);
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to save profile data',
      );
    }
    return false;
  }
}
