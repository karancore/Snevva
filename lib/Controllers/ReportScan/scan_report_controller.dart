import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart'; // ADD to pubspec: mime: ^1.0.4
import 'package:snevva/Controllers/local_storage_manager.dart';
import 'package:snevva/consts/consts.dart';

class ScanReportController extends GetxController {
  late CameraController cameraController;
  var isCameraInitialized = false.obs;
  var isFlashOn = false.obs;
  var pickedImage = Rx<File?>(null);

  final ImagePicker _imgPicker = ImagePicker();
  List<CameraDescription> cameras = [];
  final localstoragecontroler = Get.find<LocalStorageManager>();

  // Supported MIME types for upload
  static const _allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'application/pdf'
  ];
  static const _maxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

  @override
  void onInit() {
    super.onInit();
    initCamera();
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
        source: ImageSource.gallery);
    if (image != null) {
      pickedImage.value = File(image.path);
    }
  }

  @override
  void onClose() {
    cameraController.dispose();
    super.onClose();
  }

  // FIX 1: Correct return type syntax + implemented base64 encoding
  String encodeToBase64(File file) {
    final bytes = file.readAsBytesSync();
    return base64Encode(bytes);
  }

  // FIX 2: Parameter changed from String → File to match actual usage
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
      "fileName": file.path
          .split('/')
          .last,
      "mimeType": mimeType,
    };

    // final response = await ApiService.post(
    //   scanreportapi,
    //   payload,
    //   withAuth: true,
    //   encryptionRequired: true,
    // );
    //
    // // if (response is http.Response && response.statusCode != 200) {
    // //   throw Exception('API Error: ${response.statusCode}');
    // // }
    //
    // final parsedData = jsonDecode(jsonEncode(response));
    // debugPrint("Parsed data: $parsedData");
    //
    // // ← content key ki value return karo
    // final content = parsedData['content'];
    // // if (content == null || content.toString().isEmpty) {
    // //   throw Exception('No content received from server');
    // // }

    return "A response of API hit.";
  }
}
