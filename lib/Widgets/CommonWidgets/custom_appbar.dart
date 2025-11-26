import 'package:flutter_svg/flutter_svg.dart';
import '../../consts/consts.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.appbarText,
    this.isWhiteRequired = false,
    this.showDrawerIcon = true,
    this.showCloseButton = true,
    this.onClose
  });

  final String appbarText;
  final bool? isWhiteRequired;
  final bool showDrawerIcon;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return SafeArea(
      child: AppBar(
        backgroundColor: isDarkMode ? black : white,
        centerTitle: true,
        title: Text(
          appbarText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isWhiteRequired! ? white : (isDarkMode ? white : black),
          ),
        ),

        // Conditionally show leading drawer icon
        leading:
            showDrawerIcon
                ? Builder(
                  builder:
                      (context) => IconButton(
                        icon: SvgPicture.asset(
                          isWhiteRequired! ? drawerIconWhite : drawerIcon,
                        ),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                )
                : null,

        // Conditionally show close (cross) icon
        actions:
            showCloseButton
                ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      onTap: onClose != null ? onClose! : () => Navigator.pop(context),
                      child:
                          isWhiteRequired!
                              ? SizedBox(
                                height: 24,
                                width: 24,
                                child: Icon(
                                  Icons.clear,
                                  size: 21,
                                  color:
                                      white, // Keep white if explicitly required
                                ),
                              )
                              : SizedBox(
                                height: 24,
                                width: 24,
                                child: Icon(
                                  Icons.clear,
                                  size: 21,
                                  color:
                                      isDarkMode
                                          ? white
                                          : black, // Adapt to theme
                                ),
                              ),
                    ),
                  ),
                ]
                : [],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
