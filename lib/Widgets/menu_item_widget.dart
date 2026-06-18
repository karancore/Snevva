import 'package:flutter_svg/flutter_svg.dart';

import '../consts/consts.dart';

class MenuItem {
  final String title;
  final String subtitle;
  final String imagePath;
  final Widget? navigateTo;
  final String ? darkImagePath;
  final VoidCallback? onTap;
  final String? routeName;
  final bool? isDisabled;

  MenuItem({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.darkImagePath,
    this.routeName,
    this.navigateTo,
    this.isDisabled = false,
    this.onTap,
  });
}

class MenuItemWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Widget? navigateTo;
  final String? routeName;
  final bool isDarkMode;
  final String ? darkImagePath;
  final VoidCallback? onTap;
  final bool isDisabled; // 👈 add this

  const MenuItemWidget({
    super.key,
    required this.title,
    this.routeName,
    this.darkImagePath,
    required this.subtitle,
    required this.imagePath,
    this.navigateTo,
    this.onTap,
    required this.isDarkMode,
    this.isDisabled = false, // 👈 add this
  });

  @override
  Widget build(BuildContext context) {
 
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isDisabled ? null : (onTap ?? () {
        if (navigateTo != null) Get.to(() => navigateTo!);
      }),

      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: SvgPicture.asset(
                      isDarkMode && darkImagePath != null
                          ? darkImagePath!
                          : imagePath,
                      fit: BoxFit.cover,
                      width: 28,
                      height: 28,
                      color: isDisabled ? Colors.grey : null, // 👈 grey if disabled
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDisabled ? Colors.grey : null, // 👈
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDisabled ? Colors.grey : null, // 👈
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDisabled ? Colors.grey : null, // 👈
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(thickness: border04px, color: mediumGrey),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}