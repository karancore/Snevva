import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../consts/consts.dart';

class About extends StatelessWidget {
  const About({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //  final height = mediaQuery.size.height;
    //  final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: AutoSizeText('About'),
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: Icon(
            FontAwesomeIcons.arrowLeft,
            color:
                isDarkMode
                    ? white.withValues(alpha: 0.7)
                    : black.withValues(alpha: 0.8),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                buildTile('Version', 'Tap to check for updates'),
                Spacer(),
                AutoSizeText(
                  'v1.0.0',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            buildTile('Share App', 'Tap to share app'),
            buildTile('Contact Us', 'Feedbacks Appreciated!'),
          ],
        ),
      ),
    );
  }

  Column buildTile(String heading, String subheading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          heading,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),

        AutoSizeText(
          subheading,
          maxFontSize: 14,
          minFontSize: 8,
          style: TextStyle(fontWeight: FontWeight.w400, color: mediumGrey),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
