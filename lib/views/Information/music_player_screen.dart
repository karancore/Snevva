import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../consts/consts.dart';

class MusicLPlayerScreen extends StatefulWidget {
  const MusicLPlayerScreen({
    super.key,
     this.appBarHeading,
    required this.appBarSubHeading
  });


  final String? appBarHeading;
  final String appBarSubHeading;

  @override
  State<MusicLPlayerScreen> createState() => _MusicPlayerScreenState();

}

class _MusicPlayerScreenState extends State<MusicLPlayerScreen> {
  bool isPlaying = false;

  void updatePlayingStatus() {
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;
    //final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer:Drawer(
        child: DrawerMenuWidget(height: height, width: width),
      ),
      appBar: CustomAppBar(appbarText: widget.appBarHeading != null ? '${widget.appBarHeading}  ${widget.appBarSubHeading}' : widget.appBarSubHeading, isWhiteRequired: false,),
      body: Stack(
        children: [
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              image: DecorationImage(
                image: AssetImage(musicPlayer),
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
                            progress: Duration(milliseconds: 1000),
                            buffered: Duration(milliseconds: 2000),
                            total: Duration(milliseconds: 5000),
                            progressBarColor: Colors.white,
                            baseBarColor: Colors.white.withOpacity(0.7),
                            barHeight: 6.0,
                            thumbRadius: 4.0,
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
                                onPressed: updatePlayingStatus,
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
                                onPressed: () {},
                                icon: Image.asset(
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
