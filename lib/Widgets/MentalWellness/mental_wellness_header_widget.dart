import 'package:snevva/views/Information/music_player_screen.dart';
import '../../consts/consts.dart';

class MentalWellnessHeaderWidget extends StatelessWidget {
  const MentalWellnessHeaderWidget({
    super.key,
    required this.height,
    required this.width,
    this.containerPadding,
    required this.wellnessContainerImage,
    required this.heading,
    required this.subHeading,
    required this.boxFit,
    this.playText,
  });

  final double height;
  final double width;
  final double? containerPadding;
  final String wellnessContainerImage;
  final String heading;
  final String subHeading;
  final String? playText;
  final BoxFit boxFit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.to(MusicLPlayerScreen(appBarSubHeading: subHeading)),
      child: Container(
        height: height,
        width: width,
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Color(0xFF01021D),
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(
            image: AssetImage(wellnessContainerImage),
            fit: boxFit,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: TextStyle(color: Colors.white, fontSize: 20)),
            Text(
              subHeading,
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
            Spacer(),
            Container(
              padding:
                  containerPadding != null
                      ? EdgeInsets.only(
                        left: containerPadding!,
                        right: containerPadding! + 5,
                        bottom: containerPadding! - 7,
                      )
                      : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,

                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.black, size: 28),
                  if (playText != null)
                    Text(
                      playText!,
                      style: TextStyle(color: Colors.black, fontSize: 20),
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
