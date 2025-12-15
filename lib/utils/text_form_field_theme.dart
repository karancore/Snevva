import 'package:flutter/material.dart';

import '../consts/colors.dart';

class TextFormFieldTheme {
  TextFormFieldTheme._();

  static InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: mediumGrey, width: 0.4),

      borderRadius: BorderRadius.circular(4),
    ),
    prefixIconColor: Colors.grey,
    suffixIconColor: Colors.grey,
    floatingLabelStyle: const TextStyle(color: Colors.black),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: Color(0xFFB579FF)),
    ),
  );

  static InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
      borderSide: BorderSide(color: mediumGrey, width: 0.4),
      borderRadius: BorderRadius.circular(4),
    ),
    prefixIconColor: AppColors.primaryColor,
    suffixIconColor: AppColors.primaryColor,
    // floatingLabelStyle: const TextStyle(color: AppColors.primaryColor),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(width: 2, color: Color(0xFFB579FF)),
    ),
  );
}
