import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/scan_report_history.dart';

class ScanReportController extends GetxController {
  late CameraController cameraController;
  var isCameraInitialized = false.obs;
  var isFlashOn = false.obs;
  var pickedImage = Rx<File?>(null);
  var reportHistory = <ScanReportHistory>[].obs;

  final ImagePicker _imgPicker = ImagePicker();
  List<CameraDescription> cameras = [];
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
    initCamera();
    loadHistory();
  }

  Future<void> initCamera() async {
    try {
      cameras = await availableCameras();
      cameraController = CameraController(
        cameras[0],
        ResolutionPreset.ultraHigh,
      );
      await cameraController.initialize();
      isCameraInitialized.value = true;
    } catch (e) {
      log("Camera init error: $e");
    }
  }

  Future<void> toggleFlash() async {
    if (!isCameraInitialized.value) return;
    try {
      if (isFlashOn.value) {
        await cameraController.setFlashMode(FlashMode.off);
        isFlashOn.value = false;
      } else {
        await cameraController.setFlashMode(FlashMode.torch);
        isFlashOn.value = true;
      }
    } catch (e) {
      log("Flash toggle error: $e");
    }
  }

  Future<void> takePicture() async {
    if (!isCameraInitialized.value) {
      log("Camera not initialized");
      return;
    }
    try {
      final XFile picture = await cameraController.takePicture();
      pickedImage.value = File(picture.path);
      log("Picture saved to ${picture.path}");
    } catch (e) {
      log("Error taking picture: $e");
    }
  }

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
    cameraController.dispose();
    super.onClose();
  }

  String encodeToBase64(File file) {
    final bytes = file.readAsBytesSync();
    return base64Encode(bytes);
  }

  Future<String> uploadReport(File file) async {
    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      throw Exception('File size exceeds 5 MB limit');
    }

    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !_allowedMimeTypes.contains(mimeType)) {
      throw Exception('Unsupported file type: $mimeType');
    }

    final base64file = encodeToBase64(file);

    final payload = {
      "patientCode": localstoragecontroler.userMap["PatientCode"],
      "fileBase64": base64file,
      "fileName": file.path.split('/').last,
      "mimeType": mimeType,
    };

    // final response = await ApiService.post(
    //   scanreportapi,
    //   payload,
    //   withAuth: true,
    //   encryptionRequired: true,
    // );
    // final parsedData = jsonDecode(jsonEncode(response));
    // final content = parsedData['content'];

    const result = "A response of API hit.";
    return result;
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
