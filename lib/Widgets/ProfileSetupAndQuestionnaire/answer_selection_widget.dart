import '../../consts/consts.dart';

class AnswerSelectionWidget extends StatelessWidget {
  final String widgetText;
  final String img;
  final bool multipleSelection;
  final bool isSelected;
  final VoidCallback onTap;
  final int questionIndex;

  const AnswerSelectionWidget({
    super.key,
    required this.widgetText,
    required this.img,
    required this.multipleSelection,
    required this.isSelected,
    required this.onTap,
    required this.questionIndex,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryColor.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            width: border04px,
            color: isSelected ? AppColors.primaryColor : Colors.grey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: AssetImage(img), height: 12, width: 12),
            const SizedBox(width: 5),
            Text(
              widgetText,
              style: TextStyle(fontSize: 10 , fontWeight: FontWeight.w400),
            ),
            const SizedBox(width: 5),
            Icon(
              multipleSelection ? Icons.add : Icons.check,
              size: 10,
              color: isSelected ? AppColors.primaryColor : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
