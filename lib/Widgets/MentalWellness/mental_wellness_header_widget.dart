import 'package:cached_network_image/cached_network_image.dart';
import 'package:snevva/views/Information/music_player_screen.dart';
import '../../consts/consts.dart';
import '../../models/music/music_response.dart';

class MentalWellnessHeaderWidget extends StatelessWidget {
  const MentalWellnessHeaderWidget({
    super.key,
    required this.musicItem,
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
  final MusicItem musicItem;
  final double? containerPadding;
  final String wellnessContainerImage;
  final String heading;
  final String subHeading;
  final String? playText;
  final BoxFit boxFit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          () => Get.to(
            MusicPlayerScreen(
              appBarSubHeading: subHeading,
              musicItem: musicItem,
              appBarHeading: heading,
            ),
          ),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Color(0xFF01021D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wellnessContainerImage,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget:
                    (context, url, error) =>
                        Image.asset(wellnessContainerImage, fit: boxFit),
                fit: boxFit,
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subHeading,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    Spacer(),
                    Container(
                      padding: EdgeInsets.only(
                        left: containerPadding ?? 10,
                        right: (containerPadding ?? 10) + 5,
                        bottom: (containerPadding ?? 10) - 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        color: Colors.white,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, color: Colors.black, size: 28),
                          if (playText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: Text(
                                playText!,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
