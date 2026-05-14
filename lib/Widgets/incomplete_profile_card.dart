import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controllers/local_storage_manager.dart';
import '../../consts/colors.dart';

class IncompleteProfileCard extends StatelessWidget {
  final VoidCallback onTapComplete;

  const IncompleteProfileCard({super.key, required this.onTapComplete});

  bool isFilled(dynamic value) {
    if (value == null) return false;
    if (value is String && value.trim().isEmpty) return false;
    return true;
  }

  int calculateProfileCompletion(Map<String, dynamic> userInfo) {
    int totalFields = 9;
    int completedFields = 0;

    if (isFilled(userInfo['Name'])) completedFields++;
    if (isFilled(userInfo['PhoneNumber'])) completedFields++;
    if (isFilled(userInfo['Email'])) completedFields++;
    if (isFilled(userInfo['Gender'])) completedFields++;
    if (userInfo['DayOfBirth'] != null &&
        userInfo['MonthOfBirth'] != null &&
        userInfo['YearOfBirth'] != null) {
      completedFields++;
    }
    if (isFilled(userInfo['AddressByUser'])) completedFields++;
    if (isFilled(userInfo['PostalCodeUser'])) completedFields++;
    if (userInfo['OccupationData'] != null &&
        isFilled(userInfo['OccupationData']['Name'])) {
      completedFields++;
    }
    if (userInfo['ProfilePicture'] != null &&
        isFilled(userInfo['ProfilePicture']['CdnUrl'])) {
      completedFields++;
    }

    return ((completedFields / totalFields) * 100).round();
  }

  String getNextMissingField(Map<String, dynamic> userInfo) {
    if (!isFilled(userInfo['Email'])) return 'Add email';
    if (!isFilled(userInfo['AddressByUser'])) return 'Add address';
    if (!isFilled(userInfo['PostalCodeUser'])) return 'Add postal code';
    if (!isFilled(userInfo['PhoneNumber'])) return 'Add phone number';
    return 'Complete profile';
  }

  @override
  Widget build(BuildContext context) {
    final localStorageManager = Get.find<LocalStorageManager>();
    final userInfo = localStorageManager.userMap;
    final completedPercent = calculateProfileCompletion(userInfo);
    final leftPercent = (100 - completedPercent).clamp(0, 100);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Light: soft purple tint at 10% | Dark: white at 10%
        color:
            isDarkMode
                ? Colors.white.withOpacity(0.10)
                : AppColors.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryColor.withOpacity(0.20),
          width: 1,
        ),
        // Card shadow matching Snevva spec
        boxShadow:
            isDarkMode
                ? []
                : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──────────────────────────────────────────
          Row(
            children: [
              // Circular icon chip — icon color at 20% bg (Snevva card style)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Complete your profile',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? white : black,
                  ),
                ),
              ),

              // "X% left" badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$leftPercent% left',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Progress Bar ─────────────────────────────────────────
          Stack(
            children: [
              // Track
              Container(
                height: 7,
                decoration: BoxDecoration(
                  color:
                      isDarkMode
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              // Fill — purple gradient
              FractionallySizedBox(
                widthFactor: (completedPercent / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB579FF), Color(0xFFA95BFF)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── Completion label ──────────────────────────────────────
          Text(
            '$completedPercent% complete',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: isDarkMode ? Colors.white.withOpacity(0.55) : mediumGrey,
            ),
          ),

          const SizedBox(height: 14),

          // ── CTA Button — primary purple gradient ──────────────────
          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB579FF), Color(0xFFA95BFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ElevatedButton(
                onPressed: onTapComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(getNextMissingField(userInfo)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
