import 'package:flutter/material.dart';

// Simple Common colors
const Color grey = Colors.grey;
const Color mediumGrey = Color(0xFF878787);
const Color darkGray = Color(0xFF2B2B2B);
const Color white = Colors.white;
const Color transparent = Colors.transparent;

const Color black = Colors.black;
const Color green = Color(0xFF8CDC52);
const Color yellow = Color(0xFFFFD900);

final LinearGradient docAppContiner = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBE89FF), Color(0xFFC896FF)],
);

class AppColors {
  // App's Primary Color
  static const Color primaryColor = Color(0xFFA95BFF);
  static const Color primaryLight4PercentOpacity = Color(0x0A62FF0A);

  static const Color activeSwitch = Color(0xFF34C759);

  // Primary gradient
  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFFB579FF), Color(0xFFA95BFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const Gradient whiteGradient = LinearGradient(
    colors: [white, white],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

const Gradient hydrationGraphShadowColor = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFBE89FF), Color(0x00C390FF)],
);

//Scaffold Colors
final Color scaffoldColorDark = Color(0xFF000100);
final Color scaffoldColorLight = Color(0xFFFFFEFF);

// Splash Screen Colors
const Color splashScreenBg = Color(0xFFC1B7C9);

//Emergency Container
const Color vividRed = Color(0xFFFF5151);

//  Women Health Cycle Phase Container Background
const Color periodHighlighted = Color(0xFFFF0084);

//Mood Tracker Container Gradient
const contColor1 = Color(0xFFEE53FF);
const contColor2 = Color(0xFFAC68FF);
const contColor21 = Color(0xFFFFD037);
const contColor22 = Color(0xFFFF9238);
const contColor31 = Color(0xFF78F4FF);
const contColor32 = Color(0xFF6E90FF);

const Gradient mood1 = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [contColor1, contColor2],
);

const Gradient mood2 = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [contColor21, contColor22],
);

const Gradient mood3 = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [contColor31, contColor32],
);
