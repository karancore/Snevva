import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../Controllers/ReportScan/scan_report_controller.dart';
import '../../consts/colors.dart';

// ─────────────────────────────────────────────
// DUMMY DATA — replace with real API call later
// ─────────────────────────────────────────────
const String _dummyApiContent = '''
{
  "overall_health_score": 70,
  "overall_status": "Needs Attention",
  "doctor_consultation_recommended": true,
  "emergency_attention_needed": false,
  "key_findings": [
    "Uric Acid borderline high",
    "Triglycerides high",
    "Low HDL Cholesterol",
    "Globulin borderline high",
    "GFR mildly reduced"
  ],
  "parameters": [
    {
      "test_name": "Urea",
      "value": "19",
      "unit": "mg/dl",
      "reference_range": "13 - 43",
      "status": "NORMAL",
      "severity_score": 15,
      "status_color": "green",
      "hex_code": "#22C55E",
      "clinical_meaning": "Normal urea levels indicate good kidney function.",
      "possible_causes": [],
      "recommended_actions": [],
      "diet_recommendations": [],
      "exercise_recommendations": []
    },
    {
      "test_name": "Creatinine",
      "value": "1.12",
      "unit": "mg/dl",
      "reference_range": "0.7 - 1.3",
      "status": "NORMAL",
      "severity_score": 15,
      "status_color": "green",
      "hex_code": "#22C55E",
      "clinical_meaning": "Normal creatinine levels indicate healthy kidney function.",
      "possible_causes": [],
      "recommended_actions": [],
      "diet_recommendations": [],
      "exercise_recommendations": []
    },
    {
      "test_name": "Uric Acid",
      "value": "7",
      "unit": "mg/dl",
      "reference_range": "3.6 - 7.0",
      "status": "HIGH",
      "severity_score": 61,
      "status_color": "orange",
      "hex_code": "#F97316",
      "clinical_meaning": "Slightly elevated uric acid may indicate risk of gout.",
      "possible_causes": ["Diet high in purines", "Dehydration", "Kidney dysfunction"],
      "recommended_actions": ["Reduce purine-rich foods like red meat and seafood.", "Stay well-hydrated."],
      "diet_recommendations": ["Increase water intake", "Limit red meat and shellfish"],
      "exercise_recommendations": ["Walking", "Moderate aerobic exercise"]
    },
    {
      "test_name": "Estimated GFR",
      "value": "80",
      "unit": "mL/min/1.73 m2",
      "reference_range": "> 90",
      "status": "LOW",
      "severity_score": 41,
      "status_color": "orange",
      "hex_code": "#F97316",
      "clinical_meaning": "Mildly reduced kidney function.",
      "possible_causes": ["Chronic kidney disease", "Dehydration", "Age-related changes"],
      "recommended_actions": ["Follow up with more tests", "Monitor kidney function regularly"],
      "diet_recommendations": ["Eat a balanced diet", "Limit sodium intake"],
      "exercise_recommendations": ["Gentle activities like yoga", "Avoid excessive high-impact exercises"]
    },
    {
      "test_name": "Total Cholesterol",
      "value": "172",
      "unit": "mg/dl",
      "reference_range": "140 - 200",
      "status": "NORMAL",
      "severity_score": 15,
      "status_color": "green",
      "hex_code": "#22C55E",
      "clinical_meaning": "Normal cholesterol levels are good for heart health.",
      "possible_causes": [],
      "recommended_actions": [],
      "diet_recommendations": [],
      "exercise_recommendations": []
    },
    {
      "test_name": "Triglycerides",
      "value": "222",
      "unit": "mg/dl",
      "reference_range": "< 150",
      "status": "HIGH",
      "severity_score": 67,
      "status_color": "orange",
      "hex_code": "#F97316",
      "clinical_meaning": "High triglycerides can increase heart disease risk.",
      "possible_causes": ["Obesity", "Lack of physical activity", "High-carb diet"],
      "recommended_actions": ["Improve diet", "Increase physical activity"],
      "diet_recommendations": ["Reduce sugar intake", "Increase omega-3 fatty acids"],
      "exercise_recommendations": ["At least 150 minutes of moderate exercise per week"]
    },
    {
      "test_name": "HDL Cholesterol",
      "value": "32.7",
      "unit": "mg/dl",
      "reference_range": "35.2 - 79.5",
      "status": "LOW",
      "severity_score": 61,
      "status_color": "orange",
      "hex_code": "#F97316",
      "clinical_meaning": "Low HDL is associated with increased heart disease risk.",
      "possible_causes": ["Unhealthy diet", "Sedentary lifestyle", "Smoking"],
      "recommended_actions": ["Increase healthy fats", "Regular aerobic activity"],
      "diet_recommendations": ["Include avocados, nuts, and olive oil"],
      "exercise_recommendations": ["30 min brisk walk daily", "Cycling or swimming"]
    }
  ]
}
''';

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class ReportParameter {
  final String testName;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;
  final int severityScore;
  final String hexCode;
  final String clinicalMeaning;
  final List<String> possibleCauses;
  final List<String> recommendedActions;
  final List<String> dietRecommendations;
  final List<String> exerciseRecommendations;

  ReportParameter.fromJson(Map<String, dynamic> j)
      : testName = j['test_name'] ?? '',
        value = j['value'] ?? '',
        unit = j['unit'] ?? '',
        referenceRange = j['reference_range'] ?? '',
        status = j['status'] ?? '',
        severityScore = j['severity_score'] ?? 0,
        hexCode = j['hex_code'] ?? '#22C55E',
        clinicalMeaning = j['clinical_meaning'] ?? '',
        possibleCauses = List<String>.from(j['possible_causes'] ?? []),
        recommendedActions = List<String>.from(j['recommended_actions'] ?? []),
        dietRecommendations =
            List<String>.from(j['diet_recommendations'] ?? []),
        exerciseRecommendations =
            List<String>.from(j['exercise_recommendations'] ?? []);

  Color get statusColor {
    try {
      final hex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class HealthReport {
  final int overallHealthScore;
  final String overallStatus;
  final bool doctorConsultationRecommended;
  final bool emergencyAttentionNeeded;
  final List<String> keyFindings;
  final List<ReportParameter> parameters;

  HealthReport.fromJson(Map<String, dynamic> j)
      : overallHealthScore = j['overall_health_score'] ?? 0,
        overallStatus = j['overall_status'] ?? '',
        doctorConsultationRecommended =
            j['doctor_consultation_recommended'] ?? false,
        emergencyAttentionNeeded = j['emergency_attention_needed'] ?? false,
        keyFindings = List<String>.from(j['key_findings'] ?? []),
        parameters = (j['parameters'] as List? ?? [])
            .map((e) => ReportParameter.fromJson(e))
            .toList();
}

// ─────────────────────────────────────────────
// MAIN SCREEN
// Two modes:
//   1. Fresh scan  → pass file + fileName + mimeType (historyContent = null)
//   2. History view → pass historyContent JSON string only (file params ignored)
// ─────────────────────────────────────────────
class ReportDetailsScreen extends StatefulWidget {
  final File? file;
  final String? fileName;
  final String? mimeType;
  final String? historyContent;
  final String? historyTitle;

  const ReportDetailsScreen({
    super.key,
    this.file,
    this.fileName,
    this.mimeType,
    this.historyContent,
    this.historyTitle,
  }) : assert(
          historyContent != null ||
              (file != null && fileName != null && mimeType != null),
          'Provide either historyContent (history mode) or file+fileName+mimeType (scan mode)',
        );

  const ReportDetailsScreen.fromHistory({
    super.key,
    required String content,
    required String title,
  })  : historyContent = content,
        historyTitle = title,
        file = null,
        fileName = null,
        mimeType = null;

  bool get isHistoryMode => historyContent != null;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final ScanReportController _controller = Get.find<ScanReportController>();
  bool _isUploading = false;
  String? _errorMessage;
  HealthReport? _report;

  bool get _isPdf => widget.mimeType == 'application/pdf';

  @override
  void initState() {
    super.initState();
    if (widget.isHistoryMode) {
      _parseContent(widget.historyContent!);
    }
  }

  void _parseContent(String contentJson) {
    try {
      final decoded = jsonDecode(contentJson);
      setState(() => _report = HealthReport.fromJson(decoded));
    } catch (e) {
      setState(() => _errorMessage = 'Failed to parse report: $e');
    }
  }

  Future<void> _uploadFile() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _report = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      final contentJson = jsonDecode(_dummyApiContent);
      final report = HealthReport.fromJson(contentJson);

      await _controller.addToHistory(
        title: widget.fileName!,
        content: _dummyApiContent,
      );

      setState(() => _report = report);
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? scaffoldColorDark : scaffoldColorLight;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final String appBarTitle = widget.isHistoryMode
        ? (widget.historyTitle ?? 'Report Details')
        : 'Report Details';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          appBarTitle,
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: widget.isHistoryMode
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.secondaryColor.withOpacity(0.5)),
                  ),
                  child: Text(
                    'History',
                    style: TextStyle(
                      color: AppColors.secondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _errorMessage != null && _report == null
          ? _ErrorView(message: _errorMessage!)
          : _report != null
              ? _ReportResultView(
                  report: _report!, isHistoryMode: widget.isHistoryMode)
              : widget.isHistoryMode
                  ? const Center(child: CircularProgressIndicator())
                  : _FilePreviewView(
                      file: widget.file!,
                      fileName: widget.fileName!,
                      mimeType: widget.mimeType!,
                      isPdf: _isPdf,
                      isUploading: _isUploading,
                      errorMessage: _errorMessage,
                      onRetake: () => Navigator.pop(context),
                      onAnalyze: _uploadFile,
                    ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILE PREVIEW (before upload)
// ─────────────────────────────────────────────
class _FilePreviewView extends StatelessWidget {
  final File file;
  final String fileName;
  final String mimeType;
  final bool isPdf;
  final bool isUploading;
  final String? errorMessage;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;

  const _FilePreviewView({
    required this.file,
    required this.fileName,
    required this.mimeType,
    required this.isPdf,
    required this.isUploading,
    required this.errorMessage,
    required this.onRetake,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    final Color labelColor = isDark ? Colors.grey : Colors.grey[600]!;
    final Color valueColor = isDark ? Colors.white : Colors.black87;
    final Color borderColor = isDark ? Colors.white : Colors.black87;

    return Column(
      children: [
        Expanded(
          child: isPdf
              ? _PdfPreview(fileName: fileName)
              : Image.file(file, fit: BoxFit.contain),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: Icons.insert_drive_file_outlined,
                label: 'File Name',
                value: fileName,
                labelColor: labelColor,
                valueColor: valueColor,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.category_outlined,
                label: 'Type',
                value: mimeType,
                labelColor: labelColor,
                valueColor: valueColor,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.storage_outlined,
                label: 'Size',
                value: '${(file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                labelColor: labelColor,
                valueColor: valueColor,
              ),
            ],
          ),
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: isUploading ? null : onRetake,
                  child: Text(
                    'Retake',
                    style: TextStyle(color: valueColor),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isUploading ? null : onAnalyze,
                    child: isUploading
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// REPORT RESULT VIEW (after upload / from history)
// ─────────────────────────────────────────────
class _ReportResultView extends StatelessWidget {
  final HealthReport report;
  final bool isHistoryMode;

  const _ReportResultView({
    required this.report,
    this.isHistoryMode = false,
  });

  Color get _scoreColor {
    final s = report.overallHealthScore;
    if (s >= 80) return const Color(0xFF22C55E);
    if (s >= 50) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScoreCard(report: report, scoreColor: _scoreColor),
          const SizedBox(height: 16),

          if (report.emergencyAttentionNeeded)
            _AlertBanner(
              icon: Icons.emergency,
              color: const Color(0xFFEF4444),
              text: 'Emergency attention needed — visit a doctor immediately.',
            ),
          if (report.doctorConsultationRecommended)
            _AlertBanner(
              icon: Icons.medical_services_outlined,
              color: const Color(0xFFF97316),
              text: 'Doctor consultation recommended based on your results.',
            ),
          if (report.doctorConsultationRecommended ||
              report.emergencyAttentionNeeded)
            const SizedBox(height: 16),

          if (report.keyFindings.isNotEmpty) ...[
            const _SectionTitle(
                title: 'Key Findings', icon: Icons.flag_outlined),
            const SizedBox(height: 8),
            ...report.keyFindings.map((f) => _FindingChip(text: f)),
            const SizedBox(height: 20),
          ],

          const _SectionTitle(
              title: 'Test Parameters', icon: Icons.biotech_outlined),
          const SizedBox(height: 8),
          ...report.parameters.map((p) => _ParameterCard(param: p)),
          const SizedBox(height: 24),

          // Done / Back button — gradient matches rest of app
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => isHistoryMode
                  ? Navigator.pop(context)
                  : Navigator.popUntil(context, (route) => route.isFirst),
              child: Text(
                isHistoryMode ? 'Back' : 'Done',
                style:
                    const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE CARD
// ─────────────────────────────────────────────
class _ScoreCard extends StatelessWidget {
  final HealthReport report;
  final Color scoreColor;

  const _ScoreCard({required this.report, required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color progressBg = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Overall Health Score',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: report.overallHealthScore / 100,
                  strokeWidth: 9,
                  backgroundColor: progressBg,
                  valueColor: AlwaysStoppedAnimation(scoreColor),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${report.overallHealthScore}',
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/ 100',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scoreColor.withOpacity(0.4)),
            ),
            child: Text(
              report.overallStatus,
              style: TextStyle(
                color: scoreColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _AlertBanner(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION TITLE
// ─────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, color: AppColors.secondaryColor, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FINDING CHIP
// ─────────────────────────────────────────────
class _FindingChip extends StatelessWidget {
  final String text;

  const _FindingChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, color: Color(0xFFF97316), size: 7),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PARAMETER CARD (expandable)
// ─────────────────────────────────────────────
class _ParameterCard extends StatefulWidget {
  final ReportParameter param;

  const _ParameterCard({required this.param});

  @override
  State<_ParameterCard> createState() => _ParameterCardState();
}

class _ParameterCardState extends State<_ParameterCard> {
  bool _expanded = false;

  bool get _hasDetails =>
      widget.param.possibleCauses.isNotEmpty ||
      widget.param.recommendedActions.isNotEmpty ||
      widget.param.dietRecommendations.isNotEmpty ||
      widget.param.exerciseRecommendations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? Colors.grey[900]! : Colors.white;
    final Color titleColor = isDark ? Colors.white : Colors.black87;
    final Color dividerColor = isDark ? Colors.white12 : Colors.black12;
    final p = widget.param;
    final color = p.statusColor;

    return GestureDetector(
      onTap: _hasDetails ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.testName,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p.value} ${p.unit}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Ref: ${p.referenceRange}',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_hasDetails) ...[
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey,
                      size: 18,
                    ),
                  ],
                ],
              ),
            ),

            if (p.clinicalMeaning.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(34, 0, 14, 12),
                child: Text(
                  p.clinicalMeaning,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),

            if (_expanded && _hasDetails)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: dividerColor, height: 16),
                    if (p.possibleCauses.isNotEmpty)
                      _DetailSection(
                        icon: Icons.help_outline,
                        title: 'Possible Causes',
                        items: p.possibleCauses,
                        color: const Color(0xFFF97316),
                      ),
                    if (p.recommendedActions.isNotEmpty)
                      _DetailSection(
                        icon: Icons.check_circle_outline,
                        title: 'Recommended Actions',
                        items: p.recommendedActions,
                        color: const Color(0xFF22C55E),
                      ),
                    if (p.dietRecommendations.isNotEmpty)
                      _DetailSection(
                        icon: Icons.restaurant_outlined,
                        title: 'Diet',
                        items: p.dietRecommendations,
                        color: const Color(0xFF3B82F6),
                      ),
                    if (p.exerciseRecommendations.isNotEmpty)
                      _DetailSection(
                        icon: Icons.fitness_center_outlined,
                        title: 'Exercise',
                        items: p.exerciseRecommendations,
                        color: const Color(0xFFA855F7),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DETAIL SECTION
// ─────────────────────────────────────────────
class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final Color color;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color itemColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: color, fontSize: 12)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(color: itemColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: labelColor, size: 18),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(color: labelColor, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PdfPreview extends StatelessWidget {
  final String fileName;

  const _PdfPreview({required this.fileName});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.picture_as_pdf, size: 100, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'PDF ready to analyze',
            style: TextStyle(
              color: isDark ? Colors.grey : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}