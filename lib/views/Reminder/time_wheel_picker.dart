

import 'package:flutter/material.dart';
import 'package:wheel_picker/wheel_picker.dart';

class TimeWheelPicker extends StatelessWidget {
  const TimeWheelPicker({super.key , required this.hourController, required this.minuteController});
  final WheelPickerController hourController;
  final WheelPickerController minuteController;


  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        /// HOURS
        SizedBox(
          width: 80,
          height: 200,
          child: WheelPicker(
            controller: hourController,
            builder: (context, index) {
              final hour = index + 1; // 1–24
              return Center(
                child: Text(
                  hour.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 22),
                ),
              );
            },
            onIndexChanged: (index , interactionType) {
              print("Selected Hour: ${index + 1}");
            },
          ),
        ),

        const Text(":"),

        /// MINUTES
        SizedBox(
          width: 80,
          height: 200,
          child: WheelPicker(
            controller: minuteController,
            builder: (context, index) {
              return Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 22),
                ),
              );
            },
            onIndexChanged: (index , interactionType) {
              print("Selected Minute: $index");
            },
          ),
        ),
      ],
    );
  }
}
