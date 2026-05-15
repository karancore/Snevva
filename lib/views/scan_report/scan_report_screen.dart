import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/scan_report/captured_image_preview.dart';

class ScanReportScreen extends StatefulWidget {
  const ScanReportScreen({super.key});

  @override
  State<ScanReportScreen> createState() => _ScanReportScreenState();
}

class _ScanReportScreenState extends State<ScanReportScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isFlashOn = false;
  bool _cameraReady = false;

  bool _isCapturing = false;
  XFile? _capturedImage;

  XFile? _pickedImage;

  // Animation for the green scan line
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initScanAnimation();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    _controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _initScanAnimation() {
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _isFlashOn = !_isFlashOn);
    await _controller!.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  Future<void> _captureImage() async {
    // Guard clauses
    if (_controller == null) return;
    if (!_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return; // prevent double tap
    if (_isCapturing) return;

    try {
      setState(() => _isCapturing = true);

      // Optional: set flash mode before capture
      await _controller!.setFlashMode(
        _isFlashOn ? FlashMode.always : FlashMode.off,
      );

      // Take the picture
      final XFile image = await _controller!.takePicture();

      // Save to a permanent location (temp dir by default is fine for processing)
      final String fileName =
          'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String savedPath = path.join(appDir.path, fileName);

      // Copy to permanent path
      final File savedImage = await File(image.path).copy(savedPath);

      setState(() {
        _capturedImage = XFile(savedImage.path);
        _isCapturing = false;
      });

      debugPrint('Image saved at: ${savedImage.path}');

      // Navigate to preview screen after capture
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CapturedImagePreview(imagePath: savedImage.path),
          ),
        );
      }
    } on CameraException catch (e) {
      setState(() => _isCapturing = false);
      debugPrint('Camera error: ${e.code} - ${e.description}');
      _showErrorSnackbar('Camera error: ${e.description}');
    } catch (e) {
      setState(() => _isCapturing = false);
      debugPrint('Unexpected error: $e');
      _showErrorSnackbar('Something went wrong. Try again.');
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickFromGallery() async {
    // Bottom sheet show karo — Gallery ya File Manager choose karne k liye
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.secondaryColor,
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Images only'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.folder_outlined,
                    color: AppColors.secondaryColor,
                  ),
                  title: const Text('File Manager'),
                  subtitle: const Text('Images & PDFs'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickFile();
                  },
                ),
              ],
            ),
          ),
    );
  }

  // ── Gallery se image pick karo ──
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1920,
      maxHeight: 1080,
    );

    if (image == null) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CapturedImagePreview(imagePath: image.path),
        ),
      );
    }
  }

  // ── File manager se image ya PDF pick karo ──
  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
    );

    if (result == null) return; // user cancelled

    final PlatformFile file = result.files.single;
    final String? filePath = file.path;

    if (filePath == null) return;

    debugPrint('Picked file: $filePath, type: ${file.extension}');

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CapturedImagePreview(imagePath: filePath),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,

        backgroundColor: Colors.grey[200],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan your report',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Green scan line indicator ──
          Container(height: 3, color: AppColors.secondaryColor),

          // ── Camera viewfinder ──
          Expanded(
            child:
                _cameraReady && _controller != null
                    ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        // Animated scan line overlay
                        AnimatedBuilder(
                          animation: _scanLineAnimation,
                          builder: (context, child) {
                            return Positioned(
                              top:
                                  _scanLineAnimation.value *
                                  MediaQuery.of(context).size.height *
                                  0.6,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 2,
                                color: Colors.green.withOpacity(0.8),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                    : Container(color: Colors.grey[300]), // placeholder
          ),

          // ── Bottom controls ──
          Container(
            color: Colors.grey[300],
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flash toggle
                _CircleIconButton(
                  icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                  onTap: _toggleFlash,
                ),

                // Capture button
                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _captureImage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isCapturing ? 60 : 72,
                    height: _isCapturing ? 60 : 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color:
                            _isCapturing
                                ? AppColors.secondaryColor
                                : Colors.white,
                        width: 3,
                      ),
                    ),
                    child:
                        _isCapturing
                            ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.secondaryColor,
                              ),
                            )
                            : null,
                  ),
                ),

                // Gallery picker
                _CircleIconButton(
                  icon: Icons.photo_library_outlined,
                  onTap: _pickFromGallery,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable small circle button ──
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[400],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
