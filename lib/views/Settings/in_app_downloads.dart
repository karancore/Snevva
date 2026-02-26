import 'dart:io';

import 'package:intl/intl.dart';

import '../../Controllers/music/audio_downloader.dart';
import '../../Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import '../../models/music/music_response.dart';
import '../information/music_player_screen.dart';

class InAppDownloads extends StatefulWidget {
  const InAppDownloads({super.key});

  @override
  State<InAppDownloads> createState() => _InAppDownloadsState();
}

class _InAppDownloadsState extends State<InAppDownloads> {
  late Future<List<_DownloadedTrackInfo>> _downloadsFuture;

  @override
  void initState() {
    super.initState();
    _downloadsFuture = _loadDownloads();
  }

  Future<List<_DownloadedTrackInfo>> _loadDownloads() async {
    final List<File> files = await AudioDownloader.getSnevvaDownloadedTracks();
    return Future.wait<_DownloadedTrackInfo>(
      files.map((file) async {
        int fileSize = 0;
        DateTime modifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
        try {
          fileSize = await file.length();
        } catch (_) {}
        try {
          modifiedAt = await file.lastModified();
        } catch (_) {}
        return _DownloadedTrackInfo(
          file: file,
          title: AudioDownloader.displayTitleFromPath(file.path),
          fileSizeBytes: fileSize,
          lastModifiedAt: modifiedAt,
        );
      }),
    );
  }

  Future<void> _reloadDownloads() async {
    final Future<List<_DownloadedTrackInfo>> nextFuture = _loadDownloads();
    setState(() {
      _downloadsFuture = nextFuture;
    });
    await nextFuture;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: const CustomAppBar(
        appbarText: 'In App Downloads',
        showCloseButton: true,
      ),
      body: RefreshIndicator(
        onRefresh: _reloadDownloads,
        child: FutureBuilder<List<_DownloadedTrackInfo>>(
          future: _downloadsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: height * 0.25),
                  const Center(child: CircularProgressIndicator()),
                ],
              );
            }

            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                  SizedBox(height: 16),
                  Text(
                    'Could not load downloads.\nPull down to try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                ],
              );
            }

            final tracks = snapshot.data ?? <_DownloadedTrackInfo>[];
            if (tracks.isEmpty) {
              return Center(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: const [
                    SizedBox(height: 120),
                    Icon(
                      Icons.library_music_outlined,
                      size: 56,
                      color: mediumGrey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No Snevva downloads yet.\nDownloaded tracks will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: tracks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final subtitle =
                    '${_formatBytes(track.fileSizeBytes)} • ${DateFormat('dd MMM yyyy, hh:mm a').format(track.lastModifiedAt)}';

                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? darkGray : white,
                    borderRadius: BorderRadius.circular(16),

                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryColor.withValues(
                        alpha: 0.12,
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(
                      Icons.download_done_rounded,
                      color: AppColors.primaryColor,
                    ),
                    onTap: () {
                      final localItem = _buildLocalMusicItem(track.file);
                      Get.to(
                        () => MusicPlayerScreen(
                          appBarHeading: 'In App Downloads',
                          appBarSubHeading: '',
                          musicItem: localItem,
                          localFilePath: track.file.path,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  MusicItem _buildLocalMusicItem(File file) {
    final String title = AudioDownloader.displayTitleFromPath(file.path);

    return MusicItem(
      id: 0,
      dataCode: 'local_${file.path.hashCode}',
      title: title,
      artistName: 'Snevva',
      shortDescription: 'Downloaded track',
      tags: const <String>['Downloaded'],
      isActive: true,
      media: Media(
        mediaCode: 'local_media_${file.path.hashCode}',
        title: title,
        contentType: 'audio/mpeg',
        description: 'Local downloaded file',
        originalFilename: file.path.split('/').last,
        cdnUrl: file.path,
        originBucket: 'local',
      ),
      thumbnailMedia: null,
    );
  }
}

class _DownloadedTrackInfo {
  const _DownloadedTrackInfo({
    required this.file,
    required this.title,
    required this.fileSizeBytes,
    required this.lastModifiedAt,
  });

  final File file;
  final String title;
  final int fileSizeBytes;
  final DateTime lastModifiedAt;
}
