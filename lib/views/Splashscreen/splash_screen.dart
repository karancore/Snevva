import 'package:snevva/consts/consts.dart';
import 'package:snevva/views/Splashscreen/splash_screen2.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(animationController);
    animationController.forward();

    animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Get.to(
          () => SplashScreen2(),
          transition: Transition.fadeIn,
          duration: Duration(milliseconds: 600),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: splashScreenBg,
      body: Padding(
        padding: EdgeInsets.only(bottom: 150),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(splashImg, width: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
