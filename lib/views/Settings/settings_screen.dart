import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:snevva/views/Settings/about.dart';
import '../../Widgets/Setting/setting_item_widget.dart';
import '../../consts/consts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    //  final height = mediaQuery.size.height;
    //  final width = mediaQuery.size.width;
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: AutoSizeText('Settings'),
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Material(
                elevation: 1,
                color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
                borderRadius: BorderRadius.circular(4),
                child: TextFormField(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    suffixIcon: const Icon(Icons.search),
                    hintText: 'Search Available Settings',
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
              SizedBox(height: defaultSize + 20),
        
              SettingItemWidget(
                icon: themeIcon,
                heading: 'Theme',
                subHeading: 'Dark Theme, Light Theme',
                onTap: () {},
              ),
              SizedBox(height: defaultSize),
              SettingItemWidget(
                icon: appUiIcon,
                heading: 'App UI',
                subHeading: 'Accent Color, Theme Color',
                onTap: () {},
              ),
              SizedBox(height: defaultSize),
              SettingItemWidget(
                icon: volumeIcon,
                heading: 'Volume & Access',
                subHeading: 'App Volume, Streaming Quality, App Permission',
                onTap: () {},
              ),
              SizedBox(height: defaultSize),
              SettingItemWidget(
                icon: othersIcon,
                heading: 'Other',
                subHeading: 'Language, Country',
                onTap: () {},
              ),
              SizedBox(height: defaultSize),
              SettingItemWidget(
                icon: aboutFilledIcon,
                heading: 'About',
                subHeading: 'Version, Share App, Contact Us',
                onTap: () {
                  Get.to(() => About());
                },
              ),
              SizedBox(height: defaultSize),
            ],
          ),
        ),
      ),
    );
  }
}
