import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controllers/ReportScan/scan_report_controller.dart';
import '../../consts/colors.dart';

class ReportDetailsScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final String mimeType;

  const ReportDetailsScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.mimeType,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final ScanReportController _controller = Get.find<ScanReportController>();
  bool _isUploading = false;
  String? _errorMessage;
  String? _reportContent; // ← API response content yahan store hoga

  bool get _isPdf => widget.mimeType == 'application/pdf';

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _reportContent = null;
    });

    try {
      final result = await _controller.uploadReport(widget.file);

      setState(() {
        _reportContent = result; // ← content string set karo
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Report Details',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body:
          _reportContent != null
              ? _ReportContentView(
                content: _reportContent!,
              ) // ← response aane pr content show karo
              : Column(
                children: [
                  // ── File Preview ──
                  Expanded(
                    child:
                        _isPdf
                            ? _PdfPreview(fileName: widget.fileName)
                            : Image.file(widget.file, fit: BoxFit.contain),
                  ),

                  // ── File Info Card ──
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          icon: Icons.insert_drive_file_outlined,
                          label: 'File Name',
                          value: widget.fileName,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.category_outlined,
                          label: 'Type',
                          value: widget.mimeType,
                        ),
                        const SizedBox(height: 8),
                        _InfoRow(
                          icon: Icons.storage_outlined,
                          label: 'Size',
                          value:
                              '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                        ),
                      ],
                    ),
                  ),

                  // ── Error Message ──
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // ── Action Buttons ──
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed:
                                _isUploading
                                    ? null
                                    : () => Navigator.pop(context),
                            child: const Text(
                              'Retake',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _isUploading ? null : _uploadFile,
                            child:
                                _isUploading
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text(
                                      'Analyze Report',
                                      style: TextStyle(color: Colors.white),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}

// ── Report Content View — API response content yahan dikhega ──
class _ReportContentView extends StatelessWidget {
  final String content;

  const _ReportContentView({required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.grey[900],
          child: const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text(
                'AI Report Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
        ),

        // Done button
        Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed:
                  () => Navigator.popUntil(context, (route) => route.isFirst),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── File info row ──
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── PDF placeholder ──
class _PdfPreview extends StatelessWidget {
  final String fileName;

  const _PdfPreview({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'PDF ready to analyze',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
