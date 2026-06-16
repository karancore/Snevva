import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/images.dart';

import '../../Controllers/Vitals/vitalsController.dart';
import '../../features/health_sdk/controllers/health_sdk_controller.dart';

class HeartRate extends StatefulWidget {
  const HeartRate({super.key});

  @override
  State<HeartRate> createState() => _HeartRateState();
}

class _HeartRateState extends State<HeartRate> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    //// ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Heart Rate"),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Heart Image Placeholder
            Center(
              child: Image.asset(
                heart2, // replace with your asset path for heart image
                width: 200,
                height: 200,
              ),
            ),
            SizedBox(height: 20),

            // BPM Value
            Obx(() {
              final sdkController = Get.find<HealthSdkController>();
              final latestHeartRate = sdkController.latestHeartRate.value;
              final val = latestHeartRate != null ? latestHeartRate
                  .beatsPerMinute.toInt() : Get
                  .find<VitalsController>()
                  .bpm
                  .value;
              return Text(
                val > 0 ? "$val" : "--",
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold),
              );
            }),
            Obx(() {
              final sdkController = Get.find<HealthSdkController>();
              final latestHeartRate = sdkController.latestHeartRate.value;
              if (latestHeartRate != null &&
                  latestHeartRate.sourceName != null) {
                return Text(
                  "BPM (${latestHeartRate.sourceName})",
                  style: const TextStyle(fontSize: 16),
                );
              }
              return const Text("BPM", style: TextStyle(fontSize: 16));
            }),
            const SizedBox(height: 16),

            // Info Text
            const Text(
              "This result is not used as a\nmedical basis",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),

            // % Result pill / Status label
            Obx(() {
              final sdkController = Get.find<HealthSdkController>();
              final latestHeartRate = sdkController.latestHeartRate.value;
              final val = latestHeartRate != null ? latestHeartRate
                  .beatsPerMinute.toInt() : Get
                  .find<VitalsController>()
                  .bpm
                  .value;

              String status = "Unknown";
              Color pillBg = Colors.grey.shade100;
              Color pillText = Colors.grey;

              if (val > 0) {
                if (latestHeartRate != null) {
                  status = latestHeartRate.status;
                  pillText = latestHeartRate.statusColor;
                  pillBg = latestHeartRate.statusColor.withOpacity(0.15);
                } else {
                  status = Get.find<VitalsController>().getBpmStatus(val);
                  pillText = Colors.redAccent;
                  pillBg = Colors.red.shade100;
                }
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: pillText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
