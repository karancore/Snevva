import 'package:cached_network_image/cached_network_image.dart';
import 'package:snevva/views/Information/music_player_screen.dart';
import '../../consts/consts.dart';
import '../../models/music/music_response.dart';

class MentalWellnessFooterWidget extends StatelessWidget {
  const MentalWellnessFooterWidget({
    super.key,
    required this.musicItem,
    required this.wellnessContainerImage,
    required this.heading,
    required this.subHeading,
  });

  final String wellnessContainerImage;
  final String heading;
  final String subHeading;
  final MusicItem musicItem;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:
          () => Get.to(
            MusicPlayerScreen(
              appBarHeading: heading,
              appBarSubHeading: subHeading,
              musicItem: musicItem,
            ),
          ),
      child: Container(
        height: 108,
        width: 108,
        // margin: EdgeInsets.only(right: 20),
        //padding: const EdgeInsets.all(10.0),
        decoration: BoxDecoration(
          color: Color(0xFF01021D),
          borderRadius: BorderRadius.circular(50),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: wellnessContainerImage,
                placeholder: (context, url) => Container(color: Colors.black12),
                errorWidget:
                    (context, url, error) =>
                        Image.asset(wellnessContainerImage, fit: BoxFit.cover),
                fit: BoxFit.cover,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,

                  children: [
                    SizedBox(height: 10),
                    Icon(Icons.play_arrow, color: black, size: 20),
                    SizedBox(height: 15),
                    Text(
                      heading,
                      style: TextStyle(color: black, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subHeading,
                      style: TextStyle(color: black, fontSize: 16),
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
