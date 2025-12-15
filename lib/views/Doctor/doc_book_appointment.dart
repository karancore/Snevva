import 'package:flutter/material.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/consts/images.dart';

class DocBookAppointment extends StatefulWidget {
  const DocBookAppointment({super.key});

  @override
  State<DocBookAppointment> createState() => _DocBookAppointmentState();
}

class _DocBookAppointmentState extends State<DocBookAppointment> {
  int selectedDateIndex = 0;
  int selectedTimeIndex = -1;

  final List<String> dates = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> times = [
    '12-01 PM',
    '01-02 PM',
    '02-03 PM',
    '03-04 PM',
    '04-05 PM',
    '05-06 PM',
  ];

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Book Appointment"),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CustomOutlinedButton(
          width: width,
          isDarkMode: isDarkMode,
          backgroundColor: AppColors.primaryColor,
          buttonName: "Book Appointment (₹500)",
          onTap: () {
            showGeneralDialog(
              context: context,
              barrierLabel: "Appointment Scheduled",
              barrierDismissible: true,
              barrierColor: Colors.black.withOpacity(0.5),
              transitionDuration: const Duration(milliseconds: 400),
              pageBuilder: (context, animation, secondaryAnimation) {
                return const SizedBox(); // Required but unused
              },
              transitionBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1), // Start from bottom
                    end: Offset.zero, // End at center
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  child: Dialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      width: MediaQuery.of(context).size.width * 0.8,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(tick), // Your tick image asset
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Appointment Scheduled",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Your appointment scheduled for",
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "28-sep-2025 01:30PM",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Container(
                          //   decoration: BoxDecoration(gradient: buttonSign),
                          //   child: ElevatedButton(
                          //     onPressed: () {
                          //       Navigator.of(context).pop(); // Close dialog
                          //       // Navigate to home if needed
                          //       // Navigator.pushReplacement(...);

                          //     },
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: Colors.transparent,
                          //       foregroundColor: Colors.white,
                          //       shadowColor: Colors.transparent,
                          //       shape: RoundedRectangleBorder(
                          //         borderRadius: BorderRadius.circular(10),
                          //       ),
                          //       minimumSize: const Size.fromHeight(40),
                          //     ),
                          //     child: const Text("Go to home"),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Doctor Info Section
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    doc1,
                    height: 70,
                    width: 70,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dr. Jerry Jones",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Neuromedicine",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        Text(
                          "4.5 (4435)",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Tags
            Row(
              children: [
                _buildBadge("Neurologist", Colors.green.shade100, Colors.green),
                const SizedBox(width: 8),
                _buildBadge(
                  "Neuromedicine",
                  Colors.orange.shade100,
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildBadge("Dermatologist", Colors.blue.shade100, Colors.blue),
              ],
            ),
            const SizedBox(height: 24),

            /// About Me
            Text(
              "About Me",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa...",
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 24),

            /// Schedule
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Schedules",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text("Sept 2025", style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: dates.length,
                itemBuilder: (context, index) {
                  return _buildDateButton(index);
                },
              ),
            ),

            /// Choose Time
            const SizedBox(height: 24),
            Text(
              "Choose Time",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            /// Time Period Tabs
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTimeTab("Morning", false),
                  _buildTimeTab("Afternoon", true),
                  _buildTimeTab("Evening", false),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                // Light purple background
                borderRadius: BorderRadius.circular(16),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double totalSpacing = 12 * 2; // 2 gaps per row
                  double itemWidth = (constraints.maxWidth - totalSpacing) / 3;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(times.length, (index) {
                      final bool isSelected = selectedTimeIndex == index;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTimeIndex = index;
                          });
                        },
                        child: Container(
                          width: itemWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient:
                                isSelected ? AppColors.primaryGradient : null,
                            color: isSelected ? null : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              if (!isSelected)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              times[index],
                              style: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }

  Widget _buildDateButton(int index) {
    final bool isSelected = selectedDateIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDateIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              (index + 1).toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              dates[index],
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeTab(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        color: isSelected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
