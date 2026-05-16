import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:snevva/views/scan_report/report_details_screen.dart';
import 'package:snevva/views/scan_report/scan_report_screen.dart';

import '../../Controllers/ReportScan/scan_report_controller.dart';
import '../../consts/consts.dart';
import '../../models/scan_report_history.dart';

class ScanReportLandingScreen extends StatelessWidget {
  const ScanReportLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ScanReportController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color scaffoldBg = isDark ? scaffoldColorDark : scaffoldColorLight;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final Color backIconColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: backIconColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Scan Report',
          style: TextStyle(
            color: titleColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Obx(() {
        final history = controller.reportHistory;

        return Column(
          children: [
            Expanded(
              child: history.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, color: Colors.grey, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'No scan history yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Tap the button below to get started',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        return _ReportCard(
                          item: item,
                          isDark: isDark,
                          onTap: () => Get.to(
                            () => ReportDetailsScreen.fromHistory(
                              content: item.content,
                              title: item.title,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Pinned footer ─────────────────────────────────────────────
            Container(
              color: scaffoldBg,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Scan New Report button — gradient matches rest of app
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Get.to(() => const ScanReportScreen()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(
                        Icons.document_scanner_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Scan New Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        'Your data is secure and private',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT CARD
// Flutter limitation: borderRadius + non-uniform Border colors crash at paint.
// Fix: wrap in a Stack — outer Container draws rounded bg + shadow + grey border,
// inner Positioned paints the accent bar manually.
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final ScanReportHistory item;
  final VoidCallback onTap;
  final bool isDark;

  const _ReportCard({
    required this.item,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy  •  hh:mm a').format(item.dateTime);

    final Color cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final Color iconBg = isDark ? const Color(0xFF2D1F40) : const Color(0xFFF3E8FF);
    final Color badgeBg = isDark ? const Color(0xFF2D1F40) : const Color(0xFFF3E8FF);
    final Color chevronBg = isDark ? const Color(0xFF2D1F40) : const Color(0xFFF3E8FF);
    final Color chevronBorder = isDark ? const Color(0xFF4A2D70) : const Color(0xFFE0C8FF);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(isDark ? 0.08 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: titleColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scanned on $dateStr',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_outlined,
                                  size: 12,
                                  color: AppColors.primaryColor,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Verified & Secure',
                                  style: TextStyle(
                                    color: AppColors.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: chevronBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: chevronBorder),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primaryColor,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Left accent bar ──
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                child: Container(
                  width: 4,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}