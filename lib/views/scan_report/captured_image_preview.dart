import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:mime/mime.dart';
import 'package:snevva/consts/colors.dart';
import 'package:snevva/views/scan_report/report_details_screen.dart';

class CapturedImagePreview extends StatelessWidget {
  final String imagePath;

  const CapturedImagePreview({super.key, required this.imagePath});

  bool get _isPdf => imagePath.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Preview', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child:
                _isPdf
                    ? PDFView(filePath: imagePath) // PDF preview
                    : Image.file(
                      // Image preview
                      File(imagePath),
                      fit: BoxFit.contain,
                    ),
          ),
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
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: () {
                      final file = File(imagePath);
                      final mimeType =
                          lookupMimeType(imagePath) ??
                          'application/octet-stream';
                      final fileName = imagePath.split('/').last;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ReportDetailsScreen(
                                file: file,
                                fileName: fileName,
                                mimeType: mimeType,
                              ),
                        ),
                      );
                    },
                    child: const Text(
                      'Use File',
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

// ── PDF ka placeholder widget ──
class _PdfPlaceholder extends StatelessWidget {
  final String filePath;

  const _PdfPlaceholder({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final String fileName = filePath.split('/').last;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
          const SizedBox(height: 20),
          Text(
            fileName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'PDF ready to upload',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
