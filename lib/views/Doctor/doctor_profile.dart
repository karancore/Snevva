import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/Drawer/drawer_menu_wigdet.dart';
import 'package:snevva/views/Doctor/doc_book_appointment.dart';

import '../../consts/consts.dart';

class DoctorProfile extends StatefulWidget {
  const DoctorProfile({super.key});

  @override
  State<DoctorProfile> createState() => _DoctorProfileState();
}

class _DoctorProfileState extends State<DoctorProfile> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: CustomAppBar(appbarText: "Doctor Profile", isWhiteRequired: true),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: CustomOutlinedButton(
          width: width,
          backgroundColor: AppColors.primaryColor,
          isDarkMode: isDarkMode,
          buttonName: "Schedule Appointment",
          onTap: () {
            Get.to(DocBookAppointment());
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  height: height * 0.28,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                ),
                SizedBox(height: height * 0.08),
                Column(
                  children: [
                    Text(
                      'Dr Jerry Jones',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(
                        "Specialization",
                        "Neuromedicine",
                        Icons.medical_services,
                      ),
                      _buildInfoItem("Location", "Delhi", Icons.location_on),
                      _buildInfoItem(
                        "Contact",
                        "jerry9898@gmail.com",
                        Icons.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
                _buildSection(
                  "About Me",
                  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean commodo ligula eget dolor. Aenean massa.",
                ),
                _buildSection(
                  "Education",
                  "MBBS, MD-Medicine, DM-Cardiology, DNB-Medicine, Fellow- American College of Cardiology, Fellow- Society for Cardiology Angiography and Interventions.",
                ),
                const SizedBox(height: 20),
              ],
            ),
            Positioned(
              top: height * 0.20,
              left: 0,
              right: 0,
              child: Center(
                child: CircleAvatar(
                  radius: height * 0.08,
                  backgroundImage: AssetImage(doc1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFF1E5FF),
          child: Icon(icon, color: Color(0xFFBE89FF)),
        ),
        const SizedBox(height: 5),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

Widget _buildSection(String title, String content) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(color: Colors.grey)),
      ],
    ),
  );
}
