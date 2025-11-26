
import '../../consts/consts.dart';

class HeightAndWeighField extends StatelessWidget {
  const HeightAndWeighField({
    super.key,
    required this.width,
    required this.isDarkMode,
    required this.unit,
    required this.hintText,
  });

  final double width;
  final bool isDarkMode;
  final String unit;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          hintText,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: defaultSize - 20),
        SizedBox(
          width: width * 0.42,
          child: Material(
            elevation: 1,
            color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
            borderRadius: BorderRadius.circular(4),
            child: TextFormField(
              decoration: InputDecoration(
                alignLabelWithHint: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                suffixText: unit,
                suffixStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),

      ],
    );
  }
}
