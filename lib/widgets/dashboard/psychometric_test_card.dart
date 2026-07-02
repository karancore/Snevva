import 'package:flutter/material.dart';

import '../../consts/colors.dart';
import '../../views/Information/PsychometricTest/psychometric_test_screen.dart';

class PsychometricTestCard extends StatelessWidget {
  const PsychometricTestCard({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PsychometricTestScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: isDarkMode ? darkGray : white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.white12 : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                color: white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Take Psychometric Test',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? white : black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Understand your mind & personality in 2 mins',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDarkMode ? Colors.white60 : mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}