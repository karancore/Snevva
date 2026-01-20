import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/SignUp/sign_in_screen.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignInController extends GetxController {
  dynamic userProfData = {};
  dynamic userGoalData = {};

  final localStorage = Get.find<LocalStorageManager>();

  Future<bool> signInUsingEmail(
    String email,
    String password,
    BuildContext context,
    String? extraHeaders,
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
      print("URI: $uri");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['X-Data-Hash'] = encryptedEmail['hash']!;

      if (extraHeaders != null) {
  headers['X-Device-Info'] = extraHeaders;
}

      debugPrint("extra headers $extraHeaders");
      debugPrint("devive headers $headers['X-Device-Info']");
      debugPrint("final headers $extraHeaders");


      debugPrint("Headers: $headers");
     

      final encryptedRequestBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      print(response.statusCode);
      print(response.body);

      // ❌ FIX 1 — real condition
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("response Body: $responseBody");

        // ❌ FIX 2 — rename var
        final encryptedResponse = responseBody['data'];
        print("👉 Encrypted token response: $encryptedResponse");

        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        print("Decrypted token response: $decrypted\n");

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
          print('❌ Invalid token received: $tokenRaw');

          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Invalid login token received',
          );

          return false;
        }

        final String token = tokenRaw;
        print('✅ JWT Token: $token');

        final prefs = await SharedPreferences.getInstance();
        print('🧠 SharedPreferences instance obtained');

        print('🔐 Saving auth_token...');
        await prefs.setString('auth_token', token);
        print('✅ auth_token saved');

        // ================== USER INFO ==================
        print('📡 Fetching userInfo()...');
        final userdata = await userInfo();
        print('📥 Raw userdata response: $userdata');

        final userProfileData = userdata['data'];
        print('👤 userProfileData: $userProfileData');
        print('👤 userProfileData runtimeType: ${userProfileData.runtimeType}');

        final gender = userdata['data']?['Gender'];
        print('🚻 Gender from API: $gender (type: ${gender.runtimeType})');

        if (gender != null) {
          await prefs.setString('user_gender', gender.toString());
          print('✅ user_gender saved: $gender');
        } else {
          await prefs.setString('user_gender', '');
          print('⚠️ user_gender was NULL — saved empty string');
        }

        print('🗂 Saving userProfileData into localstorage.userMap...');
        localStorage.userMap.value = userProfileData;
        print('✅ localstorage.userMap updated');

        if (userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
          print('💾 userdata saved to SharedPreferences');
        } else {
          print('❌ userProfileData is NOT a Map — skipped saving userdata');
        }

        // ================== USER GOAL DATA ==================
        print('📡 Fetching useeractivedataInfo()...');
        final goaldata = await useeractivedataInfo();
        print('📥 Raw goaldata response: $goaldata');

        final data = goaldata['data'];
        print('🎯 user goal data: $data');
        print('🎯 user goal data runtimeType: ${data.runtimeType}');

        localStorage.userGoalDataMap.value = data;

        if (data is Map) {
          final userGoalJson = jsonEncode(data);
          await prefs.setString('userGoaldata', userGoalJson);
          print('💾 userGoaldata saved to SharedPreferences');
        } else {
          print('⚠️ userGoaldata is NOT a Map — nothing saved');
        }

        print('🏁 Sign-in data pipeline COMPLETED');

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
      print("sign in screen email $e  $st");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Sign In failed.',
      );
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
    // print("$response");
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
    // print("$response");
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
  //   // print("$response");
  //   return response;
  // }

  Future<bool> signInUsingPhone(
    String phone,
    String password,
    BuildContext context,
    String? extraHeaders,
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

      headers['X-Data-Hash'] = encryptedPhone['hash']!;

      if (extraHeaders != null) {
  headers['X-Device-Info'] = extraHeaders;
}

      final encryptedRequestBody = jsonEncode({
        'data': encryptedPhone['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedRequestBody,
      );

      print(response.body);
      print(response.statusCode);

      // ❌ FIX #1 — real condition
      // ❌ FIX 1 — real condition
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("response Body: $responseBody");

        // ❌ FIX 2 — rename var
        final encryptedResponse = responseBody['data'];
        print("👉 Encrypted token response: $encryptedResponse");

        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );

        print("Decrypted token response: $decrypted\n");

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
          print('❌ Invalid token received: $tokenRaw');

          CustomSnackbar.showError(
            context: context,
            title: 'Error',
            message: 'Invalid login token received',
          );

          return false;
        }

        final String token = tokenRaw;
        print('✅ JWT Token: $token');

        final prefs = await SharedPreferences.getInstance();
        print('🧠 SharedPreferences instance obtained');

        print('🔐 Saving auth_token...');
        await prefs.setString('auth_token', token);
        print('✅ auth_token saved');

        // ================== USER INFO ==================
        print('📡 Fetching userInfo()...');
        final userdata = await userInfo();
        print('📥 Raw userdata response: $userdata');

        final userProfileData = userdata['data'];
        print('👤 userProfileData: $userProfileData');
        print('👤 userProfileData runtimeType: ${userProfileData.runtimeType}');

        final gender = userdata['data']?['Gender'];
        print('🚻 Gender from API: $gender (type: ${gender.runtimeType})');

        if (gender != null) {
          await prefs.setString('user_gender', gender.toString());
          print('✅ user_gender saved: $gender');
        } else {
          await prefs.setString('user_gender', '');
          print('⚠️ user_gender was NULL — saved empty string');
        }

        print('🗂 Saving userProfileData into localstorage.userMap...');
        localStorage.userMap.value = userProfileData;
        print('✅ localstorage.userMap updated');

        if (userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
          print('💾 userdata saved to SharedPreferences');
        } else {
          print('❌ userProfileData is NOT a Map — skipped saving userdata');
        }

        // ================== USER GOAL DATA ==================
        print('📡 Fetching useeractivedataInfo()...');
        final goaldata = await useeractivedataInfo();
        print('📥 Raw goaldata response: $goaldata');

        final data = goaldata['data'];
        print('🎯 user goal data: $data');
        print('🎯 user goal data runtimeType: ${data.runtimeType}');

        localStorage.userGoalDataMap.value = data;

        if (data is Map) {
          final userGoalJson = jsonEncode(data);
          await prefs.setString('userGoaldata', userGoalJson);
          print('💾 userGoaldata saved to SharedPreferences');
        } else {
          print('⚠️ userGoaldata is NOT a Map — nothing saved');
        }

        print('🏁 Sign-in data pipeline COMPLETED');

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        return true;
      } else {
        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Sign In failed.',
        );
        return false;
      }
    } catch (e, st) {
      print("sign in phone $e $st");
      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Sign In failed.',
      );
      return false;
    }
  }
}
