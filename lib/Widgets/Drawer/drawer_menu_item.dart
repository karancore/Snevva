import 'package:flutter_svg/flutter_svg.dart';
import '../../consts/consts.dart';
import 'package:flutter/material.dart';

class DrawerMenuItem extends StatelessWidget {
  const DrawerMenuItem({
    super.key,
    required this.menuIcon,
    required this.itemName,
    required this.onWidgetTap,
    this.isDisabled = false,
  });

  final String menuIcon;
  final String itemName;
  final GestureTapCallback onWidgetTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final disabledColor = Colors.grey.withOpacity(0.5);
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: isDisabled ? null : onWidgetTap,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                menuIcon,
                width: 24,
                height: 24,
                color: isDisabled
                    ? disabledColor
                    : Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: 10),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: isDisabled ? "$itemName " : itemName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDisabled
                            ? disabledColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    if (isDisabled)
                      TextSpan(
                        text: "Upcoming",
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: disabledColor,
                        ),
                      ),
                  ],
                ),
              )

            ],
          ),
        ),
      ),
    );
  }
}
