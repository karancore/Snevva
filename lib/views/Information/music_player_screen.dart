import 'dart:async';
import 'dart:math';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:snevva/Controllers/MentalWellness/mental_wellness_controller.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
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
  });

  final String? appBarHeading;
  final String appBarSubHeading;
  final MusicItem musicItem;

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  List<Map<String, String>> shuffledCdnUrls = <Map<String, String>>[];
  Map<String, String> currentMusic = {};
  final audioDownloader = AudioDownloader();
  final MentalWellnessController mentalWellnessController =
      Get.find<MentalWellnessController>();
  LoopModeType loopMode = LoopModeType.none;
  int currentIndex = 0;
  bool isShuffleOn = false;
  List<MusicItem> allMusic = [];
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  int index = Random().nextInt(backgroundImageUrls.length);

  @override
  void initState() {
    super.initState();
    final audioUrl = widget.musicItem.media.cdnUrl;
    debugPrint("Initializing AudioPlayer with URL: $audioUrl");
    // TRY IMMEDIATELY
    _tryInitPlayer(audioUrl);
    // THEN listen for future changes
    ever(mentalWellnessController.generalMusic, (_) {
      debugPrint("generalMusic changed");
      _tryInitPlayer(audioUrl);
    });
    ever(mentalWellnessController.meditationMusic, (_) {
      debugPrint("meditationMusic changed");
      _tryInitPlayer(audioUrl);
    });
    ever(mentalWellnessController.natureMusic, (_) {
      debugPrint("natureMusic changed");
      _tryInitPlayer(audioUrl);
    });
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
    _audioPlayer.onPlayerComplete.listen((event) {
      playNext();
    });
    _positionSub = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _position = position;
      });
    });
    debugPrint("${mentalWellnessController.generalUrls} general total tracks");
    debugPrint("${mentalWellnessController.natureUrls} nature total tracks");
    debugPrint(
      "${mentalWellnessController.meditationUrls} meditation total tracks",
    );
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

    // Loop ONE → replay same song
    if (loopMode == LoopModeType.one) {
      await playFromIndex(currentIndex);
      return;
    }

    // Normal next
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

    final url = currentMusic["cdnUrl"] ?? '';

    await _audioPlayer.stop();
    if (url.isNotEmpty) {
      await _audioPlayer.setSourceUrl(url);
    }
    await _audioPlayer.resume();

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
      } else {
        moveMatchedListToShuffle(widget.musicItem.media.cdnUrl);
        currentIndex = shuffledCdnUrls.indexWhere(
          (e) => e["cdnUrl"] == currentUrl,
        );
      }
    });

    debugPrint("Shuffle: $isShuffleOn");
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
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final containerHeight200 = height * 0.2383;
    final sizedBoxHeight40 = height * 0.04331683;
    final width = mediaQuery.size.width;
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
                image: CachedNetworkImageProvider(
                  widget.musicItem.thumbnailMedia ?? backgroundImageUrls[index],
                ),
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
                                      setState(() {
                                        isDownloading = true;
                                        downloadProgress = 0;
                                      });

                                      final rawUrl =
                                          widget.musicItem.media.cdnUrl;
                                      final audioUrl =
                                          rawUrl.startsWith('http')
                                              ? rawUrl
                                              : 'https://$rawUrl';

                                      final path =
                                          await AudioDownloader.downloadAudio(
                                            url: audioUrl,
                                            fileName: widget.musicItem.title
                                                .replaceAll(' ', '_'),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Downloaded to $path',
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
    debugPrint("Loop mode: $loopMode");
  }
}
