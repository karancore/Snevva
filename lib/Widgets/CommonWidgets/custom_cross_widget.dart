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
        child: CircleAvatar(
          radius: 50.0, // Defines the size of the circle (radius, not width/height)
          backgroundColor: Colors.grey, // Background color
          child: Icon( // Optional: Add a child
            Icons.close,
            color: Colors.white,
            size: 40.0,
          ),
        )
        ,
      ),
    );
  }
}
