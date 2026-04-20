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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    color: Colors.red,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),

                const Expanded(
                  child: Text(
                    "Active Session Detected",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            /// 📦 Device Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _infoTile(Icons.android, "OS", deviceInfo['brand']),
                  _divider(),
                  _infoTile(Icons.phone_iphone, "Device", deviceInfo['device']),
                  _divider(),
                  _infoTile(Icons.memory, "Model", deviceInfo['model']),
                  _divider(),
                  _infoTile(Icons.system_update, "Version",
                      deviceInfo['androidVersion']),
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
                      backgroundColor: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Keep Session",
                      style: TextStyle(color: Colors.black87),
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

  Widget _infoTile(IconData icon, String title, dynamic value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Text(
          "$title:",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value?.toString() ?? "Unknown",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }
}