import 'package:flutter_svg/svg.dart';

import '../../consts/consts.dart';

class SettingItemWidget extends StatelessWidget {
  final String icon;
  final String heading;
  final String subHeading;
  final VoidCallback onTap;

  const SettingItemWidget({
    super.key,
    required this.icon,
    required this.heading,
    required this.subHeading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(icon, height: 30, width: 30),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AutoSizeText(
                    heading,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),

                  AutoSizeText(
                    subHeading,
                    maxFontSize: 14,
                    minFontSize: 8,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: mediumGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
