import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:snevva/Widgets/Appointment/appointment_widget.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';
import '../../Controllers/appointment_controller.dart';

class DocHaveAppointment extends StatelessWidget {
  DocHaveAppointment({super.key});

  final AppointmentController controller = Get.put(AppointmentController());
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    // final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Appointments"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(
              () => Row(
                children: [
                  GestureDetector(
                    onTap: () => controller.changeTab(0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient:
                            controller.selectedTab.value == 0
                                ? AppColors.primaryGradient
                                : null,
                        color:
                            controller.selectedTab.value == 0
                                ? null
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Upcoming Schedule',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color:
                              controller.selectedTab.value == 0
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => controller.changeTab(1),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient:
                            controller.selectedTab.value == 1
                                ? AppColors.primaryGradient
                                : null,
                        color:
                            controller.selectedTab.value == 1
                                ? null
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Schedule History',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color:
                              controller.selectedTab.value == 1
                                  ? Colors.white
                                  : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Obx(() {
              final isHistory = controller.selectedTab.value == 1;
              final appointments = controller.currentAppointments;

              if (appointments.isEmpty) {
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 175),
                      Center(
                        child: Image.asset(hielly, width: 130, height: 130),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: [
                          const Text(
                            '"No appointments scheduled at the moment.\n Please schedule appointment "',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // You can navigate to the scheduling screen here
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            DocHaveAppointment(), // or another screen
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 60,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("Schedule Appointment"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children:
                    appointments.map((appointment) {
                      return Column(
                        children: [
                          AppointmentCard(
                            doctorName: appointment['doctorName'] ?? '',
                            specialty: appointment['specialty'] ?? '',
                            imagePath: appointment['image'] ?? avatar1,
                            date: appointment['date'] ?? '',
                            time: appointment['time'] ?? '',
                            isHistory: isHistory,
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }
}
