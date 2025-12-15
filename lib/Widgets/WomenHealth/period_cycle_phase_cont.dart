import 'package:flutter_svg/flutter_svg.dart';

import '../../consts/consts.dart';

class PeriodCyclePhaseCont extends StatelessWidget {
  const PeriodCyclePhaseCont({
    super.key,
    required this.height,
    required this.width,
    required this.heading,
    required this.subHeading,
    required this.img,
    required this.borderColor,
    required this.contColor,
  });

  final double height;
  final double width;
  final String heading;
  final String subHeading;
  final String img;
  final Color borderColor;
  final Color contColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Container(
        height: 120,
        width: width * 0.4,
        padding: EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: contColor,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(color: borderColor, width: border15px),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              heading,
              minFontSize: 14,
              maxFontSize: 20,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            AutoSizeText(
              subHeading,
              minFontSize: 10,
              maxFontSize: 14,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w200),
            ),
            Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(img, height: 40),
            ),
          ],
        ),
      ),
    );
  }
}
