import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Widgets/old_device_alert.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/services/auth_service.dart';
import 'package:snevva/services/device_token_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';

import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignInController extends GetxService {
  dynamic userProfData = {};
  dynamic userGoalData = {};
  //final authService = Get.find<AuthService>();

  final localStorage = Get.find<LocalStorageManager>();

  Future<bool> signInUsingEmail(
    String email,
    String password,
    BuildContext context,
  ) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: "Error",
        message: "Email cannot be empty",
      );
      return false;
    }

    final plainEmail = jsonEncode({'Gmail': email, 'Password': password});

    try {
      final uri = Uri.parse("$baseUrl$signInEmailEndpoint");
      debugPrint("URI: $uri");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['x-data-hash'] = encryptedEmail['Hash']!;

      // ✅ Always set device info
      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;

      // debugPrint("📱 X-Device-Info: $deviceInfoHeader");
      // debugPrint("📦 Headers: $headers");

      // debugPrint("extra headers $extraHeaders");
      // debugPrint("devive headers ${headers['X-Device-Info']}");
      // debugPrint("final headers $headers");

      // debugPrint("Headers: $headers");

      final encryptedRequestBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      debugPrint(response.body);

      // ❌ FIX 1 — real condition
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        debugPrint("response Body: $responseBody");

        // ❌ FIX 2 — rename var
        final encryptedResponse = responseBody['data'];
        debugPrint("👉 Encrypted token response: $encryptedResponse");

        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        debugPrint("Decrypted token response: $decrypted\n");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        // ❌ FIX 3 — check server status
        // if (responseData['status'] != true) {
        //   CustomSnackbar.showError(context: context , title: "Error", message:  "Wrong credentials");
        //   return false;
        // }

        // token
        final dynamic tokenRaw = responseData['data'];

        if (tokenRaw == null || tokenRaw is! String || tokenRaw.isEmpty) {
          debugPrint('❌ Invalid token received: $tokenRaw');

          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Invalid login token received',
          );

          return false;
        }

        final String token = tokenRaw;
        debugPrint('✅ JWT Token: $token');

        final prefs = await SharedPreferences.getInstance();
        debugPrint('🧠 SharedPreferences instance obtained');

        debugPrint('🔐 Saving auth_token...');
        await prefs.setString('auth_token', token);
        debugPrint('✅ auth_token saved');

        // ================== USER INFO ==================
        debugPrint('📡 Fetching userInfo()...');
        final userdata = await userInfo();
        debugPrint('📥 Raw userdata response: $userdata');

        final userProfileData = userdata['data'];
        debugPrint('👤 userProfileData: $userProfileData');
        debugPrint(
          '👤 userProfileData runtimeType: ${userProfileData.runtimeType}',
        );

        final gender = userdata['data']?['Gender'];
        debugPrint('🚻 Gender from API: $gender (type: ${gender.runtimeType})');

        if (gender != null) {
          await prefs.setString('user_gender', gender.toString());
          debugPrint('✅ user_gender saved: $gender');
        } else {
          await prefs.setString('user_gender', '');
          debugPrint('⚠️ user_gender was NULL — saved empty string');
        }

        debugPrint('🗂 Saving userProfileData into localstorage.userMap...');
        localStorage.userMap.value = userProfileData;
        debugPrint('✅ localstorage.userMap updated');

        if (userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
          debugPrint('💾 userdata saved to SharedPreferences');
        } else {
          debugPrint(
            '❌ userProfileData is NOT a Map — skipped saving userdata',
          );
        }

        // ================== USER GOAL DATA ==================
        debugPrint('📡 Fetching useeractivedataInfo()...');
        final goaldata = await useeractivedataInfo();
        debugPrint('📥 Raw goaldata response: $goaldata');

        final data = goaldata['data'];
        debugPrint('🎯 user goal data: $data');
        debugPrint('🎯 user goal data runtimeType: ${data.runtimeType}');

        localStorage.userGoalDataMap.value = data;

        if (data is Map) {
          final userGoalJson = jsonEncode(data);
          await prefs.setString('userGoaldata', userGoalJson);
          debugPrint('💾 userGoaldata saved to SharedPreferences');
        } else {
          debugPrint('⚠️ userGoaldata is NOT a Map — nothing saved');
        }

        debugPrint('🏁 Sign-in data pipeline COMPLETED');

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        return true;
      }
      // Wrong input
      else if (response.statusCode == 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Wrong Credentials',
        );
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final responseBody = jsonDecode(response.body);
        debugPrint("response Body: $responseBody");

        final encryptedResponse = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        debugPrint("Decrypted logout response: $decrypted\n");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        debugPrint("resonsedata $responseData");

        // ✅ Extract ONLY the Base64 string
        final String? encodedDeviceInfo = responseData['data']?['DeviceInfo'];

        if (encodedDeviceInfo == null || encodedDeviceInfo.isEmpty) {
          debugPrint("❌ DeviceInfo missing in response");
          return false;
        }

        // ✅ Decode Base64 → JSON → Map
        final Map<String, dynamic> oldDeviceInfoMap = DeviceTokenService()
            .decodeDeviceInfoHeader(encodedDeviceInfo);

        debugPrint("oldDeviceInfoMap: $oldDeviceInfoMap");

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return OldDeviceAlert(
              deviceInfo: oldDeviceInfoMap,

              onConfirmDevice: () {
                AuthService.devicelogout(encodedDeviceInfo);
                Navigator.pop(context);
              },

              onRejectDevice: () {
                Navigator.pop(context);
                CustomSnackbar.showDeviceBlocked(context: context);
              },
            );
          },
        );

        return false;
      }
      // Other failures
      else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Sign In failed.',
        );
        return false;
      }
    } catch (e, st) {
      debugPrint("sign in screen email $e  $st");
      // CustomSnackbar.showDeviceBlocked(context: context);
      return false;
    }
  }

  Future<dynamic> userInfo() async {
    final response = await ApiService.post(
      userprofileInfo,
      null,
      withAuth: true,
      encryptionRequired: false,
    );
    // debugPrint("$response");
    userProfData = response;
    localStorage.userMap.value = userProfData['data'];
    return userProfData;
  }

  Future<dynamic> useeractivedataInfo() async {
    final response = await ApiService.post(
      useractivedata,
      null,
      withAuth: true,
      encryptionRequired: false,
    );
    // debugPrint("$response");
    userGoalData = response;
    localStorage.userGoalDataMap.value = userGoalData['data'];
    return userGoalData;
  }

  // Future<dynamic> useeractivedataInfo() async{
  //   final response = await ApiService.post(
  //     useractivedata,
  //     null,
  //     withAuth: true,
  //     encryptionRequired: false,
  //   );
  //   // debugPrint("$response");
  //   return response;
  // }

  Future<bool> signInUsingPhone(
    String phone,
    String password,
    BuildContext context,
  ) async {
    if (phone.isEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Phone cannot be empty',
      );
      return false;
    }

    final plainPhone = jsonEncode({'PhoneNumber': phone, 'Password': password});

    try {
      final uri = Uri.parse("$baseUrl$signInPhoneEndpoint");
      final encryptedPhone = EncryptionService.encryptData(plainPhone);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['x-data-hash'] = encryptedPhone['Hash']!;

      // ✅ Always set device info
      final deviceInfoHeader =
          await DeviceTokenService().buildDeviceInfoHeader();
      headers['X-Device-Info'] = deviceInfoHeader;

      debugPrint("📱 X-Device-Info: $deviceInfoHeader");
      debugPrint("📦 Headers: $headers");

      final encryptedRequestBody = jsonEncode({
        'data': encryptedPhone['encryptedData'],
      });
      debugPrint("encryptedRequestBody, $encryptedRequestBody");

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      debugPrint(response.body);
      debugPrint(response.statusCode.toString());

      // ❌ FIX #1 — real condition
      // ❌ FIX 1 — real condition
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        debugPrint("response Body: $responseBody");

        // ❌ FIX 2 — rename var
        final encryptedResponse = responseBody['data'];
        debugPrint("👉 Encrypted token response: $encryptedResponse");

        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        debugPrint("Decrypted token response: $decrypted\n");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        // ❌ FIX 3 — check server status
        // if (responseData['status'] != true) {
        //   CustomSnackbar.showError(context: context , title: "Error", message:  "Wrong credentials");
        //   return false;
        // }

        // token
        final dynamic tokenRaw = responseData['data'];

        if (tokenRaw == null || tokenRaw is! String || tokenRaw.isEmpty) {
          debugPrint('❌ Invalid token received: $tokenRaw');

          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Invalid login token received',
          );

          return false;
        }

        final String token = tokenRaw;
        debugPrint('✅ JWT Token: $token');

        final prefs = await SharedPreferences.getInstance();
        debugPrint('🧠 SharedPreferences instance obtained');

        debugPrint('🔐 Saving auth_token...');
        await prefs.setString('auth_token', token);
        debugPrint('✅ auth_token saved');

        // ================== USER INFO ==================
        debugPrint('📡 Fetching userInfo()...');
        final userdata = await userInfo();
        debugPrint('📥 Raw userdata response: $userdata');

        final userProfileData = userdata['data'];
        debugPrint('👤 userProfileData: $userProfileData');
        debugPrint(
          '👤 userProfileData runtimeType: ${userProfileData.runtimeType}',
        );

        final gender = userdata['data']?['Gender'];
        debugPrint('🚻 Gender from API: $gender (type: ${gender.runtimeType})');

        if (gender != null) {
          await prefs.setString('user_gender', gender.toString());
          debugPrint('✅ user_gender saved: $gender');
        } else {
          await prefs.setString('user_gender', '');
          debugPrint('⚠️ user_gender was NULL — saved empty string');
        }

        debugPrint('🗂 Saving userProfileData into localstorage.userMap...');
        localStorage.userMap.value = userProfileData;
        debugPrint('✅ localstorage.userMap updated');

        if (userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
          debugPrint('💾 userdata saved to SharedPreferences');
        } else {
          debugPrint(
            '❌ userProfileData is NOT a Map — skipped saving userdata',
          );
        }

        // ================== USER GOAL DATA ==================
        debugPrint('📡 Fetching useeractivedataInfo()...');
        final goaldata = await useeractivedataInfo();
        debugPrint('📥 Raw goaldata response: $goaldata');

        final data = goaldata['data'];
        debugPrint('🎯 user goal data: $data');
        debugPrint('🎯 user goal data runtimeType: ${data.runtimeType}');

        localStorage.userGoalDataMap.value = data;

        if (data is Map) {
          final userGoalJson = jsonEncode(data);
          await prefs.setString('userGoaldata', userGoalJson);
          debugPrint('💾 userGoaldata saved to SharedPreferences');
        } else {
          debugPrint('⚠️ userGoaldata is NOT a Map — nothing saved');
        }

        debugPrint('🏁 Sign-in data pipeline COMPLETED');

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        return true;
      } else if (response.statusCode == 400) {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Wrong Credentials',
        );
        return false;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        final responseBody = jsonDecode(response.body);
        debugPrint("response Body: $responseBody");

        final encryptedResponse = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        debugPrint("Decrypted logout response: $decrypted\n");

        if (decrypted == null) {
          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Failed to decrypt response',
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        debugPrint("resonsedata $responseData");

        // ✅ Extract ONLY the Base64 string
        final String? encodedDeviceInfo = responseData['data']?['DeviceInfo'];

        if (encodedDeviceInfo == null || encodedDeviceInfo.isEmpty) {
          debugPrint("❌ DeviceInfo missing in response");
          return false;
        }

        // ✅ Decode Base64 → JSON → Map
        final Map<String, dynamic> oldDeviceInfoMap = DeviceTokenService()
            .decodeDeviceInfoHeader(encodedDeviceInfo);

        debugPrint("oldDeviceInfoMap: $oldDeviceInfoMap");

        // token
        final dynamic olddeviceinfo = responseData['data'];

        debugPrint("olddeviceinfo $olddeviceinfo");

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            return OldDeviceAlert(
              deviceInfo: oldDeviceInfoMap,

              onConfirmDevice: () {
                AuthService.devicelogout(encodedDeviceInfo);
                Navigator.pop(context);

                // TODO: Call API to confirm device
                // confirmDeviceLogin(oldDeviceInfoMap);
              },

              onRejectDevice: () {
                CustomSnackbar.showDeviceBlocked(context: context);
                Navigator.pop(context);

                // TODO: Call API to block device / logout all sessions
              },
            );
          },
        );

        return false;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Sign In failed.',
        );
        return false;
      }
    } catch (e, st) {
      debugPrint("sign in phone $e $st");
      CustomSnackbar.showError(
        context: context,
        title: 'Exception',
        message: 'Sign In failed $e',
      );
      return false;
    }
  }
}
