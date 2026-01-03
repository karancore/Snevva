import 'package:flutter/material.dart';

import '../../consts/colors.dart';

class ExerciseBubbles extends StatefulWidget {
  const ExerciseBubbles({
    super.key,

    required this.isDarkMode,
  });

  final bool isDarkMode;

  @override
  State<ExerciseBubbles> createState() => _ExerciseBubblesState();
}

class _ExerciseBubblesState extends State<ExerciseBubbles> {

  final Set<String> selectedExercises = {};

  bool isSelected = false;
  void onBubbleTap(String exercise) {
    setState(() {
      if (selectedExercises.contains(exercise)) {
        selectedExercises.remove(exercise);
      } else {
        selectedExercises.add(exercise);
      }
    });
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 110,
          child: InkWell(
            onTap: () => onBubbleTap('Chin-ups'),
            child: Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Chin-ups') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Chin-ups',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 360,
          left: 60,
          child: InkWell(
            onTap: () => onBubbleTap('Yoga'),
            child: Container(
              width: 88.0,
              height: 88.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Yoga') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Yoga',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 250,
          child: InkWell(
            onTap: () => onBubbleTap('Pranayam'),
            child: Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Pranayam') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Pranayam',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 1,
          top: 200,
          child: InkWell(
            onTap: () => onBubbleTap('Burpees'),
            child: Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Burpees') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Burpees',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: 170,
          child: InkWell(
            onTap: () => onBubbleTap('Jogging'),
            child: Container(
              width: 100.0,
              height: 100.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Jogging') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Jogging',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 320,
          right: 10,
          child: InkWell(
            onTap: () => onBubbleTap('Squats'),
            child: Container(
              width: 96.0,
              height: 96.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Squats') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Squats',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 240,
          right: 100,
          child: InkWell(
            onTap: () => onBubbleTap('Push-ups'),
            child: Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                color: selectedExercises.contains('Push-ups') ? AppColors.primaryColor : mediumGrey.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'Push-ups',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
