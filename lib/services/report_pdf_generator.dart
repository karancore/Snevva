import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/health_report.dart';

class ReportPdfGenerator {
  static Future<File> generate({
    required HealthReport report,
    required String title,
    Directory? customDirectory,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => _buildHeader(title),
        footer:
            (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ),
        build:
            (context) => [
              _buildScoreSection(report),
              if (report.emergencyAttentionNeeded ||
                  report.doctorConsultationRecommended)
                _buildAlerts(report),
              if (report.keyFindings.isNotEmpty)
                _buildSection(
                  title: 'Key Findings',
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children:
                        report.keyFindings
                            .map((f) => _buildBulletLine(f, PdfColors.orange))
                            .toList(),
                  ),
                ),
              if (report.topConcerns.isNotEmpty) _buildTopConcerns(report),
              if (report.overallDietPlan.isNotEmpty)
                _buildSection(
                  title: 'Overall Diet Plan',
                  child: _buildPlanList(report.overallDietPlan, PdfColors.blue),
                ),
              if (report.overallExercisePlan.isNotEmpty)
                _buildSection(
                  title: 'Overall Exercise Plan',
                  child: _buildPlanList(
                    report.overallExercisePlan,
                    PdfColors.purple,
                  ),
                ),
              if (report.recommendations.isNotEmpty)
                _buildSection(
                  title: 'Recommendations',
                  child: _buildPlanList(
                    report.recommendations,
                    PdfColors.green,
                  ),
                ),
              // Section header for parameters — kept separate from the rows
              // so that each row is a direct MultiPage child and can be
              // page-broken individually.
              _buildSectionHeader('Test Parameters'),
              ...report.parameters.map(_buildParameterRow),
              if (report.aiDisclaimer.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    report.aiDisclaimer,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ],
      ),
    );

    final bytes = await pdf.save();
    final dir = customDirectory ?? await getTemporaryDirectory();
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '_');

    String filename = '$safeTitle.pdf';
    File file = File('${dir.path}/$filename');
    int count = 1;
    while (await file.exists()) {
      filename = '${safeTitle}_$count.pdf';
      file = File('${dir.path}/$filename');
      count++;
    }

    await file.writeAsBytes(bytes);
    return file;
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated: ${DateTime.now().toLocal().toString().split('.').first}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildScoreSection(HealthReport report) {
    final color =
        report.overallHealthScore >= 80
            ? PdfColors.green
            : report.overallHealthScore >= 50
            ? PdfColors.orange
            : PdfColors.red;
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Overall Health Score',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${report.overallHealthScore} / 100',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: color,
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Text(
              report.overallStatus,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAlerts(HealthReport report) {
    final banners = <pw.Widget>[];
    if (report.emergencyAttentionNeeded) {
      banners.add(
        _alertBanner(
          'Emergency attention needed — visit a doctor immediately.',
          PdfColors.red,
        ),
      );
    }
    if (report.doctorConsultationRecommended) {
      banners.add(
        _alertBanner(
          'Doctor consultation recommended based on your results.',
          PdfColors.orange,
        ),
      );
    }
    return pw.Column(children: [pw.SizedBox(height: 8), ...banners]);
  }

  static pw.Widget _alertBanner(String text, PdfColor color) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: color)),
    );
  }

  static pw.Widget _buildBulletLine(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 3, right: 6),
            width: 4,
            height: 4,
            decoration: pw.BoxDecoration(
              color: color,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.Expanded(
            child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSection({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  /// Lightweight header widget used when the section body is spread across
  /// multiple top-level MultiPage children (e.g., the parameters list).
  static pw.Widget _buildSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTopConcerns(HealthReport report) {
    return _buildSection(
      title: 'Top Concerns',
      child: pw.Column(
        children:
            report.topConcerns.map((c) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 16,
                      height: 16,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Text(
                        '${c.rank}',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            c.parameter,
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            c.message,
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  static pw.Widget _buildPlanList(List<String> items, PdfColor color) {
    return pw.Column(
      children: items.map((i) => _buildBulletLine(i, color)).toList(),
    );
  }

  static pw.Widget _buildParameterRow(ReportParameter p) {
    final color = _hexToPdfColor(p.hexCode);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  p.testName,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                '${p.value} ${p.unit}',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  p.status,
                  style: pw.TextStyle(fontSize: 7, color: PdfColors.white),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Ref: ${p.referenceRange}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          if (p.clinicalMeaning.isNotEmpty)
            pw.Text(
              p.clinicalMeaning,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    );
  }

  static PdfColor _hexToPdfColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return PdfColor.fromInt(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return PdfColors.grey;
    }
  }
}
