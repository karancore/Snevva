import 'package:flutter/material.dart';
import 'package:snevva/consts/colors.dart';

class AppointmentCard extends StatelessWidget {
  final String doctorName;
  final String specialty;
  final String imagePath;
  final String date;
  final String time;
  final bool isHistory;

  const AppointmentCard({
    super.key,
    required this.doctorName,
    required this.specialty,
    required this.imagePath,
    required this.date,
    required this.time,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = isHistory
        ? null
        : docAppContiner;

    final containerColor = isHistory ? Colors.grey.shade200 : null;
    final textColor = isHistory ? Colors.black87 : Colors.white;
    final subtitleColor = isHistory ? Colors.black54 : Colors.white70;
    final infoBg = isHistory ? Colors.grey.shade300 : null;

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: containerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: AssetImage(imagePath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isHistory)
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 20,
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFA95BFF), Color(0xFFB579FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.call,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              gradient: isHistory ? null : AppColors.primaryGradient,
              color: infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 16, color: textColor.withOpacity(0.3)),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text(
                  time,
                  style: TextStyle(color: textColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
