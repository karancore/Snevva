import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/localStorageManager.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
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

  void _showSnackbar(String title, String message) {
    try {
      // Use WidgetsBinding to schedule the snackbar after frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.overlayContext != null) {
          Get.snackbar(
            title,
            message,
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
        } else {
          // Fallback: print to console if overlay not available
          print('$title: $message');
        }
      });
    } catch (e) {
      print('$title: $message');
    }
  }

  Future<bool> signInUsingEmail(String email, String password) async {
    if (email.isEmpty) {
      // Get.snackbar(
      //   'Error',
      //   'Email cannot be empty',
      //   snackPosition: SnackPosition.BOTTOM,
      //   margin: EdgeInsets.all(20),
      // );
      _showSnackbar("Error", "Email cannot be empty");
      return false;
    }

    final plainEmail = jsonEncode({'Gmail': email, 'Password': password});

    try {
      final uri = Uri.parse("$baseUrl$signInEmailEndpoint");
      final encryptedEmail = EncryptionService.encryptData(plainEmail);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedEmail['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedEmail['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );
      print(response.statusCode);

      if (response.statusCode == 200 ) {
        final responseBody = jsonDecode(response.body);
        // print("response Body: $responseBody");

        final encryptedBody = responseBody['data'];
        // print("👉 Encrypted token response: $encryptedBody");

        final responseHash = response.headers['x-data-hash'];
        // print("👉 Response hash: $responseHash");

        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

        print("Decrypted token response: $decrypted");
        print('');

        if (decrypted == null) {
          Get.snackbar(
            'Error',
            'Failed to decrypt response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        final token = responseData['data'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        final userdata = await userInfo();
        final userProfileData = userdata['data'];
        final gender = userdata['data']['Gender'];
        await prefs.setString('user_gender', gender);
        print("$userProfileData");
        localstorage.userMap.value = userProfileData;

        if (userProfileData != null && userProfileData is Map) {
          // Convert the Map to a JSON string
          final userJson = jsonEncode(userProfileData);
          // Store it in SharedPreferences
          await prefs.setString('userdata', userJson);
          print("User data saved to SharedPreferences.");
        }
        //  else {
        //   print("User profile data is null or invalid.");
        // }

        final goaldata = await useeractivedataInfo();
        final data = goaldata['data'];
        // print("Data");

        if (data != null && data is Map) {
          // Convert the Map to a JSON string
          final userGoalJson = jsonEncode(data);
          // Store it in SharedPreferences
          await prefs.setString('userGoaldata', userGoalJson);
          print("User data saved to SharedPreferences.");
        }
        // else {
        //   print("User profile data is null or invalid.");
        // }

        // final useractivebasicdata = await useeractivedataInfo();
        // final basicinfo = useractivebasicdata['data'];
        // print("bsicinfo $basicinfo");
        //
        // if (basicinfo != null && basicinfo is Map) {
        //
        //   // Convert the Map to a JSON string
        //   final userJson = jsonEncode(basicinfo);
        //
        //   // Store it in SharedPreferences
        //   await prefs.setString('useractivedata', userJson);
        //   print("User active data saved to SharedPreferences.");
        // } else {
        //   print("User active data is null or invalid.");
        // }

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        // Get.snackbar(
        //   'Success',
        //   'Sign In Successful.',
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.all(20),
        // );

        return true;
      }
      else if(response.statusCode == 400){
        Get.snackbar(
          'Error',
          'Wrong Credentials',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
      else {
        Get.snackbar(
          'Error',
          'Sign In failed.',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sign In failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
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

  Future<bool> signInUsingPhone(String phone, String password) async {
    if (phone.isEmpty) {
      Get.snackbar(
        'Error',
        'Phone cannot be empty',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
    final plainPhone = jsonEncode({
      'PhoneNumber': phone,
      'Password': password,
    });

    try {
      final uri = Uri.parse("$baseUrl$signInPhoneEndpoint");
      final encryptedPhone = EncryptionService.encryptData(plainPhone);
      final headers = await AuthHeaderHelper.getHeaders(withAuth: false);

      headers['X-Data-Hash'] = encryptedPhone['hash']!;

      final encryptedBody = jsonEncode({
        'data': encryptedPhone['encryptedData'],
      });

      final response = await http.post(
        uri,
        headers: headers,
        body: encryptedBody,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final encryptedBody = responseBody['data'];
        final responseHash = response.headers['x-data-hash'];
        final decrypted = EncryptionService.decryptData(
          encryptedBody,
          responseHash!,
        );

         if (decrypted == null) {
          Get.snackbar(
            'Error',
            'Failed to decrypt response',
            snackPosition: SnackPosition.BOTTOM,
            margin: EdgeInsets.all(20),
          );
          return false;
        }

        final Map<String, dynamic> responseData = jsonDecode(decrypted);
        final token = responseData['data'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);

        final userdata = await userInfo();
        final userProfileData = userdata['data'];
        final gender = userdata['data']['Gender'];
        await prefs.setString('user_gender', gender);
        print("$userProfileData");
        localstorage.userMap.value = userProfileData;

        if (userProfileData != null && userProfileData is Map) {
          // Convert the Map to a JSON string
          final userJson = jsonEncode(userProfileData);
          // Store it in SharedPreferences
          await prefs.setString('userdata', userJson);
          print("User data saved to SharedPreferences.");
        }
        //  else {
        //   print("User profile data is null or invalid.");
        // }

        final goaldata = await useeractivedataInfo();
        final data = goaldata['data'];
        // print("Data");

        if (data != null && data is Map) {
          // Convert the Map to a JSON string
          final userGoalJson = jsonEncode(data);
          // Store it in SharedPreferences
          await prefs.setString('userGoaldata', userGoalJson);
          print("User data saved to SharedPreferences.");
        }
        // else {
        //   print("User profile data is null or invalid.");
        // }

        // final useractivebasicdata = await useeractivedataInfo();
        // final basicinfo = useractivebasicdata['data'];
        // print("bsicinfo $basicinfo");
        //
        // if (basicinfo != null && basicinfo is Map) {
        //
        //   // Convert the Map to a JSON string
        //   final userJson = jsonEncode(basicinfo);
        //
        //   // Store it in SharedPreferences
        //   await prefs.setString('useractivedata', userJson);
        //   print("User active data saved to SharedPreferences.");
        // } else {
        //   print("User active data is null or invalid.");
        // }

        userEmailOrPhoneField.clear();
        userPasswordField.clear();

        // Get.snackbar(
        //   'Success',
        //   'Sign In Successful.',
        //   snackPosition: SnackPosition.BOTTOM,
        //   margin: EdgeInsets.all(20),
        // );

        return true;
      } else {
        Get.snackbar(
          'Error',
          'Sign In failed.',
          snackPosition: SnackPosition.BOTTOM,
          margin: EdgeInsets.all(20),
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Sign In failed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: EdgeInsets.all(20),
      );
      return false;
    }
  }
}
