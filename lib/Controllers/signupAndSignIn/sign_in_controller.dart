import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/services/api_service.dart';
import 'package:snevva/views/Dashboard/dashboard.dart';
import 'package:snevva/views/ProfileAndQuestionnaire/profile_setup_initial.dart';
import 'package:snevva/views/Sign%20Up/sign_in_screen.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../services/auth_header_helper.dart';
import '../../services/encryption_service.dart';

class SignInController extends GetxController {
  dynamic userProfData = {};
  dynamic userGoalData = {};

  final localstorage = Get.put(LocalStorageManager());


  Future<bool> signInUsingEmail(String email, String password , BuildContext context) async {
    if (email.isEmpty) {
      CustomSnackbar.showError(context: context , title: "Error", message:  "Email cannot be empty");
      return false;
    }

    final plainEmail = jsonEncode({'Gmail': email, 'Password': password});

    try {
      final uri = Uri.parse("$baseUrl$signInEmailEndpoint");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);

      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);
      headers['X-Data-Hash'] = encryptedEmail['hash']!;

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
          CustomSnackbar.showError(context: context , title: 'Error', message: 'Failed to decrypt response');
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        // ❌ FIX 3 — check server status
        // if (responseData['status'] != true) {
        //   CustomSnackbar.showError(context: context , title: "Error", message:  "Wrong credentials");
        //   return false;
        // }

        // token
        final token = responseData['data'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        // fetch user data
        final userdata = await userInfo();
        final userProfileData = userdata['data'];
        final gender = userdata['data']['Gender'];

        await prefs.setString('user_gender', gender);
        localstorage.userMap.value = userProfileData;

        if (userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
        }

        final goaldata = await useeractivedataInfo();
        final data = goaldata['data'];

        if (data is Map) {
          final userGoalJson = jsonEncode(data);
          await prefs.setString('userGoaldata', userGoalJson);
        }

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        return true;
      }

      // Wrong input
      else if (response.statusCode == 400) {
        CustomSnackbar.showError(context: context , title: 'Error', message: 'Wrong Credentials');
        return false;
      }

      // Other failures
      else {
        CustomSnackbar.showError(context: context , title: 'Error', message: 'Sign In failed.');
        return false;
      }
    } catch (e) {
      print(e);
      CustomSnackbar.showError(context: context , title: 'Error', message: 'Sign In failed.');
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

  Future<bool> signInUsingPhone(String phone, String password , BuildContext context) async {
    if (phone.isEmpty) {
      CustomSnackbar.showError(context: context , title: 'Error', message: 'Phone cannot be empty');
      return false;
    }

    final plainPhone = jsonEncode({'PhoneNumber': phone, 'Password': password});

    try {
      final uri = Uri.parse("$baseUrl$signInPhoneEndpoint");
      final encryptedPhone = EncryptionService.encryptData(plainPhone);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPhone['hash']!;

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
      if (response.statusCode == 200) {
        final decodedBody = jsonDecode(response.body);
        print(decodedBody);

        // ❌ FIX #2 — variable rename
        final encryptedResponse = decodedBody['data'];
        final responseHash = response.headers['x-data-hash'];

        final decrypted = EncryptionService.decryptData(
          encryptedResponse,
          responseHash!,
        );
        print(decrypted);

        if (decrypted == null) {
          CustomSnackbar.showError(context: context , title: 'Error', message: 'Failed to decrypt response');
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);

        // ❌ FIX #3 — check login success
        // if (responseData['status'] != true) {
        //   CustomSnackbar.showError(context: context , title: 'Error', message: 'Sign-in failed');
        //   return false;
        // }

        final token = responseData['data'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        // Load user data
        final userdata = await userInfo();
        final userProfileData = userdata['data'];

        if (userProfileData != null && userProfileData is Map) {
          final userJson = jsonEncode(userProfileData);
          await prefs.setString('userdata', userJson);
        }

        return true;
      } else {
        CustomSnackbar.showError(context: context , title: 'Error', message: 'Sign In failed.');
        return false;
      }
    } catch (e) {
      print(e);
      CustomSnackbar.showError(context: context , title: 'Error', message: 'Sign In failed.');
      return false;
    }
  }

}
