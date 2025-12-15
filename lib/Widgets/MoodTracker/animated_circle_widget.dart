import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart'; // Make sure you have this package

class AnimatedShadowCircle extends StatelessWidget {
  final Gradient gradientColor;
  final Color shadowColor1;
  final Color shadowColor2;
  final double size;
  final bool hideText;
  final String text;

  const AnimatedShadowCircle({
    super.key,
    required this.gradientColor,
    required this.shadowColor1,
    required this.shadowColor2,
    required this.size,
    required this.hideText,
    this.text = '',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          gradient: gradientColor,
          borderRadius: BorderRadius.circular(size * 2),
          boxShadow: [
            BoxShadow(
              color: shadowColor1.withOpacity(0.7),
              spreadRadius: 40,
              blurRadius: 80,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: AutoSizeText(
            hideText ? '' : text, // Static text or whatever you want
            maxLines: 1,
            minFontSize: 20,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
