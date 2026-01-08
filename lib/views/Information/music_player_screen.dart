import 'dart:async';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import 'package:snevva/env/env.dart';
import '../../Controllers/music/audio_downloader.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';
import '../../models/music/music_response.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({
    super.key,
    this.appBarHeading,
    required this.musicItem,
    required this.appBarSubHeading,
  });

  final String? appBarHeading;
  final String appBarSubHeading;
  final MusicItem musicItem;

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final audioDownloader = AudioDownloader();
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  @override
  void initState() {
    super.initState();

    final audioUrl = 'https://${widget.musicItem.media.cdnUrl}';

    _audioPlayer.setSourceUrl(audioUrl);

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        isPlaying = state == PlayerState.playing;
      });
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });

  }


  @override
  void dispose() {
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();

    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final String audioUrl = 'https://${widget.musicItem.media.cdnUrl}';
    print("Audio URL: $audioUrl");
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    //// ✅ Listens to the app's current theme command
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        scrolledUnderElevation: 0.0,
        surfaceTintColor: Colors.transparent,

        title: Text(
          widget.appBarHeading != null
              ? '${widget.appBarHeading}  ${widget.appBarSubHeading}'
              : widget.appBarSubHeading,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: white,
          ),
        ),

        leading: Builder(
          builder: (context) {
            debugPrint('Drawer Icon Builder created');

            return IconButton(
              icon: SvgPicture.asset(drawerIcon, color: white),
              onPressed: () {
                debugPrint('Drawer Icon tapped');

                // 🔍 Check if Scaffold exists
                final scaffold = Scaffold.maybeOf(context);
                debugPrint('Scaffold found: ${scaffold != null}');

                if (scaffold != null) {
                  scaffold.openDrawer();
                } else {
                  debugPrint('❌ ERROR: No Scaffold found above CustomAppBar');
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
                debugPrint('Close button tapped');
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
                image: CachedNetworkImageProvider(
                  widget.musicItem.thumbnailMedia ?? natureMusicPlaceHolder,
                ),
                fit: BoxFit.fill,
              ),
            ),
          ),
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    height: 250,
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
                          ProgressBar(
                            progress: _position,
                            total: _duration,
                            buffered: Duration.zero,
                            progressBarColor: Colors.white,
                            baseBarColor: Colors.white.withOpacity(0.7),
                            barHeight: 6.0,
                            thumbRadius: 4.0,
                            onSeek: (duration) {
                              _audioPlayer.seek(duration);
                            },
                            thumbColor: Colors.white,
                            timeLabelPadding: 8.0,
                            timeLabelTextStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(3.1416),
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                              SizedBox(width: 40),
                              IconButton(
                                onPressed: () async {
                                  if (isPlaying) {
                                    await _audioPlayer.pause();
                                  } else {
                                    await _audioPlayer.resume();
                                  }
                                },
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                  color: Colors.white,
                                  size: 70,
                                ),
                              ),
                              SizedBox(width: 40),
                              Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 50,
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Download icon
                              IconButton(
                                onPressed: () async {
                                  setState(() {
                                    isDownloading = true;
                                    downloadProgress = 0;
                                  });

                                  final rawUrl = widget.musicItem.media.cdnUrl;
                                  final audioUrl =
                                  rawUrl.startsWith('http') ? rawUrl : 'https://$rawUrl';

                                  final path = await AudioDownloader.downloadAudio(
                                    url: audioUrl,
                                    fileName: widget.musicItem.title.replaceAll(' ', '_'),
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloaded to $path')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Download failed')),
                                    );
                                  }
                                },
                                icon: isDownloading
                                    ? CircularProgressIndicator(
                                  value: downloadProgress,
                                  color: Colors.white,
                                )
                                    : Image.asset(
                                  downloadIcon,
                                  width: 24,
                                  height: 24,
                                ),
                              ),


                              // Shuffle and loop icons in center
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      shuffleIcon,
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  IconButton(
                                    onPressed: () {},
                                    icon: Image.asset(
                                      loopIcon,
                                      width: 24,
                                      height: 24,
                                    ),
                                  ),
                                ],
                              ),

                              // Speed icon
                              IconButton(
                                onPressed: () {},
                                icon: Image.asset(
                                  speedIcon,
                                  width: 24,
                                  height: 24,
                                ),
                              ),
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
        ],
      ),
    );
  }
}
