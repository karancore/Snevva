import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../consts/consts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AudioDownloader
//
// Storage strategy (Play policy compliant):
//   • Files are stored in app-private internal storage:
//       getApplicationSupportDirectory()/music/<snevva_*.mp3>
//   • This directory is sandboxed to the app — NO external-storage permissions
//     (READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE, MANAGE_EXTERNAL_STORAGE)
//     are requested or required on any Android API level.
//   • The previous implementation wrote to /storage/emulated/0/Download, which
//     required MANAGE_EXTERNAL_STORAGE on API 30+ — rejected by Google Play policy.
// ─────────────────────────────────────────────────────────────────────────────

class AudioDownloader {
  static const String _downloadRegistryKey = 'snevva_downloaded_music_paths';
  static const String _downloadPathByTrackKey =
      'snevva_downloaded_music_path_by_track';
  static const String _snevvaFilePrefix = 'snevva_';

  // ── Public API ──────────────────────────────────────────────────────────────

  static Future<String?> downloadAudio({
    required String url,
    required String fileName,
    Function(double)? onProgress,
  }) async {
    try {
      debugPrint("📥 Download started");
      debugPrint("🔗 URL: $url");
      debugPrint("📄 File name: $fileName");

      final Directory musicDir = await _resolveMusicDirectory();
      final String safeFileName = _buildSnevvaFileName(fileName);
      final String filePath = await _buildUniqueFilePath(
        musicDir: musicDir,
        fileName: safeFileName,
      );
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
      await _saveDownloadedPath(filePath, trackUrl: url, fileName: fileName);
      return filePath;
    } catch (e, s) {
      debugPrint("❌ Download error: $e");
      debugPrint("📍 Stacktrace: $s");
      return null;
    }
  }

  static Future<String?> getDownloadedPathForTrack({
    required String trackUrl,
    required String fileName,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> pathByTrack = _getPathByTrackMap(prefs);
    final String normalizedUrl = _normalizeTrackUrl(trackUrl);

    final String? mappedPath = pathByTrack[normalizedUrl] as String?;
    if (mappedPath != null && mappedPath.isNotEmpty) {
      final mappedFile = File(mappedPath);
      if (await mappedFile.exists()) {
        return mappedPath;
      }
    }

    final List<String> paths =
        prefs.getStringList(_downloadRegistryKey) ?? <String>[];
    if (paths.isEmpty) {
      return null;
    }

    final String expectedBaseName =
        _buildSnevvaFileName(fileName).toLowerCase();
    for (final path in paths) {
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }

      final String name = file.path.split('/').last.toLowerCase();
      if (!name.endsWith('.mp3')) continue;

      final bool sameTrackName =
          name == '$expectedBaseName.mp3' ||
          name.startsWith('$expectedBaseName (');
      if (!sameTrackName) continue;

      pathByTrack[normalizedUrl] = file.path;
      await prefs.setString(_downloadPathByTrackKey, jsonEncode(pathByTrack));
      return file.path;
    }

    return null;
  }

  static Future<List<File>> getSnevvaDownloadedTracks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<String> candidatePaths =
        prefs.getStringList(_downloadRegistryKey)?.toSet() ?? <String>{};

    // Also scan the music directory to catch any files not yet in prefs
    final Directory musicDir = await _resolveMusicDirectory();
    if (await musicDir.exists()) {
      await for (final entity in musicDir.list(followLinks: false)) {
        if (entity is! File) continue;

        final String name = entity.path.split('/').last.toLowerCase();
        if (name.startsWith(_snevvaFilePrefix) && name.endsWith('.mp3')) {
          candidatePaths.add(entity.path);
        }
      }
    }

    final List<File> files = <File>[];
    for (final path in candidatePaths) {
      final file = File(path);
      if (await file.exists()) {
        files.add(file);
      }
    }

    final List<MapEntry<File, DateTime>> filesByModified =
        <MapEntry<File, DateTime>>[];
    for (final file in files) {
      DateTime modifiedAt;
      try {
        modifiedAt = await file.lastModified();
      } catch (_) {
        modifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
      }
      filesByModified.add(MapEntry<File, DateTime>(file, modifiedAt));
    }

    filesByModified.sort((a, b) => b.value.compareTo(a.value));
    final List<File> sortedFiles = filesByModified
        .map((entry) => entry.key)
        .toList(growable: false);

    await prefs.setStringList(
      _downloadRegistryKey,
      sortedFiles.map((file) => file.path).toList(),
    );

    return sortedFiles;
  }

  static String displayTitleFromPath(String path) {
    String title = path.split('/').last;
    if (title.toLowerCase().startsWith(_snevvaFilePrefix)) {
      title = title.substring(_snevvaFilePrefix.length);
    }
    if (title.toLowerCase().endsWith('.mp3')) {
      title = title.substring(0, title.length - 4);
    }
    return title.replaceAll('_', ' ');
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Returns the app-private music directory.
  /// On Android: <filesDir>/music/  (no storage permission required)
  /// On iOS/desktop: <ApplicationSupportDirectory>/music/
  static Future<Directory> _resolveMusicDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final musicDir = Directory('${appSupport.path}/music');
    if (!await musicDir.exists()) {
      await musicDir.create(recursive: true);
    }
    return musicDir;
  }

  static String _sanitizeFileName(String name) {
    final String cleaned =
        name
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return cleaned.isEmpty ? 'snevva_track' : cleaned;
  }

  static Future<String> _buildUniqueFilePath({
    required Directory musicDir,
    required String fileName,
  }) async {
    String candidate = '${musicDir.path}/$fileName.mp3';
    int index = 1;

    while (await File(candidate).exists()) {
      candidate = '${musicDir.path}/$fileName ($index).mp3';
      index++;
    }

    return candidate;
  }

  static String _buildSnevvaFileName(String rawName) {
    final String sanitized = _sanitizeFileName(rawName).replaceAll(' ', '_');
    if (sanitized.toLowerCase().startsWith(_snevvaFilePrefix)) {
      return sanitized;
    }
    return '$_snevvaFilePrefix$sanitized';
  }

  static Future<void> _saveDownloadedPath(
    String filePath, {
    required String trackUrl,
    required String fileName,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> existing =
        prefs.getStringList(_downloadRegistryKey) ?? <String>[];

    if (!existing.contains(filePath)) {
      existing.insert(0, filePath);
      await prefs.setStringList(_downloadRegistryKey, existing);
    }

    final Map<String, dynamic> pathByTrack = _getPathByTrackMap(prefs);
    final String normalizedTrack = _normalizeTrackUrl(trackUrl);
    pathByTrack[normalizedTrack] = filePath;
    pathByTrack[_buildSnevvaFileName(fileName).toLowerCase()] = filePath;
    await prefs.setString(_downloadPathByTrackKey, jsonEncode(pathByTrack));
  }

  static Map<String, dynamic> _getPathByTrackMap(SharedPreferences prefs) {
    final String? rawMap = prefs.getString(_downloadPathByTrackKey);
    if (rawMap == null || rawMap.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawMap);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static String _normalizeTrackUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('/') || url.startsWith('file://')) return url;
    return url.startsWith('http') ? url : 'https://$url';
  }
}
