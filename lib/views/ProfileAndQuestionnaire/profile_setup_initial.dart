import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/CommonWidgets/common_date_widget.dart';

import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/models/queryParamViewModels/date_of_birth.dart';
import 'package:snevva/models/queryParamViewModels/occupation_vm.dart';
import 'package:snevva/models/queryParamViewModels/string_value_vm.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/height_and_weight_screen.dart';
import '../../Widgets/ProfileSetupAndQuestionnaire/gender_radio_button.dart';
import '../../common/global_variables.dart';
import '../../consts/consts.dart';

class ProfileSetupInitial extends StatefulWidget {
  const ProfileSetupInitial({super.key});

  @override
  State<ProfileSetupInitial> createState() => _ProfileSetupInitialState();
}

class _ProfileSetupInitialState extends State<ProfileSetupInitial> {
  late final ProfileSetupController initialProfileController;
  final LocalStorageManager localStorageManager = Get.put(LocalStorageManager(), permanent: true);

  DateTime? dob;

  @override
  void initState() {
    super.initState();

    // Put controllers/services ONCE. If you register them in Bindings, use Get.find instead.
    // Mark permanent true here to avoid accidental re-registration in other places.
    initialProfileController =
        Get.put(ProfileSetupController(), permanent: true);


    // Load existing stored name (if any)
    final storedName = localStorageManager.userMap['Name'];
    if (storedName != null && storedName is String && storedName.isNotEmpty) {
      initialProfileController.userNameText.value = storedName;
      initialProfileController.userNameController.text = storedName;
    }

    // Load Gender
    final storedGender = localStorageManager.userMap['Gender'];
    if (storedGender != null && storedGender is String && storedGender.isNotEmpty) {
      initialProfileController.userGenderValue.value = storedGender;
    }

    // Load Occupation
    final occupationMap = localStorageManager.userMap['OccupationData'];
    final storedOccupation = occupationMap?['Name'];
    if (storedOccupation != null && storedOccupation is String && storedOccupation.isNotEmpty) {
      initialProfileController.selectedOccupation.value = storedOccupation;
    }

    // Load or default DOB (do this once here)
    final day = localStorageManager.userMap['DayOfBirth'];
    final month = localStorageManager.userMap['MonthOfBirth'];
    final year = localStorageManager.userMap['YearOfBirth'];

    if (day == null || month == null || year == null || day == 0 || month == 0 || year == 0) {
      dob = DateTime.now();
      localStorageManager.userMap['DayOfBirth'] = dob!.day;
      localStorageManager.userMap['MonthOfBirth'] = dob!.month;
      localStorageManager.userMap['YearOfBirth'] = dob!.year;
    } else {
      dob = DateTime(year, month, day);
    }

    // Set observable DOB string once (NOT inside build)
    initialProfileController.userDob.value =
    "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}";
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Do NOT mutate observables here. Only read.
    // dob is already set in initState; if you want to update it reactively,
    // use setState or controller methods via callbacks.

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context)!.setupProfile,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: AppColors.primaryColor),
      ),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          // removed 'spacing' - standard Column does not support that
          children: [
            Expanded(
              flex: 2,
              child: Center(
                child: Obx(
                      () => Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: initialProfileController.pickedImage.value != null
                            ? FileImage(initialProfileController.pickedImage.value!)
                            : AssetImage(profileImg) as ImageProvider,
                      ),
                      Positioned(
                        bottom: -6,
                        right: -8,
                        child: IconButton(
                          onPressed: () async {
                            await initialProfileController.pickImageFromGallery();
                          },
                          icon: SizedBox(
                            height: 32,
                            width: 32,
                            child: CircleAvatar(
                              backgroundColor: AppColors.primaryColor,
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              flex: 8,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            AppLocalizations.of(context)!.enterYourName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            child: Obx(
                                  () => TextFormField(
                                controller: initialProfileController.userNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  hintText: AppLocalizations.of(context)!.enterYourName,
                                  hintStyle: const TextStyle(color: Colors.white),
                                  errorText: initialProfileController.hasAttemptedSubmit.value &&
                                      initialProfileController.nameError.value.isNotEmpty
                                      ? initialProfileController.nameError.value
                                      : null,
                                  errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(width: 1, color: Colors.white),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(
                                      width: 1,
                                      color: initialProfileController.hasAttemptedSubmit.value &&
                                          initialProfileController.nameError.value.isNotEmpty
                                          ? Colors.redAccent
                                          : Colors.white70,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(
                                      width: 1,
                                      color: initialProfileController.hasAttemptedSubmit.value &&
                                          initialProfileController.nameError.value.isNotEmpty
                                          ? Colors.redAccent
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.birthdayPrompt,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                          const SizedBox(height: 6),

                          CommonDateWidget(
                            width: width,
                            isDarkMode: isDarkMode,
                            initialDate: dob,
                            setDate: (DateTime newDate) {
                              // Update local storage and controller from the date picker callback
                              localStorageManager.userMap['DayOfBirth'] = newDate.day;
                              localStorageManager.userMap['MonthOfBirth'] = newDate.month;
                              localStorageManager.userMap['YearOfBirth'] = newDate.year;

                              initialProfileController.userDob.value =
                              "${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}";
                            },
                          ),

                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: Text(
                              AppLocalizations.of(context)!.selectGender,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                          ),
                          const GenderRadioButton(),
                          SizedBox(height: defaultSize - 20),

                          const Text(
                            'Your Occupation',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: defaultSize - 20),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 1, color: Colors.white),
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.primaryColor,
                            ),
                            child: Obx(
                                  () => DropdownFlutter<String>(
                                hintText: 'Occupation',
                                items: initialProfileController.occupationList,
                                initialItem: initialProfileController.selectedOccupation.value.isEmpty
                                    ? null
                                    : initialProfileController.selectedOccupation.value,
                                onChanged: (value) {
                                  if (value != null) {
                                    initialProfileController.selectedOccupation.value = value;

                                    final formattedTime = TimeOfDay.now().format(context);
                                    final now = DateTime.now();

                                    localStorageManager.userMap['OccupationData'] = {
                                      'Day': now.day,
                                      'Month': now.month,
                                      'Year': now.year,
                                      'Time': formattedTime,
                                      'Name': value,
                                      'IsCurrent': true,
                                    };
                                  }
                                },
                                decoration: CustomDropdownDecoration(
                                  closedSuffixIcon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                                  expandedSuffixIcon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                                  closedFillColor: Colors.transparent,
                                  expandedFillColor: Colors.white,
                                  listItemStyle: TextStyle(color: AppColors.primaryColor),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                           SafeArea(
                              child: Center(
                                child: CustomOutlinedButton(
                                  backgroundColor: Colors.white,
                                  isWhiteReq: true,
                                  width: width,
                                  isDarkMode: isDarkMode,
                                  buttonName: "Submit",
                                  fontWeight: FontWeight.bold,
                                  onTap: () async {
                                    initialProfileController.isFormValid.value = true;

                                    // ================= NAME =================
                                    final String nameValue = initialProfileController.userNameController.text.trim();

                                    if (!startsWithCapital(nameValue)) {
                                      Get.snackbar(
                                        'Invalid Name',
                                        'Start name with a capital letter.',
                                        snackPosition: SnackPosition.TOP,
                                        backgroundColor: AppColors.primaryColor,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 1),
                                      );
                                      return;
                                    }

                                    final nameModel = StringValueVM(value: nameValue);

                                    // ================= GENDER =================
                                    final genderValue = initialProfileController.userGenderValue.value;
                                    final genderModel = StringValueVM(value: genderValue);

                                    // ================= DOB =================
                                    final dobString = initialProfileController.userDob.value;
                                    final parts = dobString.split('/');
                                    int? day, month, year;
                                    if (parts.length >= 3) {
                                      day = int.tryParse(parts[0]);
                                      month = int.tryParse(parts[1]);
                                      year = int.tryParse(parts[2]);
                                    }

                                    if (day == null || month == null || year == null) {
                                      CustomSnackbar.showError(context: context, title: 'Invalid Date of Birth', message: 'Please enter a valid date of birth.');
                                      return;
                                    }

                                    final today = DateTime.now();
                                    final dobDate = DateTime(year, month, day);
                                    int age = today.year - dobDate.year;
                                    if (today.month < dobDate.month || (today.month == dobDate.month && today.day < dobDate.day)) {
                                      age--;
                                    }

                                    if (age < 13) {
                                      Get.snackbar(
                                        'Age Restriction',
                                        'You must be at least 13 years old to create a profile.',
                                        snackPosition: SnackPosition.TOP,
                                        backgroundColor: AppColors.primaryColor,
                                        colorText: Colors.white,
                                        duration: const Duration(seconds: 1),
                                      );
                                      return;
                                    }

                                    final dobModel = DateOfBirthVM(dayOfBirth: day, monthOfBirth: month, yearOfBirth: year);

                                    // ================= OCCUPATION =================
                                    final occupationValue = initialProfileController.selectedOccupation.value;
                                    final occupationModel = OccupationVM(day: DateTime.now().day, month: DateTime.now().month, year: DateTime.now().year, time: TimeOfDay.now().format(context), name: occupationValue);

                                    final bool result = await initialProfileController.saveData(
                                      nameModel,
                                      genderModel,
                                      dobModel,
                                      occupationModel,
                                      context,
                                    );

                                    if (result) {
                                      Get.to(HeightWeightScreen(gender: genderValue.toString()));
                                    }
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
