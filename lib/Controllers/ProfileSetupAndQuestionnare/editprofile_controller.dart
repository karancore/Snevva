import 'dart:async';
import 'dart:convert';
import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:snevva/services/notification_service.dart';
import '../local_storage_manager.dart';
import '../signupAndSignIn/otp_verification_controller.dart';
import '../signupAndSignIn/sign_up_controller.dart';
import 'package:snevva/common/custom_snackbar.dart';

class EditprofileController extends GetxController {
  final localStorageManager = Get.put(LocalStorageManager());
  final signupController = Get.put(SignUpController());
  late OTPVerificationController otpVerificationController;
  late ProfileSetupController initialProfileController;
  late bool otpVerificationStatus;
  final otp = null;
  final notify = Get.find<NotificationService>();

  DateTime? dob;
  var name = '';
  var email = '';
  var phoneNumber = '';
  var heightValue = '';
  var weightValue = '';
  // var gender = '';
  RxString gender = ''.obs;
  var occupation = '';
  var address = '';

  var isLoading = false.obs; // For showing loader on buttons
  var isResendEnabled = true.obs; // For enabling/disabling resend
  var resendTimer = 0.obs; // For showing countdown
  Timer? _resendCountdownTimer;

  @override
  void onInit() {
    super.onInit();
    loadUserData();
    otpVerificationController = Get.put(OTPVerificationController());
    initialProfileController = Get.put(ProfileSetupController());
  }

  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('userMap');
    if (jsonString != null) {
      localStorageManager.userMap = RxMap<String, dynamic>.from(
        jsonDecode(jsonString),
      );
    }
  }

  void updateField(String key, dynamic value) {
    localStorageManager.userMap[key] = value;

    switch (key) {
      case 'Name':
        name = value;
        break;
      case 'Email':
        email = value;
        break;
      case 'PhoneNumber':
        phoneNumber = value;
        break;
      case 'Height':
        heightValue = value;
        break;
      case 'Weight':
        weightValue = value;
        break;
      case 'Gender':
        gender = value;
        break;
      case 'Occupation':
        occupation = value;
        break;
      case 'Address':
        address = value;
        break;
      case 'DayOfBirth':
      case 'MonthOfBirth':
      case 'YearOfBirth':
        final day = localStorageManager.userMap['DayOfBirth'];
        final month = localStorageManager.userMap['MonthOfBirth'];
        final year = localStorageManager.userMap['YearOfBirth'];
        dob = DateTime(year, month, day);
        break;
    }
  }

  void startResendTimer({int seconds = 30}) {
    isResendEnabled.value = false;
    resendTimer.value = seconds;

    _resendCountdownTimer?.cancel();
    _resendCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer.value > 0) {
        resendTimer.value--;
      } else {
        isResendEnabled.value = true;
        timer.cancel();
      }
    });
  }

  void stopResendTimer() {
    _resendCountdownTimer?.cancel();
    isResendEnabled.value = true;
  }

  void showEditFieldDialog(
    BuildContext context, {
    required String title,
    required String fieldKey,
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: fieldKey == 'Address' ? 4 : 1,
                  keyboardType:
                      fieldKey == 'Address'
                          ? TextInputType.multiline
                          : (fieldKey == 'Height' || fieldKey == 'Weight')
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                  inputFormatters:
                      fieldKey == 'Height' || fieldKey == 'Weight'
                          ? [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ]
                          : [],
                  decoration: InputDecoration(
                    hintText: () {
                      switch (fieldKey) {
                        case 'Name':
                          return 'Enter your full name';
                        case 'Email':
                          return 'Enter your email address';
                        case 'PhoneNumber':
                          return 'Enter your phone number';
                        case 'Height':
                          return 'Enter height (e.g., 170)';
                        case 'Weight':
                          return 'Enter weight (e.g., 65)';
                        case 'Address':
                          return 'Enter your address';
                        default:
                          return title; // fallback
                      }
                    }(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed:
                          isLoading.value
                              ? null
                              : () async {
                                isLoading.value = true;
                                final value = controller.text.trim();
                                double? height = double.tryParse(value);
                                double? weight = double.tryParse(value);

                                // 🧠 Common validation
                                if (fieldKey == 'Name') {
                                  final nameRegex = RegExp(r"^[a-zA-Z\s]+$");
                                  if (value.isEmpty) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message: 'Name cannot be empty',
                                    );

                                    isLoading.value = false;
                                    return;
                                  }
                                  if (!nameRegex.hasMatch(value)) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message:
                                          'Name should not contain numbers or special characters',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }
                                }

                                if (fieldKey == 'Height') {
                                  if (height == null || height <= 0) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message: 'Please enter a valid height',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }
                                }

                                if (fieldKey == 'Weight') {
                                  if (weight == null || weight <= 0) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message: 'Please enter a valid weight',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }
                                }

                                if (fieldKey == 'PhoneNumber') {
                                  final phoneRegex = RegExp(r"^[0-9]{10}$");
                                  if (!phoneRegex.hasMatch(value)) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message:
                                          'Please enter a valid phone number',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }

                                  try {
                                    // ✅ Step 1: Call API to send OTP
                                    final result = await signupController
                                        .phoneotp(value, context);
                                    // await notify.showOtpNotification(result);

                                    if (result != false && result != null) {
                                      otpVerificationController.responseOtp =
                                          result;

                                      // ✅ Close first dialog
                                      Navigator.of(dialogCtx).pop();

                                      // ✅ Step 2: Open OTP verification dialog
                                      Future.delayed(
                                        const Duration(milliseconds: 150),
                                        () {
                                          updatephoneDialog(
                                            context,
                                            title: "Verify your Number",
                                            fieldKey: "PhoneNumber",
                                            initialValue:
                                                value, // pass the actual entered email!
                                            onUpdated: onUpdated,
                                          );
                                        },
                                      );
                                    } else {
                                      CustomSnackbar.showError(
                                        context: context,
                                        title: 'Error',
                                        message:
                                            'Failed to send OTP. Please try again.',
                                      );
                                      isLoading.value = false;
                                    }
                                  } catch (e) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message:
                                          'Something went wrong while sending OTP.',
                                    );
                                    isLoading.value = false;
                                  } finally {
                                    isLoading.value = false;
                                  }

                                  return; // stop further code
                                }

                                // ✅ EMAIL CASE
                                if (fieldKey == 'Email') {
                                  final emailRegex = RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,9}$',
                                  );

                                  if (value.isEmpty) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message: 'Email cannot be empty',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }
                                  if (!emailRegex.hasMatch(value)) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message:
                                          'Please enter a valid email address',
                                    );
                                    isLoading.value = false;
                                    return;
                                  }

                                  try {
                                    // ✅ Step 1: Call API to send OTP
                                    final result = await signupController
                                        .gmailOtp(value, context);
                                    // await notify.showOtpNotification(result);

                                    if (result != false && result != null) {
                                      otpVerificationController.responseOtp =
                                          result;

                                      // ✅ Close first dialog
                                      Navigator.of(dialogCtx).pop();

                                      // ✅ Step 2: Open OTP verification dialog
                                      Future.delayed(
                                        const Duration(milliseconds: 150),
                                        () {
                                          updateemailDialog(
                                            context,
                                            title: "Verify your email",
                                            fieldKey: "Email",
                                            initialValue:
                                                value, // pass the actual entered email!
                                            onUpdated: onUpdated,
                                          );
                                        },
                                      );
                                    } else {
                                      CustomSnackbar.showError(
                                        context: context,
                                        title: 'Error',
                                        message:
                                            'Failed to send OTP. Please try again.',
                                      );
                                      isLoading.value = false;
                                    }
                                  } catch (e) {
                                    CustomSnackbar.showError(
                                      context: context,
                                      title: 'Error',
                                      message:
                                          'Something went wrong while sending OTP.',
                                    );
                                    isLoading.value = false;
                                  } finally {
                                    isLoading.value = false;
                                  }

                                  return; // stop further code
                                }
                                // isLoading.value = false;

                                // ✅ For other fields
                                updateField(fieldKey, value);
                                switch (fieldKey) {
                                  case 'Name':
                                    await saveName(value, context);
                                    isLoading.value = false;
                                    break;
                                  case 'Height':
                                    await saveHeight(
                                      context,
                                      height!,
                                      day: DateTime.now().day,
                                      month: DateTime.now().month,
                                      year: DateTime.now().year,
                                      time: TimeOfDay.now().format(context),
                                    );
                                    isLoading.value = false;
                                    break;
                                  case 'Weight':
                                    await saveWeight(
                                      context,
                                      weight!,
                                      day: DateTime.now().day,
                                      month: DateTime.now().month,
                                      year: DateTime.now().year,
                                      time: TimeOfDay.now().format(context),
                                    );
                                    isLoading.value = false;
                                    break;
                                  case 'Address':
                                    await saveAddress(value, context);
                                    isLoading.value = false;
                                    break;
                                }

                                Navigator.of(dialogCtx).pop();
                                if (onUpdated != null) onUpdated();
                              },
                      child:
                          isLoading.value
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                "Update",
                                style: TextStyle(
                                  color:
                                      isDarkMode
                                          ? scaffoldColorDark
                                          : scaffoldColorLight,
                                ),
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final defaultPinTheme = PinTheme(
    width: 60,
    height: 60,
    textStyle: TextStyle(
      fontSize: 24,
      color: Colors.black,
      fontWeight: FontWeight.w600,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F4FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.transparent),
    ),
  );

  late final focusedPinTheme = defaultPinTheme.copyWith(
    decoration: BoxDecoration(
      color: const Color(0xFFF8F4FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.primaryColor, width: 2),
    ),
  );

  late final submittedPinTheme = defaultPinTheme.copyWith(
    decoration: BoxDecoration(
      color: const Color(0xFFEAE6FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black),
    ),
  );

  late final followingPinTheme = defaultPinTheme.copyWith(
    decoration: BoxDecoration(
      color: const Color(0xFFF8F4FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
  );

  void updateemailDialog(
    BuildContext context, {
    required String title,
    required String fieldKey,
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final pinController = TextEditingController();
    final value = controller.text.trim();
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Image.asset(veriemail, height: 180, width: 180),
                const SizedBox(height: 25),
                Text(
                  'Enter the 6-digit code sent to\n$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 25),

                Pinput(
                  length: 6,
                  controller: pinController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  followingPinTheme: followingPinTheme,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onCompleted: (pin) async {
                    otpVerificationStatus = await otpVerificationController
                        .verifyOtp(pin, ctx);
                    if (otpVerificationStatus) {
                      localStorageManager.userMap['Email'] = initialValue;
                      email = initialValue;
                      await signupController.updateGmail(email, ctx);
                      if (onUpdated != null) onUpdated();
                    }
                  },
                ),

                const SizedBox(height: 15),
                Obx(
                  () => InkWell(
                    onTap:
                        isResendEnabled.value
                            ? () async {
                              isResendEnabled.value = false;
                              startResendTimer(
                                seconds: 30,
                              ); // Start 30-sec timer

                              final result = await signupController.gmailOtp(
                                value,
                                ctx,
                              );

                              if (result != false && result != null) {
                                otpVerificationController.responseOtp = result;
                                CustomSnackbar.showSuccess(
                                  context: context,
                                  title: 'Success',
                                  message: 'OTP resent successfully.',
                                );
                              } else {
                                CustomSnackbar.showError(
                                  context: context,
                                  title: 'Error',
                                  message: 'Failed to resend OTP.',
                                );
                              }
                            }
                            : null,
                    child: ShaderMask(
                      shaderCallback:
                          (bounds) => AppColors.primaryGradient.createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                      child: Text(
                        isResendEnabled.value
                            ? "Resend code"
                            : "Resend in ${resendTimer.value}s",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void updatephoneDialog(
    BuildContext context, {
    required String title,
    required String fieldKey,
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    final pinController = TextEditingController();
    final value = controller.text.trim();
    final isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Image.asset(veriemail, height: 180, width: 180),
                const SizedBox(height: 25),
                Text(
                  'Enter the 6-digit code sent to\n$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 25),

                Pinput(
                  length: 6,
                  controller: pinController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  submittedPinTheme: submittedPinTheme,
                  followingPinTheme: followingPinTheme,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onCompleted: (pin) async {
                    otpVerificationStatus = await otpVerificationController
                        .verifyOtp(pin, ctx);
                    if (otpVerificationStatus) {
                      localStorageManager.userMap['PhoneNumber'] = initialValue;
                      phoneNumber = initialValue;
                      await signupController.updatePhone(phoneNumber, ctx);
                      if (onUpdated != null) onUpdated();
                    }
                  },
                ),

                const SizedBox(height: 15),
                Obx(
                  () => InkWell(
                    onTap:
                        isResendEnabled.value
                            ? () async {
                              isResendEnabled.value = false;
                              startResendTimer(
                                seconds: 30,
                              ); // Start 30-sec timer

                              final result = await signupController.phoneotp(
                                value,
                                ctx,
                              );

                              if (result != false && result != null) {
                                otpVerificationController.responseOtp = result;
                                CustomSnackbar.showSuccess(
                                  context: context,
                                  title: 'Success',
                                  message: 'OTP resent successfully.',
                                );
                              } else {
                                CustomSnackbar.showError(
                                  context: context,
                                  title: 'Error',
                                  message: 'Failed to resend OTP.',
                                );
                              }
                            }
                            : null,
                    child: ShaderMask(
                      shaderCallback:
                          (bounds) => AppColors.primaryGradient.createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                      child: Text(
                        isResendEnabled.value
                            ? "Resend code"
                            : "Resend in ${resendTimer.value}s",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showGenderDialog(BuildContext context, {VoidCallback? onUpdated}) {
    final String? selectedGender = localStorageManager.userMap['Gender'];

    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    void selectGender(String Usergender) async {
      localStorageManager.userMap['Gender'] = Usergender;
      gender.value = Usergender;
      await saveGender(Usergender, context);
      Navigator.pop(context);
      if (onUpdated != null) onUpdated!();
    }

    InkWell genderContainer(String genderText) {
      final bool isSelected = selectedGender == genderText;
      return InkWell(
        onTap: () => selectGender(genderText),
        borderRadius: BorderRadius.circular(20),
        child: Material(
          elevation: 1,
          borderRadius: BorderRadius.circular(20),
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(width: 0.4, color: mediumGrey),
              color: isSelected ? AppColors.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              genderText,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You do you! Choose how you identify, or select ‘Prefer not to say’ if you’re not into labels.",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      genderContainer("Male"),
                      SizedBox(height: 10),
                      genderContainer("Female"),
                      SizedBox(height: 10),

                      genderContainer("Prefer not to say"),
                      SizedBox(height: 10),
                      genderContainer("Other"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showOccupationDialog(BuildContext context, {VoidCallback? onUpdated}) {
    final initialOccupation =
        localStorageManager.userMap['Occupation']?.toString();
    String? selectedOccupation = initialOccupation;
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          clipBehavior: Clip.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What’s your hustle? Tell us your job title, and we'll tailor your experience accordingly.",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 20),

                // 👇 Your occupation dropdown here
                DropdownFlutter<String>(
                  hintText: 'Select Job Role',
                  initialItem: initialOccupation,
                  items: initialProfileController.occupationList,
                  onChanged: (value) {
                    selectedOccupation = value;
                  },
                  decoration: CustomDropdownDecoration(
                    hintStyle: TextStyle(color: AppColors.primaryColor),
                    headerStyle: TextStyle(color: AppColors.primaryColor),
                    //closedBorder: Border.all(color: Colors.transparent),
                    closedFillColor:
                        isDarkMode ? Colors.black45 : scaffoldColorLight,
                    expandedFillColor:
                        isDarkMode ? Colors.black87 : scaffoldColorLight,
                  ),
                ),

                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      if (selectedOccupation != null &&
                          selectedOccupation!.isNotEmpty) {
                        localStorageManager.userMap['Occupation'] =
                            selectedOccupation;
                        occupation = selectedOccupation!;
                        await saveOccupation(
                          context,
                          selectedOccupation!,
                          day: DateTime.now().day,
                          month: DateTime.now().month,
                          year: DateTime.now().year,
                          time: TimeOfDay.now().format(context),
                        );
                      }
                      Navigator.pop(ctx);
                      if (onUpdated != null) onUpdated!();
                    },
                    child: Text(
                      "Update",
                      style: TextStyle(
                        color:
                            isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showDOBDialog(BuildContext context, {VoidCallback? onUpdated}) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    DateTime? selectedDate;
    final day = localStorageManager.userMap['DayOfBirth'];
    final month = localStorageManager.userMap['MonthOfBirth'];
    final year = localStorageManager.userMap['YearOfBirth'];

    if (day != null && month != null && year != null) {
      selectedDate = DateTime(year, month, day);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (BuildContext statefulContext, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Age is just a number, but yours might bring you perks! When were you born?",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 👇 Date picker trigger
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          // ⚡ use root context (not dialogContext)
                          context: context,
                          initialDate: selectedDate ?? DateTime(2000),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: mediumGrey, width: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedDate != null
                                  ? DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(selectedDate!)
                                  : 'Tap to select date',
                              style: TextStyle(fontSize: 14),
                            ),
                            Icon(
                              Icons.calendar_today,
                              color: AppColors.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          if (selectedDate != null) {
                            localStorageManager.userMap['DayOfBirth'] =
                                selectedDate!.day;
                            localStorageManager.userMap['MonthOfBirth'] =
                                selectedDate!.month;
                            localStorageManager.userMap['YearOfBirth'] =
                                selectedDate!.year;
                            updateField('DayOfBirth', selectedDate!.day);
                            updateField('MonthOfBirth', selectedDate!.month);
                            updateField('YearOfBirth', selectedDate!.year);
                            await saveDOB(selectedDate!, context);
                          }
                          setState(() {});
                          Navigator.pop(dialogContext);
                          if (onUpdated != null) onUpdated!();
                        },
                        child: Text(
                          "Update",
                          style: TextStyle(
                            color:
                                isDarkMode
                                    ? scaffoldColorDark
                                    : scaffoldColorLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool> saveName(String name, BuildContext context) async {
    return _saveField(context, 'Value', name, userNameApi);
  }

  Future<bool> saveAddress(String name, BuildContext context) async {
    return _saveField(context, 'Address', name, userAddressApi);
  }

  // Future<bool> SaveEmail(String email) async {
  //   return _saveField('Email', email, endpoint)
  // }

  // Future<bool> SavePhoneNumber(String phone) async {
  //   return _saveField('PhoneNumber', phone);
  // }

  Future<bool> saveHeight(
    BuildContext context,
    double height, {
    required int day,
    required int month,
    required int year,
    required String time,
  }) async {
    return _saveField(
      context,

      'Value',

      height,
      userHeightApi,
      payloadExtras: {'Day': day, 'Month': month, 'Year': year, 'Time': time},
    );
  }

  Future<bool> saveWeight(
    BuildContext context,
    double weight, {
    required int day,
    required int month,
    required int year,
    required String time,
  }) async {
    return _saveField(
      context,
      'Value',

      weight,
      userWeightApi,
      payloadExtras: {'Day': day, 'Month': month, 'Year': year, 'Time': time},
    );
  }

  Future<bool> saveGender(String gender, BuildContext context) async {
    return _saveField(context, 'Value', gender, userGenderApi);
  }

  Future<bool> saveOccupation(
    BuildContext context,
    String occupation, {
    required int day,
    required int month,
    required int year,
    required String time,
  }) async {
    return _saveField(
      context,
      'Name',

      occupation,
      userOccupationApi,
      payloadExtras: {'Day': day, 'Month': month, 'Year': year, 'Time': time},
    );
  }

  /// Optional: if DOB requires special payload, you can create a custom function for DOB below.
  Future<bool> saveDOB(DateTime date, BuildContext context) async {
    Map<String, dynamic> payload = {
      'DayOfBirth': date.day,
      'MonthOfBirth': date.month,
      'YearOfBirth': date.year,
    };

    try {
      final response = await ApiService.post(
        userDobApi, // replace with your correct API endpoint
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save DOB: ${response.statusCode}',
        );
        return false;
      }
      CustomSnackbar.showSuccess(
        context: context,
        title: 'Success',
        message: '',
      );
      return true;
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving DOB',
      );
      return false;
    }
  }

  Future<bool> _saveField(
    BuildContext context,
    String key,

    dynamic value,
    dynamic endpoint, {
    Map<String, Object>? payloadExtras,
  }) async {
    try {
      Map<String, dynamic> payload = {
        if (payloadExtras != null) ...payloadExtras,
        key: value,
      };

      final response = await ApiService.post(
        endpoint, // ⚡ you can change this per field if needed
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to save $key: ${response.statusCode}',
        );
        return false;
      }

      return true;
    } catch (e) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed saving $key',
      );
      return false;
    }
  }
}
