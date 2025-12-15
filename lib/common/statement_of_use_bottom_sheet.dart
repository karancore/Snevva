import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../views/Information/vitals.dart';
import '../consts/colors.dart';

class StatementOfUseBottomSheet extends StatelessWidget {
  const StatementOfUseBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Statement of Use",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            '"Snevvalink" is a platform that helps users monitor their vital signs.\n\n'
            'If you select Agree and use, you agree to:',
            style: TextStyle(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: const [
              Text("Service Agreement", style: TextStyle(color: Colors.blue)),
              Text(" and "),
              Text("Privacy Notices", style: TextStyle(color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 20),
          // Agree button
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true); // return true to parent
              },
              child: const Text("Agree and continue"),
            ),
          ),
          const SizedBox(height: 10),
          // Disagree button
          TextButton(
            onPressed: () => Navigator.pop(context, false), // return false
            child: const Text("Disagree", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showStatementsOfUseBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const StatementOfUseBottomSheet(),
  );
}
