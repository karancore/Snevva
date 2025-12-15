import 'package:flutter_svg/flutter_svg.dart';

import '../../consts/consts.dart';

class DashboardServiceWidgetItems extends StatelessWidget {
  final String widgetText;
  final String widgetImg;
  final VoidCallback onTap;

  const DashboardServiceWidgetItems({
    super.key,
    required this.widgetText,
    required this.widgetImg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: 70,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              height: 54,
              width: 54,
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
              child: SvgPicture.asset(widgetImg),
            ),
            SizedBox(height: 6),
            AutoSizeText(
              widgetText,
              minFontSize: 10,
              maxFontSize: 14,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
