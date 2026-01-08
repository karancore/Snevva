import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../consts/colors.dart';

class DashboardContainerWidget extends StatelessWidget {
  const DashboardContainerWidget({
    super.key,
    required this.width,
    required this.height,
    required this.isDarkMode,
    required this.widgetName,
    required this.widgetIcon,
    this.onTap,

    required this.content,
    required this.valueText,
    required this.valuePraisingText,
  });

  final double width;
  final double height;
  final String widgetName;
  final String widgetIcon;
  final VoidCallback? onTap;
  final bool isDarkMode;
  final Widget valueText;
  final String valuePraisingText;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width / 2.5,
        height: width / 2.5,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 2,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(widgetIcon, height: 24, width: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AutoSizeText(
                      widgetName,
                      maxLines: 1,
                      minFontSize: 8,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (valuePraisingText.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        valueText,
                        AutoSizeText(
                          valuePraisingText,
                          minFontSize: 8,
                          style: const TextStyle(fontSize: 8),
                        ),
                      ],
                    )
                  else
                    valueText,
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
