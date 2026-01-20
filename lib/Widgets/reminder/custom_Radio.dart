import '../../consts/colors.dart' as Colors;
import '../../consts/consts.dart';

class CustomRadio extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final double strokeWidth;

  const CustomRadio({
    super.key,
    required this.selected,
    required this.onTap,
    this.size = 18,
    this.activeColor = Colors.black,
    this.inactiveColor = Colors.grey,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? activeColor : inactiveColor,
              width: strokeWidth,
            ),
          ),
          child: selected
              ? Center(
            child: Container(
              width: size * 0.5,
              height: size * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
              ),
            ),
          )
              : null,
        ),
      ),
    );
  }
}
