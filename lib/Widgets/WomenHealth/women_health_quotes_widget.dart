import 'package:cached_network_image/cached_network_image.dart';

import '../../consts/consts.dart';

class WomenHealthQuotesWidget extends StatelessWidget {
  const WomenHealthQuotesWidget({
    super.key,
    required this.title,
    required this.shortDescription,
    required this.imageUrl,
  });

  final String shortDescription;
  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Container(
                //   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                //   decoration: BoxDecoration(
                //     borderRadius: BorderRadius.circular(4),
                //     color: Colors.red.withValues(alpha: 0.9),
                //   ),
                //   child: Text(
                //     "title",
                //     style: TextStyle(color: Colors.red.withValues(alpha: 0.1)),
                //   ),
                // ),
                SizedBox(height: 10),
                AutoSizeText(
                  title,
                  minFontSize: 10,
                  maxFontSize: 16,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 10),
                AutoSizeText(
                  shortDescription,
                  minFontSize: 10,
                  maxFontSize: 14,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: mediumGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          CachedNetworkImage(
            imageUrl:
                imageUrl.isEmpty
                    ? "https://$imageUrl"
                    : "https://d3byuuhm0bg21i.cloudfront.net/derivatives/c3d47d00-8a25-46ef-bba3-ec5609c49b08/thumb.webp",
            height: 120,
          ),
        ],
      ),
    );
  }
}
