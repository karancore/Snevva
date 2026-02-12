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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔰 Title with Active Device Indicator
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.phone_android,
                      size: 28,
                      color: Colors.black87,
                    ),

                    /// 🟢 Active session dot
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Text(
                  "Active Login Detected",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 14),

            _infoRow("OS", deviceInfo['brand'] ?? 'Unknown'),
            _infoRow("Device", deviceInfo['device'] ?? 'Unknown'),
            _infoRow("Model", deviceInfo['model'] ?? 'Unknown'),
            _infoRow("Version", deviceInfo['androidVersion'] ?? 'Unknown'),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRejectDevice,
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmDevice,
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(flex: 5, child: Text(value)),
        ],
      ),
    );
  }
}
