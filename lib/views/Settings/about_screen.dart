import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../consts/consts.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //  final height = mediaQuery.size.height;
    //  final width = mediaQuery.size.width;
    // ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: AutoSizeText('About'),
        iconTheme: IconThemeData(color: isDarkMode ? white : black, size: 20),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          "Snevva summary for the about section: SNEVVA is an AI-powered health companion offering symptom guidance, lab report insights, medicine reminders, period tracking, and expert consultations to support informed health decisions anytime, anywhere.",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color:
                isDarkMode ? white.withValues(alpha: 0.9) : Color(0xff878787),
          ),
        ),
      ),
    );
  }
}
