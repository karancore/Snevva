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

  static final LinearGradient whiteDrawerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFFA95BFF),
      const Color(0xFFAF6BFF),
      const Color(0xFFB579FF),
      const Color(0xFFC391FF),
      const Color(0xFFD2AEFF),
      const Color(0xFFE3CCFF),
      const Color(0xFFF1E7FF),
      white.withOpacity(0.96),
      white,
    ],
    stops: const [
      0.0,
      0.12,
      0.24,
      0.38,
      0.52,
      0.68,
      0.82,
      0.93,
      1.0,
    ],
  );

  static final LinearGradient purpleToBlackDrawerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFFA95BFF), // header purple — exact match
      const Color(0xFF9A52F0), // slightly darker
      const Color(0xFF7B3DC8), // mid-dark purple
      const Color(0xFF5C2D96), // deeper
      const Color(0xFF3E1E64), // dark violet
      const Color(0xFF251238), // near-black purple
      const Color(0xFF120918), // almost black
      const Color(0xFF050305), // near-black
      Colors.black, // pure black — matches body
    ],
    stops: const [0.00, 0.12, 0.26, 0.40, 0.54, 0.67, 0.79, 0.90, 1.00],
  );
  static const Gradient greenGradient = LinearGradient(
    colors: [Color(0xFF56D364), Color(0xFF2EA043)],
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
  );
  static const Color secondaryColor = Color(0xffB475FF);
  static const Color primaryLight4PercentOpacity = Color(0x0A62FF0A);

  static const Color activeSwitch = Color(0xFFA95BFF);

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
