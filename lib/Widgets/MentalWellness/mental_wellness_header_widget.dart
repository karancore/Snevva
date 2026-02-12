import 'package:cached_network_image/cached_network_image.dart';

import 'package:snevva/views/information/music_player_screen.dart';
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
    required this.playText,
  });

  final double height;
  final double width;
  final MusicItem musicItem;
  final double? containerPadding;
  final String wellnessContainerImage;
  final String heading;
  final String subHeading;
  final String playText;
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
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SizedBox(
          height: height,
          width: width,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: wellnessContainerImage,
                  placeholder:
                      (context, url) => Container(color: Colors.black12),
                  errorWidget:
                      (context, url, error) => Container(
                        color: Colors.black12,
                        child: const Icon(
                          Icons.music_note,
                          size: 40,
                          color: Colors.white70,
                        ),
                      ),
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
                          color: white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subHeading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: white, fontSize: 16),
                      ),
                      const Spacer(),
                      playText.isEmpty
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              color: white,
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          )
                          : Container(
                            padding: EdgeInsets.only(
                              top: (containerPadding ?? 10) - 7,
                              left: containerPadding ?? 10,
                              right: (containerPadding ?? 10) + 5,
                              bottom: (containerPadding ?? 10) - 7,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(200),
                              color: white,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.play_arrow,
                                  color: Colors.black,
                                  size: 22,
                                ),
                                playText.isEmpty
                                    ? SizedBox.shrink()
                                    : Padding(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: Text(
                                        playText,
                                        style: TextStyle(
                                          color: black,
                                          fontSize: 16,
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
      ),
    );
  }
}
