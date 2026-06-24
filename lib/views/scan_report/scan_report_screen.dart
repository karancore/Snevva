import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:pdfx/pdfx.dart';
import 'package:snevva/Controllers/ReportScan/scan_report_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/scan_report/report_details_screen.dart';

import '../../Widgets/Drawer/drawer_menu_wigdet.dart';

class ScanReportScreen extends StatefulWidget {
  const ScanReportScreen({super.key});

  @override
  State<ScanReportScreen> createState() => _ScanReportScreenState();
}

class _ScanReportScreenState extends State<ScanReportScreen> {
  String? _pdfPath;

  Future<void> _pickPdf({required bool isDarkMode}) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result == null) return;

    final PlatformFile pickedFile = result.files.single;

    final String? path = pickedFile.path;

    if (path == null) return;

    // 5 MB validation
    const int maxSizeInBytes = 5 * 1024 * 1024;

    if (pickedFile.size > maxSizeInBytes) {
      if (!mounted) return;

      Get.snackbar(
        'Aye! Mate',
        'PDF size should be less than 5 MB',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.primaryColor,
        colorText: isDarkMode ? white : black,

        duration: const Duration(seconds: 3),
      );

      return;
    }

    setState(() {
      _pdfPath = path;
    });
  }

  Future<void> _useFile() async {
    if (_pdfPath == null) {
      debugPrint("_pdfPath is null");
      return;
    }

    debugPrint("Starting upload...");
    debugPrint("PDF Path: $_pdfPath");

    final bool isUploaded = await Get.find<ScanReportController>()
        .sendReportToServer(
          pdfPath: _pdfPath,
          isOwnPdf: _isOwnPdf,
          selectedGender: _selectedGender,
          ageController: _ageController,
      nameController: _nameController,
        );

    debugPrint("Upload Result: $isUploaded");

    // Stop navigation if upload failed
    if (!isUploaded) {
      debugPrint("Navigation stopped because upload failed");

      Get.snackbar(
        'Upload Failed',
        'Could not upload report',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: white,
      );

      return;
    }

    debugPrint("Upload successful, preparing navigation...");

    final file = File(_pdfPath!);

    debugPrint("File Exists: ${file.existsSync()}");

    final mimeType = lookupMimeType(_pdfPath!) ?? 'application/pdf';

    debugPrint("MimeType: $mimeType");

    final fileName = _pdfPath!.split('/').last;

    debugPrint("FileName: $fileName");

    debugPrint("Navigating to ReportDetailsScreen");

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
  }

  String? _selectedGender;
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();


  bool _isOwnPdf = true;

  void _showOwnershipBottomSheet({required bool isDark}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,

      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),

              decoration: BoxDecoration(
                color: isDark ? darkGray : white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,

                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Is this your report?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _isOwnPdf = true;
                              _selectedGender = null;
                              _nameController.clear();
                              _ageController.clear();
                            });
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),

                            decoration: BoxDecoration(
                              gradient:
                                  _isOwnPdf ? AppColors.primaryGradient : null,

                              color: _isOwnPdf ? null : (isDark ? Colors.grey
                                  .shade800 : Colors.grey.shade100),

                              borderRadius: BorderRadius.circular(18),
                            ),

                            child: Center(
                              child: Text(
                                'Yes',

                                style: TextStyle(
                                  color: _isOwnPdf
                                      ? white
                                      : (isDark ? white : black),

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setModalState(() {
                              _isOwnPdf = false;
                            });
                          },

                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),

                            decoration: BoxDecoration(
                              gradient:
                                  !_isOwnPdf ? AppColors.primaryGradient : null,

                              color: !_isOwnPdf ? null : (isDark ? Colors.grey
                                  .shade800 : Colors.grey.shade100),

                              borderRadius: BorderRadius.circular(18),
                            ),

                            child: Center(
                              child: Text(
                                'No',

                                style: TextStyle(
                                  color: !_isOwnPdf
                                      ? white
                                      : (isDark ? white : black),

                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),



                  if (!_isOwnPdf) ...[
                    Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _nameController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? white : black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter name',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark ? darkGray : Colors.grey.shade100,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Gender',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        _genderChip(
                          label: 'Male',
                          setModalState: setModalState,
                          isDark: isDark
                        ),

                        const SizedBox(width: 10),

                        _genderChip(
                          label: 'Female',
                          setModalState: setModalState,
                            isDark: isDark
                        ),

                        const SizedBox(width: 10),

                        _genderChip(
                          label: 'Other',
                          setModalState: setModalState,
                            isDark: isDark
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Age',
                      style: TextStyle(fontWeight: FontWeight.w600 ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        color: isDark ? white : black,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter age',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark ? darkGray : Colors.grey.shade100,

                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 58,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      onPressed: () {
                        if (!_isOwnPdf) {
                          if (_selectedGender == null ||
                              _ageController.text
                                  .trim()
                                  .isEmpty ||
                              _nameController.text
                                  .trim()
                                  .isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter name , gender and age'),
                              ),
                            );

                            return;
                          }
                        }

                        Navigator.pop(context);

                        _useFile();
                      },

                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _genderChip({
    required String label,
    required StateSetter setModalState,
    required bool isDark,
  }) {
    final bool isSelected = _selectedGender == label;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setModalState(() {
            _selectedGender = label;
          });
        },

        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),

          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,

            color: isSelected ? null : (isDark ? Colors.grey.shade800 : Colors
                .grey.shade100),

            borderRadius: BorderRadius.circular(16),
          ),

          child: Center(
            child: Text(
              label,

              style: TextStyle(
                color: isSelected
                    ? white
                    : (isDark ? white : black),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? scaffoldColorDark : scaffoldColorLight;
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    return Scaffold(
      backgroundColor: bg,

      appBar: CustomAppBar(appbarText: 'Upload Report'),
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      bottomNavigationBar:
          _pdfPath != null
              ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  color: bg,

                  child: SizedBox(
                    height: 58,

                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),

                      onPressed:
                          () => _showOwnershipBottomSheet(isDark: isDark),

                      child: const Text(
                        'Use File',
                        style: TextStyle(
                          color: white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              : null,

      body:
          _pdfPath == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),

                  child: GestureDetector(
                    onTap: () => _pickPdf(isDarkMode: isDark),

                    child: Container(
                      width: double.infinity,

                      padding: const EdgeInsets.symmetric(
                        vertical: 50,
                        horizontal: 24,
                      ),

                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1A1A) : white,

                        borderRadius: BorderRadius.circular(28),

                        border: Border.all(
                          color: AppColors.secondaryColor.withOpacity(0.3),
                          width: 2,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),

                      child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Container(
                    height: 90,
                    width: 90,

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),

                            child: const Icon(
                              Icons.picture_as_pdf_rounded,
                              color: white,

                              size: 42,
                            ),
                          ),

                          const SizedBox(height: 28),

                          Text(
                            'Upload Your PDF',
                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark ? white : black,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'Choose a PDF report from your phone and preview it instantly.',
                            textAlign: TextAlign.center,

                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color:
                                  isDark
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                            ),
                          ),

                          const SizedBox(height: 30),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),

                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),

                            child: const Row(
                              mainAxisSize: MainAxisSize.min,

                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  color: white,
                                ),

                                SizedBox(width: 10),

                                Text(
                                  'Choose PDF',
                                  style: TextStyle(
                                    color: white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              : Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),

                    padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),

                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A1A) : AppColors
                          .primaryColor.withOpacity(0.1),

                      borderRadius: BorderRadius.circular(18),
                    ),

                    child: Row(
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Text(
                            File(_pdfPath!).path.split('/').last,

                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontWeight: FontWeight.w600,

                              color: isDark ? white : black,
                            ),
                          ),
                        ),

                        TextButton(
                          onPressed: () => _pickPdf(isDarkMode: isDark),

                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),

                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),

                        child: PdfView(
                          controller: PdfController(
                            document: PdfDocument.openFile(_pdfPath!),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
    );
  }
}
