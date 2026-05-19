import 'package:cached_network_image/cached_network_image.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/common_tips_response.dart';

import '../../Controllers/common/common_tips_controller.dart';
import '../../views/information/Health Tips/Nutrition_tips.dart/nutrition_tips.dart';

class CommonTipsList extends StatefulWidget {
  const CommonTipsList({super.key});

  @override
  State<CommonTipsList> createState() => _CommonTipsListState();
}

class _CommonTipsListState extends State<CommonTipsList> {
  final CommonTipsController controller = Get.find<CommonTipsController>();

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double scale = MediaQuery.of(context).size.width / 360;

    return Obx(() {
      if (controller.isLoading.value) {
        return AppLoader();
      }

      /// EMPTY
      if (controller.commonTips.isEmpty) {
        return Center(
          child: Text(
            "Sorry! We have no tips for you currently!",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      final showLoader = controller.isLoadingMore.value;

      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.commonTips.length + (showLoader ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= controller.commonTips.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: AppLoader(size: 32)),
            );
          }

          final item = controller.commonTips[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 16 * scale),
            child: _commonCard(
              isDarkMode: isDarkMode,
              heading: item.title ?? '',
              subheading: item.heading ?? '',
              imageUrl: item.thumbnailMedia?.cdnUrl ?? '',
              scale: scale,
              commonTip: item,
            ),
          );
        },
      );
    });
  }

  Widget _commonCard({
    required bool isDarkMode,
    required String heading,
    required String subheading,
    required String imageUrl,
    required double scale,
    required CommonTip commonTip,
  }) {
    // final imageUrl = data?.imageUrl;
    final completeImgUrl = "https://$imageUrl";
    return InkWell(
      onTap: () {
        Get.to(() => NutritionTipsPage(commonTip: commonTip));
      },
      child: Material(
        color: Colors.transparent,
        elevation: 3,
        child: Container(
          width: double.infinity,
          height: 210 * scale,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isDarkMode ? black : white,
            border: Border.all(width: border04px, color: mediumGrey),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Color(0x14000000) : Color(0x14FFFFFF),
                offset: const Offset(0, 0),
                blurRadius: 8,
                spreadRadius: 4,
              ),
            ],
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150 * scale,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: CachedNetworkImage(
                    imageUrl:
                        completeImgUrl.isEmpty
                            ? placeHolderImage
                            : completeImgUrl,
                    height: 32.0,
                    width: double.infinity,
                    fit: BoxFit.cover,

                    placeholder:
                        (_, _) => Container(
                          height: 140,
                          alignment: Alignment.center,
                          child: const AppLoader(),
                        ),

                    errorWidget:
                        (_, _, _) => Container(
                          height: 140,
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image),
                        ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsGeometry.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subheading,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: mediumGrey,
                        fontWeight: FontWeight.w400,
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
