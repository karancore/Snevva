import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/CommonWidgets/common_date_widget.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/models/queryParamViewModels/date_of_birth.dart';
import 'package:snevva/models/queryParamViewModels/occupation_vm.dart';
import 'package:snevva/models/queryParamViewModels/string_value_vm.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/height_and_weight_screen.dart';
import '../../Controllers/local_storage_manager.dart';
import '../../Widgets/ProfileSetupAndQuestionnaire/gender_radio_button.dart';
import '../../consts/consts.dart';

class ProfileSetupInitial extends StatefulWidget {
  const ProfileSetupInitial({super.key});

  @override
  State<ProfileSetupInitial> createState() => _ProfileSetupInitialState();
}

class _ProfileSetupInitialState extends State<ProfileSetupInitial> {
  late ProfileSetupController initialProfileController;

  @override
  void initState() {
    super.initState();

    initialProfileController = Get.put(ProfileSetupController());

    final localStorageManager = Get.put(LocalStorageManager());

    print(localStorageManager.userMap);

    // Load Name
    final storedName = localStorageManager.userMap['Name'];
    if (storedName != null && storedName is String && storedName.isNotEmpty) {
      initialProfileController.userNameText.value = storedName;
      initialProfileController.userNameController.text = storedName;
    }

    // Load Gender
    final storedGender = localStorageManager.userMap['Gender'];
    print("Loaded gender from local storage: $storedGender");

    if (storedGender != null &&
        storedGender is String &&
        storedGender.isNotEmpty) {
      initialProfileController.userGenderValue.value = storedGender;
    }

    // Load Occupation
    final occupationMap = localStorageManager.userMap['OccupationData'];
    final storedOccupation = occupationMap?['Name'];

    print("Occupation from local storage: $storedOccupation");

    if (storedOccupation != null &&
        storedOccupation is String &&
        storedOccupation.isNotEmpty) {
      initialProfileController.selectedOccupation.value = storedOccupation;
    }

    // Load or default DOB
    final day = localStorageManager.userMap['DayOfBirth'];
    final month = localStorageManager.userMap['MonthOfBirth'];
    final year = localStorageManager.userMap['YearOfBirth'];

    if (day == 0 ||
        day == null ||
        month == 0 ||
        month == null ||
        year == 0 ||
        year == null) {
      dob = DateTime.now();
      localStorageManager.userMap['DayOfBirth'] = dob!.day;
      localStorageManager.userMap['MonthOfBirth'] = dob!.month;
      localStorageManager.userMap['YearOfBirth'] = dob!.year;
    } else {
      dob = DateTime(year, month, day);
    }

    // if (day != null && month != null && year != null) {
    //   dob = DateTime(year, month, day);
    // } else {
    //   dob = DateTime.now();
    //   localStorageManager.userMap['DayOfBirth'] = dob!.day;
    //   localStorageManager.userMap['MonthOfBirth'] = dob!.month;
    //   localStorageManager.userMap['YearOfBirth'] = dob!.year;
    // }

    initialProfileController.userDob.value =
        "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}";
  }

  DateTime? dob;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final LocalStorageManager localStorageManager = Get.put(
      LocalStorageManager(),
    );

    final day = localStorageManager.userMap['DayOfBirth'];
    final month = localStorageManager.userMap['MonthOfBirth'];
    final year = localStorageManager.userMap['YearOfBirth'];

    if (day != 0 && month != 0 && year != 0) {
      dob = DateTime(year, month, day);
    } else {
      // If not found, default to today
      dob = DateTime.now();
      print("DOB not found in local storage, defaulting to today: $dob");

      localStorageManager.userMap['DayOfBirth'] = dob!.day;
      localStorageManager.userMap['MonthOfBirth'] = dob!.month;
      localStorageManager.userMap['YearOfBirth'] = dob!.year;
    }

    // Also update observable DOB string for later use
    initialProfileController.userDob.value =
        "${dob!.day.toString().padLeft(2, '0')}/${dob!.month.toString().padLeft(2, '0')}/${dob!.year}";

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppLocalizations.of(context)!.setupProfile,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
        ),
      ),
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          spacing: 24,
          children: [
            // Align(
            Expanded(
              flex: 2,
              child: Center(
                // Changed from Column to Center
                child: Obx(
                  () => Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage:
                            initialProfileController.pickedImage.value != null
                                ? FileImage(
                                  initialProfileController.pickedImage.value!,
                                )
                                : AssetImage(profileImg) as ImageProvider,
                      ),
                      Positioned(
                        bottom: -6,
                        right: -8,
                        child: IconButton(
                          onPressed: () async {
                            await initialProfileController
                                .pickImageFromGallery();
                          },
                          icon: SizedBox(
                            height: 32,
                            width: 32,
                            child: CircleAvatar(
                              backgroundColor: AppColors.primaryColor,
                              child: Icon(
                                Icons.camera_alt,
                                color: white,
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

            //const SizedBox(height: 16,),
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
                    behavior: ScrollBehavior().copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 40),
                          Text(
                            AppLocalizations.of(context)!.enterYourName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            child: Obx(
                              () => TextFormField(
                                controller:
                                    initialProfileController.userNameController,
                                style: const TextStyle(color: white),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  hintText:
                                      AppLocalizations.of(
                                        context,
                                      )!.enterYourName,
                                  hintStyle: const TextStyle(color: white),

                                  errorText:
                                      initialProfileController
                                                  .hasAttemptedSubmit
                                                  .value &&
                                              initialProfileController
                                                  .nameError
                                                  .value
                                                  .isNotEmpty
                                          ? initialProfileController
                                              .nameError
                                              .value
                                          : null,

                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),

                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: const BorderSide(
                                      width: 1,
                                      color: white,
                                    ),
                                  ),

                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(
                                      width: 1,
                                      color:
                                          initialProfileController
                                                      .hasAttemptedSubmit
                                                      .value &&
                                                  initialProfileController
                                                      .nameError
                                                      .value
                                                      .isNotEmpty
                                              ? Colors.redAccent
                                              : Colors.white70,
                                    ),
                                  ),

                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(4),
                                    borderSide: BorderSide(
                                      width: 1,
                                      color:
                                          initialProfileController
                                                      .hasAttemptedSubmit
                                                      .value &&
                                                  initialProfileController
                                                      .nameError
                                                      .value
                                                      .isNotEmpty
                                              ? Colors.redAccent
                                              : white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.birthdayPrompt,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: white,
                            ),
                          ),
                          const SizedBox(height: 6),

                          CommonDateWidget(
                            width: width,
                            isDarkMode: isDarkMode,
                            initialDate: dob,
                            // ← this will now be today if null
                            setDate: (DateTime newDate) {
                              localStorageManager.userMap['DayOfBirth'] =
                                  newDate.day;
                              localStorageManager.userMap['MonthOfBirth'] =
                                  newDate.month;
                              localStorageManager.userMap['YearOfBirth'] =
                                  newDate.year;

                              // Keep observable DOB updated
                              initialProfileController.userDob.value =
                                  "${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}";

                              print(
                                "Date updated: ${initialProfileController.userDob.value}",
                              );
                            },
                          ),

                          Transform.translate(
                            offset: Offset(0, -10),
                            child: Text(
                              AppLocalizations.of(context)!.selectGender,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: white,
                              ),
                            ),
                          ),
                          GenderRadioButton(),
                          SizedBox(height: defaultSize - 20),

                          Text(
                            'Your Occupation',
                            style: const TextStyle(
                              fontSize: 18,
                              color: white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: defaultSize - 20),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 1, color: white),
                              borderRadius: BorderRadius.circular(4),
                              color: AppColors.primaryColor,
                            ),
                            child: Obx(
                              () => DropdownFlutter<String>(
                                hintText: 'Occupation',
                                items: initialProfileController.occupationList,
                                initialItem:
                                    initialProfileController
                                            .selectedOccupation
                                            .value
                                            .isEmpty
                                        ? null
                                        : initialProfileController
                                            .selectedOccupation
                                            .value,

                                onChanged: (value) {
                                  if (value != null) {
                                    initialProfileController
                                        .selectedOccupation
                                        .value = value;

                                    final now = DateTime.now();
                                    final formattedTime = TimeOfDay.now()
                                        .format(context);

                                    localStorageManager
                                        .userMap['OccupationData'] = {
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
                                  closedSuffixIcon: Icon(
                                    Icons.keyboard_arrow_down,
                                    // default arrow icon
                                    color:
                                        white, // change this to any color you want
                                  ),
                                  expandedSuffixIcon: Icon(
                                    Icons.keyboard_arrow_up,
                                    // default arrow icon
                                    color:
                                        white, // change this to any color you want
                                  ),

                                  closedFillColor: Colors.transparent,
                                  expandedFillColor: white,

                                  //hintStyle: TextStyle(color: AppColors.w.withOpacity(0.5)),
                                  listItemStyle: TextStyle(
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Obx(
                            () => SafeArea(
                              child: Center(
                                child: CustomOutlinedButton(
                                  backgroundColor: white,
                                  isWhiteReq: true,
                                  width: width,
                                  isDarkMode: isDarkMode,
                                  buttonName: "Submit",
                                  fontWeight: FontWeight.bold,

                                  onTap:
                                      initialProfileController.isFormValid.value
                                          ? () async {
                                            print(
                                              '🟢 Profile Submit TAP triggered',
                                            );

                                            // ================= NAME =================
                                            final nameValue =
                                                initialProfileController
                                                    .userNameText
                                                    .value;

                                            final nameModel = StringValueVM(
                                              value: nameValue,
                                            );

                                            // ================= GENDER =================
                                            final genderValue =
                                                initialProfileController
                                                    .userGenderValue
                                                    .value;
                                            print(
                                              '🚻 Gender raw value: "$genderValue"',
                                            );

                                            final genderModel = StringValueVM(
                                              value: genderValue,
                                            );

                                            // ================= DOB =================
                                            final dobString =
                                                initialProfileController
                                                    .userDob
                                                    .value;

                                            print(
                                              '📅 DOB raw string: "$dobString"',
                                            );

                                            final parts = dobString.split('/');
                                            int? day, month, year;

                                            if (parts.length >= 3) {
                                              day = int.tryParse(parts[0]);
                                              month = int.tryParse(parts[1]);
                                              year = int.tryParse(parts[2]);
                                            }

                                            print(
                                              '📆 Parsed DOB → day=$day, month=$month, year=$year',
                                            );

                                            if (day == null ||
                                                month == null ||
                                                year == null) {
                                              CustomSnackbar.showError(
                                                context: context,
                                                title: 'Invalid Date of Birth',
                                                message:
                                                    'Please enter a valid date of birth.',
                                              );
                                              return;
                                            }

                                            final today = DateTime.now();
                                            final dob = DateTime(
                                              year,
                                              month,
                                              day,
                                            );

                                            int age = today.year - dob.year;
                                            if (today.month < dob.month ||
                                                (today.month == dob.month &&
                                                    today.day < dob.day)) {
                                              age--;
                                            }

                                            print('🎂 Calculated age = $age');

                                            if (age < 13) {
                                              CustomSnackbar.showError(
                                                context: context,
                                                title: 'Age Restriction',
                                                message:
                                                    'You must be at least 13 years old to create a profile.',
                                              );
                                              return; // ⛔ STOP profile creation
                                            }

                                            final dobModel = DateOfBirthVM(
                                              dayOfBirth: day,
                                              monthOfBirth: month,
                                              yearOfBirth: year,
                                            );

                                            // ================= OCCUPATION =================
                                            final occupationValue =
                                                initialProfileController
                                                    .selectedOccupation
                                                    .value;

                                            print(
                                              '💼 Occupation raw value: "$occupationValue"',
                                            );

                                            final occupationModel =
                                                OccupationVM(
                                                  day: DateTime.now().day,
                                                  month: DateTime.now().month,
                                                  year: DateTime.now().year,
                                                  time: TimeOfDay.now().format(
                                                    context,
                                                  ),
                                                  name: occupationValue,
                                                );

                                            // ================= FINAL CHECK =================
                                            print(
                                              '📦 Models BEFORE saveData():',
                                            );
                                            print(
                                              '   👉 NameModel.value = ${nameModel.value}',
                                            );
                                            print(
                                              '   👉 GenderModel.value = ${genderModel.value}',
                                            );
                                            print(
                                              '   👉 DOBModel = ${dobModel.dayOfBirth}/${dobModel.monthOfBirth}/${dobModel.yearOfBirth}',
                                            );
                                            print(
                                              '   👉 OccupationModel.name = ${occupationModel.name}',
                                            );

                                            // ================= SAVE =================
                                            print('💾 Calling saveData()...');
                                            final bool result =
                                                await initialProfileController
                                                    .saveData(
                                                      nameModel,
                                                      genderModel,
                                                      dobModel,
                                                      occupationModel,
                                                      context,
                                                    );

                                            //await initialProfileController.uploadProfilePicture(context);

                                            if (result) {
                                              Get.to(
                                                HeightWeightScreen(
                                                  gender:
                                                      genderValue.toString(),
                                                ),
                                              );
                                            }

                                            print(
                                              '➡️ Navigation → HeightWeightScreen',
                                            );
                                          }
                                          : null,
                                  // disables the button
                                ),
                              ),
                            ),
                          ),
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
