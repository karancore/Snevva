import 'package:flutter_svg/flutter_svg.dart';
import '../../consts/consts.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    required this.appbarText,
    this.isWhiteRequired = false,
    this.showDrawerIcon = true,
    this.showCloseButton = true,
    this.onClose,
  });

  final String appbarText;
  final bool? isWhiteRequired;
  final bool showDrawerIcon;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: isDarkMode ? black : white,
        centerTitle: true,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: isDarkMode ? black : white,

        title: Text(
          appbarText,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isWhiteRequired! ? white : (isDarkMode ? white : black),
          ),
        ),

        leading:
            showDrawerIcon
                ? Builder(
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: IconButton(
                        iconSize: 200.0,
                        icon: SvgPicture.asset(
                          isWhiteRequired! ? drawerIconWhite : drawerIcon,
                        ),
                        onPressed: () {
                          // 🔍 Check if Scaffold exists
                          final scaffold = Scaffold.maybeOf(context);

                          if (scaffold != null) {
                            scaffold.openDrawer();
                          }
                        },
                      ),
                    );
                  },
                )
                : IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    size: 24,
                    color:
                        isWhiteRequired! ? white : (isDarkMode ? white : black),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

        actions:
            showCloseButton
                ? [
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: InkWell(
                      onTap: () {
                        onClose != null ? onClose!() : Navigator.pop(context);
                      },
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: Icon(
                          Icons.clear,
                          size: 21,
                          color:
                              isWhiteRequired!
                                  ? white
                                  : (isDarkMode ? white : black),
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
