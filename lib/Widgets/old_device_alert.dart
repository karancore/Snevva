import 'package:flutter/material.dart';

class OldDeviceAlert extends StatelessWidget {
  final Map<String, dynamic> deviceInfo;
  final VoidCallback onConfirmDevice;
  final VoidCallback onRejectDevice;

  const OldDeviceAlert({
    super.key,
    required this.deviceInfo,
    required this.onConfirmDevice,
    required this.onRejectDevice,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final Color dialogBgColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors
        .white;
    final Color subtitleColor = isDarkMode ? Colors.white60 : Colors.grey
        .shade600;
    final Color cardBgColor = isDarkMode ? const Color(0xFF262626) : Colors.grey
        .shade50;
    final Color cardBorderColor = isDarkMode ? const Color(0xFF3A3A3A) : Colors
        .grey.shade200;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color iconColor = isDarkMode ? const Color(0xFF4A4A4A) : Colors.grey
        .shade600;
    final Color keepSessionBgColor = isDarkMode
        ? const Color(0xFF2A2A2A)
        : Colors.grey.shade100;
    final Color keepSessionTextColor = isDarkMode ? Colors.white70 : Colors
        .black87;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dialogBgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// 🔴 Icon + Title Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(isDarkMode ? 0.2 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.red,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    "Active Session Detected",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// 🧠 Subtitle
            Text(
              "You're already logged in on another device. Review the details below.",
              style: TextStyle(
                fontSize: 13,
                color: subtitleColor,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            /// 📦 Device Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorderColor),
              ),
              child: Column(
                children: [
                  _infoTile(Icons.android, "OS", deviceInfo['brand'], iconColor,
                      isDarkMode),
                  _divider(isDarkMode, cardBorderColor),
                  _infoTile(Icons.phone_iphone, "Device", deviceInfo['device'],
                      iconColor, isDarkMode),
                  _divider(isDarkMode, cardBorderColor),
                  _infoTile(
                      Icons.memory, "Model", deviceInfo['model'], iconColor,
                      isDarkMode),
                  _divider(isDarkMode, cardBorderColor),
                  _infoTile(Icons.system_update, "Version",
                      deviceInfo['androidVersion'], iconColor, isDarkMode),
                ],
              ),
            ),

            const SizedBox(height: 22),

            /// 🎯 Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onRejectDevice,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: keepSessionBgColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      "Keep Session",
                      style: TextStyle(color: keepSessionTextColor),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmDevice,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Logout Device",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, dynamic value, Color iconColor,
      bool isDarkMode) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Text(
          "$title:",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value?.toString() ?? "Unknown",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider(bool isDarkMode, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: borderColor, height: 1),
    );
  }
}