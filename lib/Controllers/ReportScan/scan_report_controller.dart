import 'dart:convert';
import 'dart:developer';
import 'dart:io';

// import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/scan_report_history.dart';

import '../../Services/api_service.dart';
import '../../env/env.dart';

class ScanReportController extends GetxController {
  // late CameraController cameraController;
  // var isCameraInitialized = false.obs;
  // var isFlashOn = false.obs;
  var pickedImage = Rx<File?>(null);
  var reportHistory = <ScanReportHistory>[].obs;

  final ImagePicker _imgPicker = ImagePicker();

  // List<CameraDescription> cameras = [];
  final localstoragecontroler = Get.find<LocalStorageManager>();

  static const _allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'application/pdf',
  ];
  static const _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB
  static const _historyPrefKey = 'scan_report_history';

  @override
  void onInit() {
    super.onInit();
    // initCamera();
    loadHistory();
  }

  // Future<void> initCamera() async {
  //   try {
  //     cameras = await availableCameras();
  //     cameraController = CameraController(
  //       cameras[0],
  //       ResolutionPreset.ultraHigh,
  //     );
  //     await cameraController.initialize();
  //     isCameraInitialized.value = true;
  //   } catch (e) {
  //     log("Camera init error: $e");
  //   }
  // }
  //
  // Future<void> toggleFlash() async {
  //   if (!isCameraInitialized.value) return;
  //   try {
  //     if (isFlashOn.value) {
  //       await cameraController.setFlashMode(FlashMode.off);
  //       isFlashOn.value = false;
  //     } else {
  //       await cameraController.setFlashMode(FlashMode.torch);
  //       isFlashOn.value = true;
  //     }
  //   } catch (e) {
  //     log("Flash toggle error: $e");
  //   }
  // }
  //
  // Future<void> takePicture() async {
  //   if (!isCameraInitialized.value) {
  //     log("Camera not initialized");
  //     return;
  //   }
  //   try {
  //     final XFile picture = await cameraController.takePicture();
  //     pickedImage.value = File(picture.path);
  //     log("Picture saved to ${picture.path}");
  //   } catch (e) {
  //     log("Error taking picture: $e");
  //   }
  // }

  Future<void> pickImageFromGallery() async {
    final XFile? image = await _imgPicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      pickedImage.value = File(image.path);
    }
  }

  @override
  void onClose() {
    // cameraController.dispose();
    super.onClose();
  }

  String encodeToBase64(File file) {
    final bytes = file.readAsBytesSync();
    return base64Encode(bytes);
  }


  int calculateAge({
    required int day,
    required int month,
    required int year,
  }) {
    final today = DateTime.now();

    int age = today.year - year;

    if (today.month < month ||
        (today.month == month &&
            today.day < day)) {
      age--;
    }

    return age;
  }

  Future<bool> sendReportToServer(
      {required String ? pdfPath, required bool isOwnPdf, required String ? selectedGender, required TextEditingController ageController}) async {
    if (pdfPath == null) return false;

    try {
      final file = File(pdfPath!);

      // Convert PDF to base64
      final bytes = await file.readAsBytes();
      final base64File = base64Encode(bytes);

      final fileName = pdfPath!.split('/').last;

      final mimeType =
          lookupMimeType(pdfPath!) ?? 'application/pdf';

      String patientCode = await Get
          .find<LocalStorageManager>()
          .userGoalDataMap['PatientCode'];
      String cachedGender = await Get
          .find<LocalStorageManager>()
          .userMap['Gender'];
      final userInfo =
          Get
              .find<LocalStorageManager>()
              .userMap;

      final int day =
      userInfo['DayOfBirth'];

      final int month =
      userInfo['MonthOfBirth'];

      final int year =
      userInfo['YearOfBirth'];

      final int cachedAge = calculateAge(
        day: day,
        month: month,
        year: year,
      );

      debugPrint("Cached age is $cachedAge");


      // Payload
      final Map<String, dynamic> payload = {
        "patientCode": patientCode,

        "fileBase64": base64File,

        "fileName": fileName,

        "mimeType": mimeType,

        "isYourReport": isOwnPdf,

        // Required only when report is NOT user's
        "ageRange":
        !isOwnPdf
            ? ageController.text.trim()
            : cachedAge,

        "gender":
        !isOwnPdf
            ? selectedGender
            : cachedGender,
      };

      debugPrint("Payload: $payload");

      final response = await ApiService.post(
        scanreportapi,
        payload,
        withAuth: true,
        encryptionRequired: true,
      );

      debugPrint("Response: $response");
      return true;
    } catch (e, st) {
      debugPrint("Upload Error: $e");
      debugPrint("StackTrace: $st");

      return true;
    }
  }


  Future<void> addToHistory({
    required String title,
    required String content,
  }) async {
    final entry = ScanReportHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dateTime: DateTime.now(),
      content: content,
    );
    reportHistory.insert(0, entry);
    await _saveHistory();
  }

  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_historyPrefKey) ?? [];
      reportHistory.value =
          raw
              .map((e) => ScanReportHistory.fromJson(jsonDecode(e)))
              .toList();
    } catch (e) {
      log("Load history error: $e");
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = reportHistory.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_historyPrefKey, raw);
    } catch (e) {
      log("Save history error: $e");
    }
  }

  Future<void> downloadReport(ScanReportHistory report) async {
    await Share.share(
      '${report.title}\n\n${report.content}',
      subject: report.title,
    );
  }
}
