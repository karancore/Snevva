import 'package:flutter_svg/flutter_svg.dart';
import '../../consts/consts.dart';

class CustomCrossWidget extends StatelessWidget {
  const CustomCrossWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: InkWell(
        onTap: () => Get.back(),
        child: SvgPicture.asset(appbarActionCross),
      ),
    );
  }
}
