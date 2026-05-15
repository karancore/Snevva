// import 'dart:convert';
// import 'dart:math';
//
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:get/get_connect/http/src/response/response.dart'
// as http;
// import 'package:snevva/common/global_variables.dart';
//
// import '../../Services/api_service.dart';
// import '../../common/custom_snackbar.dart';
// import '../../consts/consts.dart';
// import '../../env/env.dart';
// import '../../models/common_tips_response.dart';
//
// class CommonTipsController extends GetxController {
//
//
//   RxList<CommonTip> commonTips = <CommonTip>[].obs;
//
//   RxBool isLoading = false.obs;
//   static const int _pageSize = 4;
//
//   Future<List<CommonTip>> getCommonTips({
//     required BuildContext context,
//     required String tag,
//   }) async {
//     try {
//       debugPrint("🟡 getCommonTips START");
//       debugPrint("🏷 Tag: $tag");
//
//       Map<String, dynamic> payload = {
//         'Tags': <String>[tag],
//         'FetchAll': false,
//         'Count': int.parse(_pageSize.toString()),
//         'Index': 1,
//       };
//
//       debugPrint("📤 Payload: $payload");
//
//       final response = await ApiService.post(
//         genhealthtipsAPI,
//         payload,
//         withAuth: true,
//         encryptionRequired: true,
//       );
//
//       debugPrint("📥 Raw Response: $response");
//
//       if (response is http.Response) {
//         debugPrint("❌ HTTP Error Code: ${response.statusCode}");
//         debugPrint("❌ HTTP Error Body: ${response.body}");
//
//         CustomSnackbar.showError(
//           context: context,
//           title: 'Error',
//           message:
//           'Failed to load general tips: ${response.statusCode}',
//         );
//
//         commonTips.value = [];
//         update();
//         return [];
//       }
//
//       final parsedData = jsonDecode(jsonEncode(response));
//
//
//       debugPrint("✅ Parsed Data: $parsedData");
//       final model = CommonTipsResponse.fromJson(parsedData);
//
//       debugPrint("Model : $model");
//
//       commonTips.value = model.data ?? [];
//
//       logLong("General Tips" , commonTips.toString());
//
//
//       if (parsedData['status'] == true) {
//         commonTips = parsedData['data'] ?? [];
//
//         debugPrint("🎯 Tips Count: ${commonTips.length}");
//
//         for (var tip in commonTips) {
//           debugPrint("📝 Tip Item: $tip");
//         }
//       } else {
//         debugPrint("⚠ API returned false status");
//         commonTips.value = [];
//       }
//
//       update();
//
//       debugPrint("✅ getCommonTips END");
//       return [];
//     } catch (e, stackTrace) {
//       debugPrint("❌ Exception in getCommonTips: $e");
//       debugPrint("📛 StackTrace: $stackTrace");
//
//       commonTips.value = [];
//
//       CustomSnackbar.showError(
//         context: context,
//         title: 'Error',
//         message: 'Failed to load general tips',
//       );
//
//       update();
//     }
//   }
// }

import 'dart:convert';

import 'package:get/get_connect/http/src/response/response.dart' as http;

import '../../Services/api_service.dart';
import '../../common/custom_snackbar.dart';
import '../../consts/consts.dart';
import '../../env/env.dart';
import '../../models/common_tips_response.dart';

class CommonTipsController extends GetxController {
  RxList<CommonTip> commonTips = <CommonTip>[].obs;

  RxBool isLoading = false.obs;

  static const int _pageSize = 4;

  Future<List<CommonTip>> getCommonTips({
    required BuildContext context,
    required String tag,
    List<String>? tags,
  }) async {
    try {
      isLoading.value = true;

      debugPrint("🟡 getCommonTips START");
      debugPrint("🏷 Tag: $tag");

      Map<String, dynamic> payload = {
        'Tags': tags ?? <String>[tag],
        'FetchAll': false,
        'Count': int.parse(_pageSize.toString()),
        'Index': 1,
      };

      debugPrint("📤 Payload: $payload");

      final response = await ApiService.post(
        genhealthtipsAPI,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("📥 Raw Response: $response");

      /// HTTP ERROR
      if (response is http.Response) {
        debugPrint("❌ HTTP Error Code: ${response.statusCode}");
        debugPrint("❌ HTTP Error Body: ${response.body}");

        CustomSnackbar.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load general tips: ${response.statusCode}',
        );

        commonTips.clear();
        update();

        return [];
      }

      final parsedData = jsonDecode(jsonEncode(response));

      debugPrint("✅ Parsed Data: $parsedData");

      final model = CommonTipsResponse.fromJson(parsedData);

      /// SUCCESS
      if (model.status == true) {
        commonTips.value = model.data ?? [];

        debugPrint("🎯 Tips Count: ${commonTips.length}");

        for (var tip in commonTips) {
          debugPrint("📝 Tip Item: ${tip.title}");
        }
      } else {
        debugPrint("⚠ API returned false status");

        commonTips.clear();
      }

      update();

      debugPrint("✅ getCommonTips END");

      return commonTips;
    } catch (e, stackTrace) {
      debugPrint("❌ Exception in getCommonTips: $e");
      debugPrint("📛 StackTrace: $stackTrace");

      commonTips.clear();

      CustomSnackbar.showError(
        context: context,
        title: 'Error',
        message: 'Failed to load general tips',
      );

      update();

      return [];
    } finally {
      isLoading.value = false;
    }
  }
}
