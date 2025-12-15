import 'package:snevva/views/Vitals/heart_rate.dart';
import 'package:flutter/material.dart';
import 'package:snevva/consts/colors.dart';

import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';

class AddWatch extends StatefulWidget {
  const AddWatch({super.key});

  @override
  State<AddWatch> createState() => _AddWatchState();
}

class _AddWatchState extends State<AddWatch> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    //final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Heart Rate"),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(height: 20),
              Text(
                "Scan QR code from your\nwatch to connect",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              Container(
                height: 298,
                width: 298,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    Icons.qr_code_scanner,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              ),
              SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HeartRate()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text("Scan", style: TextStyle(fontSize: 16)),
                ),
              ),
              Spacer(), // Pushes footer to bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Add Later", style: TextStyle(fontSize: 16)),
                    Row(
                      children: [
                        Text(
                          "Not able to find! ",
                          style: TextStyle(fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Handle "Need Help?" tap here
                          },
                          child: Text(
                            "Need Help?",
                            style: TextStyle(
                              color: Colors.purpleAccent,
                              fontWeight: FontWeight.w500,
                              // decoration: TextDecoration.underline,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
