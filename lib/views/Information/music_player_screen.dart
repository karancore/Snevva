import 'dart:async';
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/svg.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/env/env.dart';
import '../../Controllers/music/audio_downloader.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import '../../models/music/music_response.dart';

enum LoopModeType { none, one, all }

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({
    super.key,
    this.appBarHeading,
    required this.musicItem,
    required this.appBarSubHeading,
    this.localFilePath,
  });

  final String? appBarHeading;
  final String appBarSubHeading;
  final MusicItem musicItem;
  final String? localFilePath;

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  static const int _musicNotificationId = 5031;
  static const String _musicChannelId = 'music_playback_channel';
  static const String _musicChannelName = 'Music Playback';
  static const String _musicPayload = 'music_player_controls';
  static const String _actionPrevious = 'music_previous';
  static const String _actionPlayPause = 'music_play_pause';
  static const String _actionNext = 'music_next';
  static const String _darwinMusicCategoryId = 'music_player_controls_category';

  List<Map<String, String>> shuffledCdnUrls = <Map<String, String>>[];
  Map<String, String> currentMusic = {};
  final audioDownloader = AudioDownloader();
  final FlutterLocalNotificationsPlugin _musicNotifications =
      FlutterLocalNotificationsPlugin();
  final MentalWellnessController mentalWellnessController =
      Get.find<MentalWellnessController>();
  LoopModeType loopMode = LoopModeType.none;
  int currentIndex = 0;
  bool isShuffleOn = false;
  List<MusicItem> allMusic = [];
  bool isPlaying = false;
  final ValueNotifier<Duration> _durationNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _playerCompleteSub;
  final List<Worker> _musicWorkers = <Worker>[];
  int _lastProgressTick = -1;
  bool _isHandlingCompletion = false;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  bool _isCurrentTrackDownloaded = false;
  String? _currentTrackDownloadedPath;
  bool _notificationInitialized = false;
  String? _cachedNotificationArtworkUrl;
  ByteArrayAndroidBitmap? _cachedNotificationArtwork;
  int index = Random().nextInt(backgroundImageUrls.length);

  bool get _isLocalSource =>
      widget.localFilePath != null && widget.localFilePath!.isNotEmpty;

  String _resolvedTrackImageUrl() {
    final String? currentThumb = currentMusic["thumbnailUrl"];
    if (currentThumb != null && currentThumb.isNotEmpty) {
      return _normalizeUrl(currentThumb);
    }

    final String lookedUpThumb = _lookupThumbnailFromCatalog();
    if (lookedUpThumb.isNotEmpty) {
      return lookedUpThumb;
    }

    final String? fallbackThumb = widget.musicItem.thumbnailMedia;
    if (fallbackThumb != null && fallbackThumb.isNotEmpty) {
      return _normalizeUrl(fallbackThumb);
    }

    return backgroundImageUrls[index];
  }

  String _lookupThumbnailFromCatalog() {
    final String? cdnUrl = currentMusic["cdnUrl"];
    if (cdnUrl == null || cdnUrl.isEmpty) {
      return '';
    }

    final List<MusicItem> allTracks = <MusicItem>[
      ...mentalWellnessController.generalMusic,
      ...mentalWellnessController.meditationMusic,
      ...mentalWellnessController.natureMusic,
    ];

    for (final track in allTracks) {
      if (track.media.cdnUrl == cdnUrl &&
          track.thumbnailMedia != null &&
          track.thumbnailMedia!.isNotEmpty) {
        return _normalizeUrl(track.thumbnailMedia!);
      }
    }

    return '';
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('/') || url.startsWith('file://')) return url;
    return url.startsWith('http') ? url : 'https://$url';
  }

  String _currentTrackUrl() {
    final String url = currentMusic["cdnUrl"] ?? widget.musicItem.media.cdnUrl;
    return _normalizeUrl(url);
  }

  String _currentTrackTitle() {
    final String title =
        (currentMusic["title"] ?? widget.musicItem.title).trim();
    return title.isEmpty ? 'track' : title;
  }

  String _currentTrackArtist() {
    final String activeTrackUrl =
        currentMusic["cdnUrl"] ?? widget.musicItem.media.cdnUrl;
    if (activeTrackUrl.isNotEmpty) {
      final List<MusicItem> allTracks = <MusicItem>[
        ...mentalWellnessController.generalMusic,
        ...mentalWellnessController.meditationMusic,
        ...mentalWellnessController.natureMusic,
      ];
      for (final MusicItem track in allTracks) {
        if (track.media.cdnUrl == activeTrackUrl) {
          final String artist = track.artistName.trim();
          if (artist.isNotEmpty) return artist;
        }
      }
    }

    final String fallbackArtist = widget.musicItem.artistName.trim();
    if (fallbackArtist.isNotEmpty) return fallbackArtist;
    return 'Snevva';
  }

  String _notificationContentText() {
    final String artist = _currentTrackArtist();
    final String section = widget.appBarSubHeading.trim();
    if (section.isEmpty) return artist;
    return '$artist - $section';
  }

  Future<AndroidBitmap<Object>?> _resolveNotificationLargeIcon() async {
    final String artworkUrl = _resolvedTrackImageUrl();
    if (artworkUrl.isEmpty ||
        artworkUrl.startsWith('/') ||
        artworkUrl.startsWith('file://')) {
      return _cachedNotificationArtwork;
    }

    if (_cachedNotificationArtworkUrl == artworkUrl &&
        _cachedNotificationArtwork != null) {
      return _cachedNotificationArtwork;
    }

    try {
      final Uri uri = Uri.parse(artworkUrl);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return _cachedNotificationArtwork;
      }

      final ByteData artworkData = await NetworkAssetBundle(
        uri,
      ).load(artworkUrl);
      final Uint8List bytes = artworkData.buffer.asUint8List();
      if (bytes.isEmpty) return _cachedNotificationArtwork;

      final ByteArrayAndroidBitmap bitmap = ByteArrayAndroidBitmap(bytes);
      _cachedNotificationArtwork = bitmap;
      _cachedNotificationArtworkUrl = artworkUrl;
      return bitmap;
    } catch (e) {
      debugPrint('Music notification artwork load failed: $e');
      return _cachedNotificationArtwork;
    }
  }

  Future<void> _refreshCurrentTrackDownloadStatus() async {
    if (_isLocalSource) {
      _isCurrentTrackDownloaded = true;
      _currentTrackDownloadedPath = widget.localFilePath;
      return;
    }

    final String? downloadedPath =
        await AudioDownloader.getDownloadedPathForTrack(
          trackUrl: _currentTrackUrl(),
          fileName: _currentTrackTitle(),
        );

    if (!mounted) return;
    setState(() {
      _isCurrentTrackDownloaded = downloadedPath != null;
      _currentTrackDownloadedPath = downloadedPath;
    });
  }

  Future<void> _initMusicNotifications() async {
    final DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          notificationCategories: <DarwinNotificationCategory>[
            DarwinNotificationCategory(
              _darwinMusicCategoryId,
              actions: <DarwinNotificationAction>[
                DarwinNotificationAction.plain(_actionPrevious, 'Previous'),
                DarwinNotificationAction.plain(_actionPlayPause, 'Play/Pause'),
                DarwinNotificationAction.plain(_actionNext, 'Next'),
              ],
            ),
          ],
        );

    final InitializationSettings settings = InitializationSettings(
      android: const AndroidInitializationSettings(
        '@drawable/ic_stat_notification',
      ),
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    final bool? initResult = await _musicNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onMusicNotificationResponse,
    );
    _notificationInitialized = initResult ?? false;
    if (!_notificationInitialized) return;
    await _showOrUpdateMusicNotification();
  }

  Future<void> _onMusicNotificationResponse(
    NotificationResponse response,
  ) async {
    if (!mounted) return;
    if (response.payload != _musicPayload) return;

    switch (response.actionId) {
      case _actionPrevious:
        await playPrevious();
        return;
      case _actionPlayPause:
        await _togglePlayPause();
        return;
      case _actionNext:
        await playNext();
        return;
      default:
        return;
    }
  }

  Future<void> _togglePlayPause() async {
    if (isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  Future<void> _showOrUpdateMusicNotification() async {
    if (!_notificationInitialized) return;

    final String title = _currentTrackTitle();
    final String contentText = _notificationContentText();
    final String subText = widget.appBarSubHeading.trim();
    final String playPauseLabel = isPlaying ? 'Pause' : 'Play';
    final AndroidBitmap<Object>? largeIcon =
        await _resolveNotificationLargeIcon();
    const AndroidNotificationAction previousAction = AndroidNotificationAction(
      _actionPrevious,
      'Previous',
      cancelNotification: false,
      showsUserInterface: true,
    );
    final AndroidNotificationAction playPauseAction = AndroidNotificationAction(
      _actionPlayPause,
      playPauseLabel,
      cancelNotification: false,
      showsUserInterface: true,
    );
    const AndroidNotificationAction nextAction = AndroidNotificationAction(
      _actionNext,
      'Next',
      cancelNotification: false,
      showsUserInterface: true,
    );

    try {
      await _musicNotifications.show(
        _musicNotificationId,
        title,
        contentText,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _musicChannelId,
            _musicChannelName,
            channelDescription: 'Music playback controls',
            importance: Importance.low,
            priority: Priority.low,
            category: AndroidNotificationCategory.transport,
            styleInformation: const MediaStyleInformation(),
            icon: '@drawable/ic_stat_notification',
            largeIcon: largeIcon,
            colorized: true,
            color: const Color(0xFF1AA382),
            visibility: NotificationVisibility.public,
            playSound: false,
            enableVibration: false,
            silent: true,
            ongoing: isPlaying,
            onlyAlertOnce: true,
            autoCancel: false,
            showWhen: false,
            subText: subText.isEmpty ? null : subText,
            actions: <AndroidNotificationAction>[
              previousAction,
              playPauseAction,
              nextAction,
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: false,
            presentSound: false,
            categoryIdentifier: _darwinMusicCategoryId,
          ),
        ),
        payload: _musicPayload,
      );
    } catch (e) {
      debugPrint('Music notification update failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initMusicNotifications());
    final audioUrl =
        _isLocalSource ? widget.localFilePath! : widget.musicItem.media.cdnUrl;
    debugPrint("Initializing AudioPlayer with URL: $audioUrl");
    if (_isLocalSource) {
      currentMusic = <String, String>{
        "title": widget.musicItem.title,
        "cdnUrl": audioUrl,
      };
      _isCurrentTrackDownloaded = true;
      _currentTrackDownloadedPath = audioUrl;
    } else {
      // TRY IMMEDIATELY
      _tryInitPlayer(audioUrl);

      // THEN listen for future changes
      _musicWorkers.addAll(<Worker>[
        ever(mentalWellnessController.generalMusic, (_) {
          debugPrint("generalMusic changed");
          _tryInitPlayer(audioUrl);
        }),
        ever(mentalWellnessController.meditationMusic, (_) {
          debugPrint("meditationMusic changed");
          _tryInitPlayer(audioUrl);
        }),
        ever(mentalWellnessController.natureMusic, (_) {
          debugPrint("natureMusic changed");
          _tryInitPlayer(audioUrl);
        }),
      ]);
    }
    unawaited(_refreshCurrentTrackDownloadStatus());
    if (_isLocalSource) {
      unawaited(_audioPlayer.setSourceDeviceFile(audioUrl));
    } else {
      _audioPlayer.setSourceUrl(audioUrl);
    }
    unawaited(_syncReleaseMode());
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
      unawaited(_showOrUpdateMusicNotification());
    });
    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      if (_durationNotifier.value == duration) return;
      _durationNotifier.value = duration;
    });
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((event) {
      _handleTrackCompletion();
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      final int progressTick = position.inMilliseconds ~/ 250;
      if (progressTick == _lastProgressTick) return;
      _lastProgressTick = progressTick;
      _positionNotifier.value = position;
    });
    debugPrint("${mentalWellnessController.generalUrls} general total tracks");
    debugPrint("${mentalWellnessController.natureUrls} nature total tracks");
    debugPrint(
      "${mentalWellnessController.meditationUrls} meditation total tracks",
    );
    unawaited(_showOrUpdateMusicNotification());
    // ever(mentalWellnessController.generalMusic, (_) => ));
    // ever(mentalWellnessController.meditationMusic, (_) => _tryInitPlayer(audioUrl));
    // ever(mentalWellnessController.natureMusic, (_) => _tryInitPlayer(audioUrl));
  }

  void _tryInitPlayer(String audioUrl) {
    debugPrint("Input audioUrl: $audioUrl");
    // Already initialized
    if (shuffledCdnUrls.isNotEmpty) {
      return;
    }

    // Build shuffled list
    moveMatchedListToShuffle(audioUrl);

    if (shuffledCdnUrls.isEmpty) {
      return;
    }

    // Find index of current song
    currentIndex = shuffledCdnUrls.indexWhere((e) => e["cdnUrl"] == audioUrl);

    if (currentIndex == -1) {
      currentIndex = 0;
    }

    currentMusic = shuffledCdnUrls[currentIndex];
    unawaited(_refreshCurrentTrackDownloadStatus());

    debugPrint(
      "🎶 Current music initialized → "
      "index: $currentIndex | "
      "title: ${currentMusic["title"]} | "
      "url: ${currentMusic["cdnUrl"]}",
    );
  }

  Future<void> playNext() async {
    if (shuffledCdnUrls.isEmpty) {
      return;
    }

    // Manual next should always advance to the next track.
    if (currentIndex < shuffledCdnUrls.length - 1) {
      await playFromIndex(currentIndex + 1);
    } else {
      if (loopMode == LoopModeType.all) {
        await playFromIndex(0);
      } else {}
    }
  }

  void moveMatchedListToShuffle(String value) {
    if (mentalWellnessController.generalUrls.any(
      (item) => item["cdnUrl"] == value,
    )) {
      shuffledCdnUrls.assignAll(
        _shuffledCopy(mentalWellnessController.generalUrls),
      );

      return;
    }

    if (mentalWellnessController.meditationUrls.any(
      (item) => item["cdnUrl"] == value,
    )) {
      shuffledCdnUrls.assignAll(
        _shuffledCopy(mentalWellnessController.meditationUrls),
      );
      debugPrint("Matched in MEDITATION list");
      return;
    }

    if (mentalWellnessController.natureUrls.any(
      (item) => item["cdnUrl"] == value,
    )) {
      shuffledCdnUrls.assignAll(
        _shuffledCopy(mentalWellnessController.natureUrls),
      );
      debugPrint("Matched in NATURE list");
      return;
    }

    debugPrint("No list matched for: $value");
  }

  List<Map<String, String>> _shuffledCopy(List<Map<String, String>> source) {
    final list = List<Map<String, String>>.from(source);

    list.shuffle(Random());
    return list;
  }

  // Future<void> playFromIndex(int index) async {
  //   if (shuffledCdnUrls.isEmpty) return;
  //
  //   currentIndex = index.clamp(0, shuffledCdnUrls.length - 1);
  //
  //   final url = shuffledCdnUrls[currentIndex]["cdnUrl"] ?? '';
  //
  //   await _audioPlayer.stop();
  //   if(url.isNotEmpty){
  //
  //     await _audioPlayer.setSourceUrl(url);
  //   }
  //   await _audioPlayer.resume();
  //
  //   debugPrint("Playing index $currentIndex : $url");
  // }

  Future<void> playFromIndex(int index) async {
    if (shuffledCdnUrls.isEmpty) return;

    setState(() {
      currentIndex = index.clamp(0, shuffledCdnUrls.length - 1);
      currentMusic = shuffledCdnUrls[currentIndex];
    });
    unawaited(_refreshCurrentTrackDownloadStatus());

    final url = currentMusic["cdnUrl"] ?? '';

    await _audioPlayer.stop();
    if (url.isNotEmpty) {
      await _audioPlayer.setSourceUrl(url);
    }
    await _audioPlayer.resume();
    unawaited(_showOrUpdateMusicNotification());

    debugPrint("Playing: ${currentMusic["title"]}");
  }

  Future<void> playPrevious() async {
    if (shuffledCdnUrls.isEmpty) {
      return;
    }

    if (currentIndex > 0) {
      await playFromIndex(currentIndex - 1);
    } else {
      if (loopMode == LoopModeType.all) {
        debugPrint(
          "Loop ALL enabled → jumping to last index: ${shuffledCdnUrls.length - 1}",
        );
        await playFromIndex(shuffledCdnUrls.length - 1);
      } else {}
    }
  }

  void _handleTrackCompletion() {
    if (_isHandlingCompletion) return;
    _isHandlingCompletion = true;

    // Native ReleaseMode.loop handles replay for loop-one.
    if (loopMode == LoopModeType.one) {
      _isHandlingCompletion = false;
      return;
    }

    unawaited(
      playNext()
          .timeout(const Duration(seconds: 10))
          .catchError((e) {
            debugPrint('Completion handling failed: $e');
          })
          .whenComplete(() {
            _isHandlingCompletion = false;
          }),
    );
  }

  Future<void> _syncReleaseMode() async {
    final ReleaseMode releaseMode =
        loopMode == LoopModeType.one ? ReleaseMode.loop : ReleaseMode.release;

    try {
      await _audioPlayer.setReleaseMode(releaseMode);
    } catch (e) {
      debugPrint('Failed to set release mode: $e');
    }
  }

  void toggleShuffle() {
    setState(() {
      isShuffleOn = !isShuffleOn;

      final currentUrl =
          shuffledCdnUrls.isNotEmpty
              ? shuffledCdnUrls[currentIndex]["cdnUrl"]
              : widget.musicItem.media.cdnUrl;

      if (isShuffleOn) {
        shuffledCdnUrls.shuffle(Random());
        currentIndex = 0;
        if (shuffledCdnUrls.isNotEmpty) {
          currentMusic = shuffledCdnUrls[currentIndex];
        }
      } else {
        moveMatchedListToShuffle(widget.musicItem.media.cdnUrl);
        currentIndex = shuffledCdnUrls.indexWhere(
          (e) => e["cdnUrl"] == currentUrl,
        );
        if (currentIndex == -1 && shuffledCdnUrls.isNotEmpty) {
          currentIndex = 0;
        }
        if (shuffledCdnUrls.isNotEmpty) {
          currentMusic = shuffledCdnUrls[currentIndex];
        }
      }
    });
    unawaited(_refreshCurrentTrackDownloadStatus());

    debugPrint("Shuffle: $isShuffleOn");
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerCompleteSub?.cancel();
    for (final Worker worker in _musicWorkers) {
      worker.dispose();
    }
    unawaited(_musicNotifications.cancel(_musicNotificationId));
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _durationNotifier.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final containerHeight200 = height * 0.2383;
    final sizedBoxHeight40 = height * 0.04331683;
    final width = mediaQuery.size.width;
    final backgroundUrl = _resolvedTrackImageUrl();
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,

        title: Text(
          currentMusic["title"] ?? '',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: white,
          ),
        ),

        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: SvgPicture.asset(drawerIcon, color: white),
              onPressed: () {
                final scaffold = Scaffold.maybeOf(context);

                if (scaffold != null) {
                  scaffold.openDrawer();
                }
              },
            );
          },
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: SizedBox(
                height: 24,
                width: 24,
                child: Icon(Icons.clear, size: 21, color: white),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              image: DecorationImage(
                image: CachedNetworkImageProvider(backgroundUrl),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Container(
                        height: containerHeight200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AnimatedBuilder(
                                animation: Listenable.merge(<Listenable>[
                                  _positionNotifier,
                                  _durationNotifier,
                                ]),
                                builder: (context, _) {
                                  return ProgressBar(
                                    progress: _positionNotifier.value,
                                    total: _durationNotifier.value,
                                    buffered: Duration.zero,
                                    progressBarColor: Colors.white,
                                    baseBarColor: Colors.white.withOpacity(0.7),
                                    barHeight: 6.0,
                                    thumbRadius: 4.0,
                                    onSeek: (duration) {
                                      _positionNotifier.value = duration;
                                      unawaited(_audioPlayer.seek(duration));
                                    },
                                    thumbColor: Colors.white,
                                    timeLabelPadding: 8.0,
                                    timeLabelTextStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.rotationY(3.1416),
                                    child: InkWell(
                                      onTap: playPrevious,

                                      child: Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: sizedBoxHeight40),
                                  IconButton(
                                    onPressed: () async {
                                      await _togglePlayPause();
                                    },
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle
                                          : Icons.play_circle,
                                      color: Colors.white,
                                      size: 70,
                                    ),
                                  ),
                                  SizedBox(width: sizedBoxHeight40),
                                  InkWell(
                                    onTap: playNext,
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Download icon
                                  IconButton(
                                    onPressed: toggleLoop,
                                    icon: SvgPicture.asset(
                                      getLoopIcon(loopMode),

                                      color: getLoopColor(loopMode),
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: toggleShuffle,
                                    icon: SvgPicture.asset(
                                      shuffleIcon,
                                      width: 20,
                                      color: isShuffleOn ? Colors.green : white,
                                      height: 20,
                                    ),
                                  ),

                                  // // Shuffle and loop icons in center
                                  // Row(
                                  //   children: [
                                  //
                                  //     SizedBox(width: 20),
                                  //
                                  //   ],
                                  // ),
                                  IconButton(
                                    onPressed: () async {
                                      if (_isCurrentTrackDownloaded) {
                                        final String location =
                                            _currentTrackDownloadedPath == null
                                                ? 'Downloads'
                                                : _currentTrackDownloadedPath!
                                                    .split('/')
                                                    .last;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Already downloaded: $location',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        isDownloading = true;
                                        downloadProgress = 0;
                                      });

                                      final audioUrl = _currentTrackUrl();
                                      final trackTitle = _currentTrackTitle();

                                      final path =
                                          await AudioDownloader.downloadAudio(
                                            url: audioUrl,
                                            fileName: trackTitle,
                                            onProgress: (progress) {
                                              setState(() {
                                                downloadProgress = progress;
                                              });
                                            },
                                          );

                                      setState(() {
                                        isDownloading = false;
                                      });

                                      if (path != null) {
                                        final fileName = path.split('/').last;
                                        final inDownloads = path.startsWith(
                                          '/storage/emulated/0/Download/',
                                        );
                                        setState(() {
                                          _isCurrentTrackDownloaded = true;
                                          _currentTrackDownloadedPath = path;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              inDownloads
                                                  ? 'Saved to Downloads/$fileName'
                                                  : 'Downloaded to $path',
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Download failed'),
                                          ),
                                        );
                                      }
                                    },
                                    icon:
                                        isDownloading
                                            ? CircularProgressIndicator(
                                              value: downloadProgress,
                                              color: Colors.white,
                                            )
                                            : _isCurrentTrackDownloaded
                                            ? const Icon(
                                              Icons.download_done,
                                              color: Colors.green,
                                            )
                                            : SvgPicture.asset(
                                              downloadIcon,
                                              color: white,
                                              width: 20,
                                              height: 20,
                                            ),
                                  ),

                                  // // Speed icon
                                  // IconButton(
                                  //   onPressed: (){},
                                  //   icon: Image.asset(
                                  //     speedIcon,
                                  //     width: 24,
                                  //
                                  //     height: 24,
                                  //   ),
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color getLoopColor(LoopModeType mode) {
    switch (mode) {
      case LoopModeType.none:
        return white;
      case LoopModeType.all:
        return Colors.green;
      case LoopModeType.one:
        return Colors.green;
    }
  }

  String getLoopIcon(LoopModeType mode) {
    switch (mode) {
      case LoopModeType.none:
        return loopIcon; // normal loop
      case LoopModeType.all:
        return loopIcon; // loop all
      case LoopModeType.one:
        return loopOneIcon; // special loop-one icon
    }
  }

  void toggleLoop() {
    setState(() {
      if (loopMode == LoopModeType.none) {
        loopMode = LoopModeType.all;
      } else if (loopMode == LoopModeType.all) {
        loopMode = LoopModeType.one;
      } else {
        loopMode = LoopModeType.none;
      }
    });
    unawaited(_syncReleaseMode());
    debugPrint("Loop mode: $loopMode");
  }
}
