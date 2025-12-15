import 'package:snevva/utils/text_form_field_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../consts/consts.dart';

class SnevvaTheme {
  SnevvaTheme._();

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: scaffoldColorLight,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((
        Set<MaterialState> states,
      ) {
        if (states.contains(MaterialState.selected)) {
          return Colors.black;
        }
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(Colors.white),
    ),
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(color: Colors.black),
      elevation: 0.0,
      backgroundColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(),
    inputDecorationTheme: TextFormFieldTheme.lightInputDecorationTheme,
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: scaffoldColorDark,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith<Color>((
        Set<MaterialState> states,
      ) {
        if (states.contains(MaterialState.selected)) {
          return Colors.grey;
        }
        return Colors.transparent;
      }),
      checkColor: MaterialStateProperty.all(Colors.black),
    ),
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(color: Colors.white.withValues(alpha: 0.1)),
      elevation: 0.0,
      backgroundColor: Colors.transparent,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(),

    inputDecorationTheme: TextFormFieldTheme.darkInputDecorationTheme,
  );
}
