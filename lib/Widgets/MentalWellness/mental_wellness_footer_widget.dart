import 'package:snevva/views/Information/music_player_screen.dart';
import '../../consts/consts.dart';

class MentalWellnessFooterWidget extends StatelessWidget {
  const MentalWellnessFooterWidget({
    super.key,
    required this.wellnessContainerImage,
    required this.heading,
    required this.subHeading,
  });

  final String wellnessContainerImage;
  final String heading;
  final String subHeading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          () => Get.to(
            MusicLPlayerScreen(
              appBarHeading: heading,
              appBarSubHeading: subHeading,
            ),
          ),
      child: Container(
        height: 100,
        width: 100,
        margin: EdgeInsets.only(right: 20),
        padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Color(0xFF01021D),
          borderRadius: BorderRadius.circular(50),
          image: DecorationImage(
            image: AssetImage(wellnessContainerImage),
            fit: BoxFit.fill,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,

          children: [
            Icon(Icons.play_arrow, color: Colors.white, size: 20),
            SizedBox(height: 10),
            Text(heading, style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              subHeading,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
