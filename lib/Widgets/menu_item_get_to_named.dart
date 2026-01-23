import 'package:flutter_svg/flutter_svg.dart';

import '../consts/consts.dart';

class MenuItemToNamed {
  final String title;
  final String subtitle;
  final String imagePath;
  final Widget? navigateTo;
  final VoidCallback? onTap;
  final bool? isDisabled;

  MenuItemToNamed({
    required this.title,
    required this.subtitle,
    required this.imagePath,
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
  final bool isDarkMode;
  final VoidCallback? onTap;

  const MenuItemWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    this.navigateTo,
    this.onTap,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final disabledColor = Colors.grey;

    return title == "AI Symptom Checker"
        ? Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SvgPicture.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  color: disabledColor.withOpacity(1),
                ),
              ),
              const SizedBox(width: 12),

              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: disabledColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: disabledColor),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Icon(Icons.arrow_forward_ios, size: 16, color: disabledColor),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(thickness: border04px, color: mediumGrey),
          const SizedBox(height: 10),
        ],
      ),
    )
        : GestureDetector(
      onTap:
      onTap ??
              () {
            if (navigateTo != null) {
              Get.to(() => navigateTo!);
            }
          },
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SvgPicture.asset(imagePath, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),

                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),

                // Arrow icon
                const Icon(Icons.arrow_forward_ios, size: 16),
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
