
import 'package:flutter_svg/svg.dart';
import '../../Controllers/WomenHealth/women_health_controller.dart';
import '../../consts/consts.dart';

class WomenHealthTopCont extends StatefulWidget {
  const WomenHealthTopCont({
    super.key,
    required this.isDarkMode,
    required this.height,
  });

  final bool isDarkMode;
  final double height;

  @override
  State<WomenHealthTopCont> createState() => _WomenHealthTopContState();

}

class _WomenHealthTopContState extends State<WomenHealthTopCont> {

  final WomenHealthController womenController = Get.find<WomenHealthController>();


  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(16.0),
      color: widget.isDarkMode ? scaffoldColorDark : scaffoldColorLight,
      child: Container(
        height: widget.height * 0.25,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: AppColors.primaryColor,
            width: border04px,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image(
                  image: AssetImage(periodContainerTopEffect),
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: AppColors.primaryColor,
                    width: border04px + 0.2,
                  ),
                ),
                child: Row(
                  children: [
                    SvgPicture.asset(calenderIcon, height: 16),
                    SizedBox(width: 4),
                    Obx(() => Text(womenController.formattedCurrentDate.value, style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SvgPicture.asset(
                  periodContainerBottomCircle,
                  height: widget.height * 0.16,
                ),
              ),
            ),
            Positioned(
              bottom: 5,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AutoSizeText(
                      "Periods in",
                      minFontSize: 12,
                      maxFontSize: 16,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  Obx(
                    ()=> AutoSizeText(
                         "${womenController.dayLeftNextPeriod.value} days",
                          minFontSize: 20,
                          maxFontSize: 28,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 28,
                            color: white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
