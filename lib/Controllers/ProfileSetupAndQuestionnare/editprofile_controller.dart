import 'dart:async';

import 'package:dropdown_flutter/custom_dropdown.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:snevva/Controllers/ProfileSetupAndQuestionnare/profile_setup_controller.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/env/env.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/notification_service.dart';

import '../BMI/bmi_updatecontroller.dart';
import '../local_storage_manager.dart';
import '../signupAndSignIn/otp_verification_controller.dart';
import '../signupAndSignIn/sign_up_controller.dart';

void showError(String message) {
  Get.snackbar(
    'Heads up',
    message,
    snackPosition: SnackPosition.TOP,
    backgroundColor: const Color(0xFF1A1A2E),
    colorText: Colors.white,
    duration: const Duration(seconds: 3),
    borderRadius: 12,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    icon: const Icon(Icons.error_rounded, color: Color(0xFFFF4D6D)),
    shouldIconPulse: false,
  );
}

void showSuccess(String message) {
  // Get.snackbar(
  //   'All set',
  //   message,
  //   snackPosition: SnackPosition.TOP,
  //   backgroundColor: const Color(0xFF1A1A2E),
  //   colorText: Colors.white,
  //   duration: const Duration(seconds: 3),
  //   borderRadius: 12,
  //   margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //   icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF7C4DFF)),
  //   shouldIconPulse: false,
  // );
}

class EditprofileController extends GetxService {
  final localStorageManager = Get.find<LocalStorageManager>();
  final signupController = Get.find<SignUpController>();
  late OTPVerificationController otpVerificationController;
  late ProfileSetupController initialProfileController;
  late bool otpVerificationStatus;
  final otp = null;
  final notify = NotificationService();

  DateTime? dob;
  var name = '';
  RxString email = ''.obs;
  var phoneNumber = '';
  var heightValue = '';
  var weightValue = '';

  // var gender = '';
  RxString gender = ''.obs;
  var occupation = '';
  var address = '';
  var postalCode = '';

  var isLoading = false.obs; // For showing updateFieldloader on buttons
  var isResendEnabled = true.obs; // For enabling/disabling resend
  var resendTimer = 0.obs; // For showing countdown
  Timer? _resendCountdownTimer;

  // ─── Shared snackbar style helpers ───────────────────────────────────────


  // ─────────────────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    otpVerificationController = Get.find<OTPVerificationController>();
    initialProfileController = Get.find<ProfileSetupController>();

    // ✅ Seed gender immediately so Obx widgets never render with empty gender
    _syncGenderFromStorage();

    // ✅ Keep gender in sync if userMap is reloaded (e.g. after login)
    ever(localStorageManager.userMap, (_) => _syncGenderFromStorage());
  }

  void _syncGenderFromStorage() {
    final storedGender =
        localStorageManager.userMap['Gender']?.toString() ?? '';
    // ✅ Guard: only update if value actually changed — prevents unnecessary
    // Obx rebuilds in DashboardServicesWidget on repeated userMap refreshes.
    if (storedGender.isNotEmpty &&
        storedGender != 'null' &&
        storedGender != gender.value) {
      gender.value = storedGender;
    }
  }

  Future<void> updateField(String key, dynamic value) async {
    switch (key) {
      case 'Name':
        localStorageManager.userMap['Name'] = value;
        name = value;
        await localStorageManager.saveUserMap();
        break;

      case 'Email':
        localStorageManager.userMap['Email'] = value;
        email.value = value;
        await localStorageManager.saveUserMap();
        break;

      case 'PhoneNumber':
        localStorageManager.userMap['PhoneNumber'] = value;
        phoneNumber = value;
        await localStorageManager.saveUserMap();
        break;

      case 'Height':
        heightValue = value;
        await localStorageManager.updateGoalField('HeightData', {
          ...localStorageManager.userGoalDataMap['HeightData'] ?? {},
          'Value': double.tryParse(value.toString()),
        });
        break;

      case 'Weight':
        weightValue = value;
        await localStorageManager.updateGoalField('WeightData', {
          ...localStorageManager.userGoalDataMap['WeightData'] ?? {},
          'Value': double.tryParse(value.toString()),
        });
        break;

      case 'DayOfBirth':
        localStorageManager.userMap['DayOfBirth'] = value;
        await localStorageManager.saveUserMap();
        break;
      case 'MonthOfBirth':
        localStorageManager.userMap['MonthOfBirth'] = value;
        await localStorageManager.saveUserMap();
        break;
      case 'YearOfBirth':
        localStorageManager.userMap['YearOfBirth'] = value;
        await localStorageManager.saveUserMap();
        break;

      case 'Gender':
        localStorageManager.userMap['Gender'] = value;
        gender.value = value;
        await localStorageManager.saveUserMap();
        break;

      case 'Occupation':
        localStorageManager.userMap['Occupation'] = value;
        occupation = value;
        await localStorageManager.saveUserMap();
        break;

      case 'Address':
        localStorageManager.userMap['AddressByUser'] = value;
        address = value;
        await localStorageManager.saveUserMap();
        break;

      case 'PostalCode':
        localStorageManager.userMap['PostalCodeUser'] = value;
        postalCode = value;
        await localStorageManager.saveUserMap();
        break;
    }
  }

  void updateDob({int? day, int? month, int? year}) {
    final current = dob ?? DateTime.now();

    dob = DateTime(
      year ?? current.year,
      month ?? current.month,
      day ?? current.day,
    );
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

  void showEditFieldDialog(BuildContext context, {
    required String title,
    required String fieldKey,
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                        case 'PostalCode':
                          return 'Enter your postal code';
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
                      () =>
                      SizedBox(
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

                        // ─── Validation ───────────────────────────

                        if (fieldKey == 'Name') {
                          final nameRegex = RegExp(r"^[a-zA-Z\s]+$");
                          final capNameRegex = RegExp(r'^[A-Z][a-zA-Z\s]*$');
                          if (value.isEmpty) {
                            showError(
                              'Your name can\'t be blank. Please enter your full name.',
                            );
                            isLoading.value = false;
                            return;
                          }
                          if (!nameRegex.hasMatch(value)) {
                            showError(
                              'Names can only contain letters and spaces — no numbers or symbols.',
                            );
                            isLoading.value = false;
                            return;
                          }
                          if (!capNameRegex.hasMatch(value)) {
                            showError(
                              'Name must start with a capital letter and contain only letters and spaces.',
                            );
                            isLoading.value = false;
                            return;
                          }
                        }

                        if (fieldKey == 'Height') {
                          if (height == null || height <= 0) {
                            showError(
                              'Please enter a valid height in centimetres (e.g. 170).',
                            );
                            isLoading.value = false;
                            return;
                          }
                        }

                        if (fieldKey == 'Weight') {
                          if (weight == null || weight <= 0) {
                            showError(
                              'Please enter a valid weight in kilograms (e.g. 65).',
                            );
                            isLoading.value = false;
                            return;
                          }
                        }

                        if (fieldKey == 'PhoneNumber') {
                          final phoneRegex = RegExp(r"^[0-9]{10}$");
                          if (value.isEmpty) {
                            showError(
                              'Field cannot be empty',
                            );
                            isLoading.value = false;
                            return;
                          }
                          if (!phoneRegex.hasMatch(value)) {
                            showError(
                              'Please enter a valid 10-digit mobile number.',
                            );
                            isLoading.value = false;
                            return;
                          }

                          try {
                            final result = await signupController
                                .phoneotp(value, context);

                            if (result != false && result != null) {
                              otpVerificationController
                                  .responseOtp
                                  .value = result;

                              Navigator.of(dialogCtx).pop();

                              Future.delayed(
                                const Duration(milliseconds: 150),
                                    () {
                                  updatephoneDialog(
                                    context,
                                    title: "Verify your Number",
                                    fieldKey: "PhoneNumber",
                                    initialValue: value,
                                    onUpdated: onUpdated,
                                  );
                                },
                              );
                            } else {
                              isLoading.value = false;
                            }
                          } catch (e) {
                            debugPrint(
                              'Error during phone OTP process: $e',
                            );
                            showError(
                              'Something went wrong while sending the OTP. Please try again in a moment.',
                            );
                            isLoading.value = false;
                          } finally {
                            isLoading.value = false;
                          }

                          return;
                        }

                        // ─── Email ────────────────────────────────

                        if (fieldKey == 'Email') {
                          final emailRegex = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,9}$',
                          );

                          if (value.isEmpty) {
                            showError(
                              'Email address can\'t be blank. Please enter a valid email.',
                            );
                            isLoading.value = false;
                            return;
                          }
                          if (!emailRegex.hasMatch(value)) {
                            showError(
                              'That doesn\'t look like a valid email. Try something like name@example.com.',
                            );
                            isLoading.value = false;
                            return;
                          }

                          try {
                            final result = await signupController
                                .gmailOtp(value, context);

                            if (result != false && result != null) {
                              otpVerificationController
                                  .responseOtp
                                  .value = result;

                              Navigator.of(dialogCtx).pop();

                              Future.delayed(
                                const Duration(milliseconds: 150),
                                    () {
                                  updateemailDialog(
                                    context,
                                    title: "Verify your email",
                                    fieldKey: "Email",
                                    initialValue: value,
                                    onUpdated: onUpdated,
                                  );
                                },
                              );
                            } else {
                              showError(
                                'We couldn\'t send the OTP to this email. Please double-check and try again.',
                              );
                              isLoading.value = false;
                            }
                          } catch (e) {
                            debugPrint('Error sending OTP: $e');
                            showError(
                              'Something went wrong while sending the OTP. Please try again shortly.',
                            );
                            isLoading.value = false;
                          } finally {
                            isLoading.value = false;
                          }

                          return;
                        }

                        // ─── Other fields ─────────────────────────

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
                              day: DateTime
                                  .now()
                                  .day,
                              month: DateTime
                                  .now()
                                  .month,
                              year: DateTime
                                  .now()
                                  .year,
                              time: TimeOfDay.now().format(context),
                            );
                            final bmiController =
                            Get.find<BmiUpdateController>();
                            bmiController.height.value = height!;
                            isLoading.value = false;
                            break;
                          case 'Weight':
                            await saveWeight(
                              context,
                              weight!,
                              day: DateTime
                                  .now()
                                  .day,
                              month: DateTime
                                  .now()
                                  .month,
                              year: DateTime
                                  .now()
                                  .year,
                              time: TimeOfDay.now().format(context),
                            );
                            final bmiController =
                            Get.find<BmiUpdateController>();
                            bmiController.weight.value = weight!;
                            isLoading.value = false;
                            break;
                          case 'Address':
                            await saveAddress(value, context);
                            isLoading.value = false;
                            break;
                          case 'PostalCode':
                            await savePostalCode(value, context);
                            isLoading.value = false;
                            break;
                        }

                        Navigator.of(dialogCtx).pop();
                        if (onUpdated != null) onUpdated();
                      },
                      child: AppLoadingButtonChild(
                        isLoading: isLoading.value,
                        loaderSize: 20,
                        child: Text(
                          "Update",
                          style: TextStyle(
                            color:
                            isDarkMode ? white : black)),
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

  void openNextMissingFieldDialog(BuildContext context,
      {VoidCallback? onUpdated}) {
    final userInfo = localStorageManager.userMap;

    if (!_isFilled(userInfo['PhoneNumber'])) {
      showEditFieldDialog(
        context,
        title: 'Add Phone Number',
        fieldKey: 'PhoneNumber',
        initialValue: userInfo['PhoneNumber']?.toString() ?? '',
        onUpdated: onUpdated,
      );
      return;
    }

    if (!_isFilled(userInfo['Email'])) {
      showEditFieldDialog(
        context,
        title: 'Add Email',
        fieldKey: 'Email',
        initialValue: userInfo['Email']?.toString() ?? '',
        onUpdated: onUpdated,
      );
      return;
    }

    if (!_isFilled(userInfo['PostalCodeUser'])) {
      showEditFieldDialog(
        context,
        title: 'Add Postal Code',
        fieldKey: 'PostalCode',
        initialValue: userInfo['PostalCodeUser']?.toString() ?? '',
        onUpdated: onUpdated,
      );
      return;
    }

    if (!_isFilled(userInfo['AddressByUser'])) {
      showAddressDialog(
        context,
        initialValue: userInfo['AddressByUser']?.toString() ?? '',
        onUpdated: onUpdated,
      );
      return;
    }
  }

  // Splits a previously saved combined address string back into its 3 parts.
  // Expected format: "HouseNo, Street, City/State"
  List<String> _splitAddress(String combined) {
    final parts = combined.split(',').map((s) => s.trim()).toList();
    return [
      parts.isNotEmpty ? parts[0] : '',
      parts.length > 1 ? parts[1] : '',
      parts.length > 2 ? parts.sublist(2).join(', ') : '',
    ];
  }

  void showAddressDialog(BuildContext context, {
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    final parts = _splitAddress(initialValue);
    final houseCtrl = TextEditingController(text: parts[0]);
    final streetCtrl = TextEditingController(text: parts[1]);
    final cityCtrl = TextEditingController(text: parts[2]);
    final bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color dialogColor = isDarkMode
        ? const Color(0xFF19131F)
        : scaffoldColorLight;
    final Color cardColor = isDarkMode
        ? Colors.white.withOpacity(0.10)
        : AppColors.primaryColor.withOpacity(0.08);
    final Color borderColor = AppColors.primaryColor.withOpacity(0.20);
    final Color textColor = isDarkMode ? white : black;
    final Color helperColor = isDarkMode
        ? Colors.white.withOpacity(0.58)
        : mediumGrey;

    InputDecoration inputDecoration(String hintText) {
      return InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: helperColor,
          fontFamily: 'Inter',
          fontSize: 13,
        ),
        filled: true,
        fillColor: isDarkMode ? Colors.white.withOpacity(0.08) : white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDarkMode ? Colors.white24 : Colors.black26,
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: AppColors.primaryColor,
            width: 1.4,
          ),
        ),
      );
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: dialogColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      boxShadow: isDarkMode
                          ? []
                          : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    initialValue
                                        .trim()
                                        .isEmpty
                                        ? 'Add Address'
                                        : 'Update Address',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Keep your profile location details complete.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: helperColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: houseCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(color: textColor),
                          decoration: inputDecoration('House / Flat number'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: streetCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(color: textColor),
                          decoration: inputDecoration('Street name'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: cityCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(color: textColor),
                          decoration: inputDecoration('City and state'),
                        ),
                        const SizedBox(height: 18),
                        Obx(
                              () =>
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      disabledBackgroundColor: Colors
                                          .transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: white,
                                      disabledForegroundColor: white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                      textStyle: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: isLoading.value
                                        ? null
                                        : () async {
                                      final house = houseCtrl.text.trim();
                                      final street = streetCtrl.text.trim();
                                      final city = cityCtrl.text.trim();

                                      if (house.isEmpty ||
                                          street.isEmpty ||
                                          city.isEmpty) {
                                        showError(
                                          'Please fill in all three address fields.',
                                        );
                                        return;
                                      }

                                      final combined =
                                          '$house, $street, $city';
                                      isLoading.value = true;
                                      await updateField('Address', combined);
                                      await saveAddress(combined, context);
                                      isLoading.value = false;
                                      if (dialogCtx.mounted) {
                                        Navigator.of(dialogCtx).pop();
                                      }
                                      onUpdated?.call();
                                    },
                                    child: AppLoadingButtonChild(
                                      isLoading: isLoading.value,
                                      loaderSize: 20,
                                      child: const Text(
                                        'Update',
                                        style: TextStyle(color: white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: helperColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// Private helper (mirrors isFilled in the card)
  bool _isFilled(dynamic value) {
    if (value == null) return false;
    if (value is String && value
        .trim()
        .isEmpty) return false;
    return true;
  }
  void updateemailDialog(BuildContext context, {
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

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),

                Image.asset(
                  veriemail,
                  height: 180,
                  width: 180,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox();
                  },
                ),

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
                    otpVerificationStatus = otpVerificationController.verifyOtp(
                      pin,
                      otpVerificationController.responseOtp.value,
                      ctx,
                      isEditPassword: true,
                    );

                    if (otpVerificationStatus) {
                      await localStorageManager.updateUserField(
                        'Email',
                        initialValue,
                      );

                      email.value = initialValue;

                      await signupController.updateGmail(initialValue, ctx);

                      showSuccess(
                        'Your email has been updated to $initialValue. A confirmation has been sent.',
                      );
                      if (onUpdated != null) onUpdated();
                      Navigator.pop(ctx);
                    }
                  },
                ),

                const SizedBox(height: 15),

                Obx(
                      () =>
                      InkWell(
                    onTap:
                    isResendEnabled.value
                        ? () async {
                      isResendEnabled.value = false;
                      startResendTimer(seconds: 30);

                      final result = await signupController.gmailOtp(
                        value,
                        ctx,
                      );

                      if (result != false && result != null) {
                        otpVerificationController.responseOtp.value =
                            result;
                        showSuccess(
                          'A fresh verification code has been sent to $value.',
                        );
                      } else {
                        showError(
                          'We couldn\'t resend the code. Please wait a moment and try again.',
                        );
                      }
                    }
                        : null,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return AppColors.primaryGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        );
                      },
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

  void updatephoneDialog(BuildContext context, {
    required String title,
    required String fieldKey,
    required String initialValue,
    VoidCallback? onUpdated,
  }) {
    showDialog(
      context: context,
      builder:
          (ctx) =>
          _PhoneOtpDialog(
            phoneNumber: initialValue.trim(),
            ctrl: this,
            onUpdated: onUpdated,
          ),
    );
  }

  void showGenderDialog(BuildContext context, {VoidCallback? onUpdated}) {
    final String? selectedGender = localStorageManager.userMap['Gender'];

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    void selectGender(String Usergender) async {
      localStorageManager.userMap['Gender'] = Usergender;
      gender.value = Usergender;
      await localStorageManager.saveUserMap();
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
                  "You do you! Choose how you identify, or select 'Prefer not to say' if you're not into labels.",
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
    localStorageManager.userMap['OccupationData']?['Name']?.toString();
    String? selectedOccupation = initialOccupation;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                  "What's your hustle? Tell us your job title, and we'll tailor your experience accordingly.",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 20),

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
                    closedFillColor:
                    isDarkMode ? Colors.transparent : scaffoldColorLight,
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
                        localStorageManager.userMap['OccupationData'] ??= {};
                        localStorageManager.userMap['OccupationData']['Name'] =
                            selectedOccupation;
                        occupation = selectedOccupation!;
                        await localStorageManager.saveUserMap();
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
                      if (onUpdated != null) onUpdated();
                    },
                    child: Text(
                      "Update",
                      style: TextStyle(
                        color:
                        isDarkMode ? scaffoldColorLight : scaffoldColorDark,
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

  DateTime safeInitialDate(DateTime? date) {
    final firstDate = DateTime(1900);
    final lastDate = DateTime.now();

    if (date == null) return lastDate;
    if (date.isBefore(firstDate)) return firstDate;
    if (date.isAfter(lastDate)) return lastDate;

    return date;
  }

  void showDOBDialog(BuildContext context, {VoidCallback? onUpdated}) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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

                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: safeInitialDate(selectedDate),
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
                                  ? DateFormat('dd/MM/yyyy').format(
                                selectedDate!,
                              )
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
                            await localStorageManager.saveUserMap();
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

  Future<bool> savePostalCode(String value, BuildContext context) async {
    return _saveField(context, 'PostalCode', value, userAddressApi);
  }

  Future<bool> saveHeight(BuildContext context,
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

  Future<bool> saveWeight(BuildContext context,
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

  Future<bool> saveOccupation(BuildContext context,
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

  Future<bool> saveDOB(DateTime date, BuildContext context) async {
    try {
      Map<String, dynamic> payload = {
        'DayOfBirth': date.day,
        'MonthOfBirth': date.month,
        'YearOfBirth': date.year,
      };
      debugPrint('🚀 [Save DOB] Payload: $payload');

      final response = await ApiService.post(
        userDobApi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        showError(
          'We couldn\'t save your date of birth right now (${response
              .statusCode}). Please try again.',
        );
        return false;
      }

      showSuccess('Your date of birth has been updated successfully.');
      return true;
    } catch (e) {
      showError(
        'Something went wrong while saving your date of birth. Please try again.',
      );
      return false;
    }
  }

  Future<bool> _saveField(BuildContext context,
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
        endpoint,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      if (response is http.Response) {
        showError(
          'We couldn\'t save your changes right now (${response
              .statusCode}). Please try again shortly.',
        );
        return false;
      }

      showSuccess(_successMessageFor(key));
      return true;
    } catch (e) {
      showError(
        'Something went wrong while saving your changes. Please check your connection and try again.',
      );
      return false;
    }
  }

  /// Returns a human-friendly success message for a given field key.
  String _successMessageFor(String key) {
    switch (key) {
      case 'Value':
        return 'Your profile has been updated successfully.';
      case 'Name':
        return 'Your name has been updated.';
      case 'Address':
        return 'Your address has been saved.';
      case 'Email':
        return 'Your email address has been updated.';
      case 'PhoneNumber':
        return 'Your mobile number has been updated.';
      default:
        return 'Your changes have been saved.';
    }
  }
}

class _PhoneOtpDialog extends StatefulWidget {
  final String phoneNumber;
  final EditprofileController ctrl;
  final VoidCallback? onUpdated;

  const _PhoneOtpDialog({
    required this.phoneNumber,
    required this.ctrl,
    this.onUpdated,
  });

  @override
  State<_PhoneOtpDialog> createState() => _PhoneOtpDialogState();
}

class _PhoneOtpDialogState extends State<_PhoneOtpDialog> {
  final _pinController = TextEditingController();
  final _smartAuth = SmartAuth.instance;

  @override
  void initState() {
    super.initState();
    _listenForSms();
  }

  Future<void> _listenForSms() async {
    final res = await _smartAuth.getSmsWithUserConsentApi();
    if (!mounted || !res.hasData) return;
    final code = res.requireData.code;
    if (code == null || code.length != 6) return;

    _pinController.text = code;
    _pinController.selection = TextSelection.fromPosition(
      TextPosition(offset: code.length),
    );

    if (!widget.ctrl.otpVerificationController.isVerifying.value) {
      await _handleVerify(code);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _smartAuth.removeSmsRetrieverApiListener();
    _smartAuth.removeUserConsentApiListener();
    super.dispose();
  }

  Future<void> _handleVerify(String pin) async {
    final ctrl = widget.ctrl;
    final status = ctrl.otpVerificationController.verifyOtp(
      pin,
      ctrl.otpVerificationController.responseOtp.value,
      context,
      isEditPassword: true,
    );
    ctrl.otpVerificationStatus = status;
    if (!status) return;

    ctrl.localStorageManager.userMap['PhoneNumber'] = widget.phoneNumber;
    ctrl.phoneNumber = widget.phoneNumber;
    await ctrl.localStorageManager.saveUserMap();
    await ctrl.signupController.updatePhone(ctrl.phoneNumber, context);

    showSuccess(
        'Your mobile number has been updated to ${widget.phoneNumber}.');
    if (widget.onUpdated != null) widget.onUpdated!();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Image.asset(veriemail, height: 180, width: 180),
            const SizedBox(height: 25),
            Text(
              'Enter the 6-digit code sent to\n${widget.phoneNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 25),
            Pinput(
              length: 6,
              controller: _pinController,
              defaultPinTheme: ctrl.defaultPinTheme,
              focusedPinTheme: ctrl.focusedPinTheme,
              submittedPinTheme: ctrl.submittedPinTheme,
              followingPinTheme: ctrl.followingPinTheme,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onCompleted: (pin) {
                debugPrint("Handle Verify button oncomplete");
                _handleVerify(pin);
              },
            ),
            const SizedBox(height: 15),
            Obx(
                  () =>
                  InkWell(
                    onTap:
                    ctrl.isResendEnabled.value
                        ? () async {
                      ctrl.isResendEnabled.value = false;
                      ctrl.startResendTimer(seconds: 30);
                      final result = await ctrl.signupController.phoneotp(
                        widget.phoneNumber,
                        context,
                      );
                      if (result != false && result != null) {
                        ctrl.otpVerificationController.responseOtp.value =
                            result;
                        showSuccess(
                          'A new verification code has been sent to ${widget
                              .phoneNumber}.',
                        );
                      } else {
                        showError(
                          'We couldn\'t resend the code. Please wait a moment and try again.',
                        );
                      }
                    }
                        : null,
                    child: ShaderMask(
                      shaderCallback:
                          (bounds) =>
                          AppColors.primaryGradient.createShader(
                            Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                          ),
                      child: Text(
                        ctrl.isResendEnabled.value
                            ? 'Resend code'
                            : 'Resend in ${ctrl.resendTimer.value}s',
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
  }
}
