import '../../consts/consts.dart';

class MoodAnswerSelectionWidget extends StatelessWidget {
  const MoodAnswerSelectionWidget({
    super.key,
    required this.height,
    required this.heading,
    required this.subHeading,
    required this.isSelected,
    required this.onTap,
    required this.isDarkMode,
    required this.index,
  });

  final double height;
  final String heading;
  final String subHeading;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    return (index == 3)
        ? SizedBox.shrink()
        : InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: height * 0.1,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mediumGrey, width: border04px),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutoSizeText(
              heading,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 18,
                color:
                isSelected
                    ? white
                    : isDarkMode
                    ? white
                    : black,
              ),
            ),
            AutoSizeText(
              subHeading,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: isSelected ? white : mediumGrey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
