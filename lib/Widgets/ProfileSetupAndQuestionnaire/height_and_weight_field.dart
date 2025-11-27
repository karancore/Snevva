import '../../consts/consts.dart';
import 'package:flutter/services.dart';

class HeightAndWeighField extends StatelessWidget {
  const HeightAndWeighField({
    super.key,
    required this.width,
    required this.isDarkMode,
    required this.unit,
    required this.hintText,
    this.controller,
  });

  final double width;
  final bool isDarkMode;
  final String unit;
  final String hintText;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoSizeText(
          hintText,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: defaultSize - 20),

        SizedBox(
          width: width * 0.42,
          child: Material(
            elevation: 1,
            color: isDarkMode ? scaffoldColorDark : scaffoldColorLight,
            borderRadius: BorderRadius.circular(4),
            child: TextFormField(
              controller: controller, // ✅ IMPORTANT: attach controller
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'), // allow decimals like 180.55
                ),
              ],

              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.grey),
                suffixText: unit,
                suffixStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
