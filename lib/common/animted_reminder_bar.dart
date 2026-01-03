import 'package:flutter/material.dart';
import 'package:snevva/consts/colors.dart';

class AnimatedReminderBar extends StatefulWidget {
  const AnimatedReminderBar({super.key, this.show});

  final bool? show;

  @override
  State<AnimatedReminderBar> createState() => _AnimatedReminderBarState();
}

class _AnimatedReminderBarState extends State<AnimatedReminderBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late bool _showBar;

  @override
  void initState() {
    super.initState();

    _showBar = widget.show == true;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    // ❗ Hide bar when animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showBar = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!_showBar) return const SizedBox.shrink(); // 🔥 Hide widget

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 40,
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: _controller.value,
                backgroundColor: grey.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.check_box, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Reminder has been saved and scheduled.",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: black,
                      ),
                    ),
                  ),
                  const Text(
                    "DONE",
                    style: TextStyle(color: Color(0xff00CA5B)),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
