import 'package:camera/camera.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:snevva/Controllers/ReportScan/scan_report_controller.dart';
import 'package:snevva/Widgets/home_wrapper.dart';
import '../../consts/consts.dart';

class ScanReportScreen extends StatefulWidget {
  const ScanReportScreen({super.key});

  @override
  State<ScanReportScreen> createState() => _ScanReportScreenState();
}

class _ScanReportScreenState extends State<ScanReportScreen> {
  late final ScanReportController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ScanReportController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Obx(() {
            if (!controller.isCameraInitialized.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return SizedBox.expand(
              child: CameraPreview(controller.cameraController),
            );
          }),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Text(
                    'Camera',
                    style: TextStyle(
                      color: white,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  Align(
                    alignment: Alignment.topRight,
                    child: InkWell(
                      onTap: () {
                        Get.delete<ScanReportController>();
                        Get.off(HomeWrapper());
                      },
                      child: SvgPicture.asset(appbarActionCrossWhite),
                    ),
                  ),

                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        InkWell(
                          onTap: controller.toggleFlash,
                          child: Obx(
                            () => Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    controller.isFlashOn.value
                                        ? AppColors.primaryColor.withValues(
                                          alpha: 0.8,
                                        )
                                        : white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Icon(
                                FontAwesomeIcons.lightbulb,
                                color:
                                    controller.isFlashOn.value
                                        ? white
                                        : mediumGrey,
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => controller.takePicture(),
                          child: SvgPicture.asset(cameraCaptureIcon),
                        ),
                        InkWell(
                          onTap: controller.pickImageFromGallery,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              FontAwesomeIcons.image,
                              color: mediumGrey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
