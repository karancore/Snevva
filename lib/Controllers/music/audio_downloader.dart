import 'dart:io';
import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../consts/consts.dart';

class AudioDownloader {
  static Future<String?> downloadAudio({
    required String url,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint("📥 Download started");
      debugPrint("🔗 URL: $url");
      debugPrint("📄 File name: $fileName");

      // 🔍 Android version check
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final sdkInt = androidInfo.version.sdkInt;

        debugPrint("📱 Android SDK: $sdkInt");

        if (sdkInt <= 32) {
          debugPrint("🔐 Requesting storage permission...");
          final permission = await Permission.storage.request();
          debugPrint("🔐 Permission status: $permission");

          if (!permission.isGranted) {
            debugPrint("❌ Storage permission denied");
            return null;
          }
        } else {
          debugPrint("✅ Android 13+ → no storage permission needed");
        }
      }

      // 📂 Downloads directory
      final Directory? downloadsDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      if (downloadsDir == null || !downloadsDir.existsSync()) {
        debugPrint("❌ Downloads directory not found");
        return null;
      }

      final filePath = '${downloadsDir.path}/$fileName.mp3';
      debugPrint("📁 Saving to: $filePath");

      final dio = Dio();

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            debugPrint(
              "⬇️ Download progress: ${(progress * 100).toStringAsFixed(1)}%",
            );
            onProgress(progress);
          }
        },
      );

      debugPrint("✅ Download completed successfully");
      return filePath;
    } catch (e, s) {
      debugPrint("❌ Download error: $e");
      debugPrint("📍 Stacktrace: $s");
      return null;
    }
  }
}
