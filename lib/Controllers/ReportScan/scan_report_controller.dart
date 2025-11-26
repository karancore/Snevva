import 'dart:developer';
import 'dart:io';

import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class ScanReportController extends GetxController {
  late CameraController cameraController;
  var isCameraInitialized = false.obs;

  var isFlashOn = false.obs;

  var pickedImage = Rx<File?>(null);
  final ImagePicker _imgPicker = ImagePicker();

  List<CameraDescription> cameras = [];

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
        await cameraController.setFlashMode(FlashMode.torch); // or .always for photo
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
    final XFile? image = await _imgPicker.pickImage(source: ImageSource.gallery);
    if(image != null){
      pickedImage.value = File(image.path);
    }
  }

  @override
  void onClose() {
    cameraController.dispose();
    super.onClose();
  }
}
