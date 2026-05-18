import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../consts/consts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor =
        isDarkMode ? white.withValues(alpha: 0.9) : const Color(0xff878787);
    final Color headingColor = isDarkMode ? white : black;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: AutoSizeText('About'),
        iconTheme: IconThemeData(color: isDarkMode ? white : black, size: 20),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // About Section
            Text(
              "About Snevva",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: headingColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "SNEVVA is an AI-powered health companion offering symptom guidance, lab report insights, medicine reminders, period tracking, and expert consultations to support informed health decisions anytime, anywhere.",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),

            const SizedBox(height: 32),

            // Medical Disclaimer Section
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.triangleExclamation,
                  size: 16,
                  color:
                      isDarkMode ? Colors.amberAccent : const Color(0xffE6A817),
                ),
                const SizedBox(width: 8),
                Text(
                  "Medical Disclaimer",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: headingColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _disclaimerParagraph(
              "The health analysis, insights, and suggestions provided through this application are generated solely on the basis of the medical reports, data, and information uploaded or submitted by the user. The platform utilizes automated systems and/or AI-assisted technologies to provide general wellness guidance and preliminary health-related observations.",
              textColor,
            ),
            _disclaimerParagraph(
              "The information, analysis, recommendations, dietary suggestions, lifestyle guidance, or alerts provided by the application are intended strictly for informational and supportive purposes only and shall not be construed as medical advice, diagnosis, prescription, treatment recommendation, or clinical opinion.",
              textColor,
            ),
            _disclaimerParagraph(
              "Users are advised that the suggestions provided by the platform are indicative in nature and should not be solely relied upon for making medical decisions. Any medication changes, treatment modifications, diagnostic interpretations, or healthcare-related actions should only be undertaken after consultation with a qualified and licensed medical practitioner.",
              textColor,
            ),
            _disclaimerParagraph(
              "The application does not replace professional medical consultation, physical examination, emergency care, or personalized clinical assessment. For any serious symptoms, abnormal findings, medical emergencies, chronic conditions, or requirement of detailed diagnosis and treatment, users are strongly advised to seek immediate assistance from a qualified healthcare professional or registered medical practitioner.",
              textColor,
            ),
            _disclaimerParagraph(
              "The platform, its developers, affiliates, and associated healthcare partners shall not be held liable for any direct or indirect consequences arising from reliance upon the analysis or suggestions generated through the application.",
              textColor,
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _disclaimerParagraph(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: color,
          height: 1.6,
        ),
      ),
    );
  }
}