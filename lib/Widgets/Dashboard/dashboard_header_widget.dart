import '../../consts/consts.dart';
import '../../views/Chat/snevva_ai_chat_screen.dart';

class DashboardHeaderWidget extends StatelessWidget {
  const DashboardHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.64),
          //     gradient: AppColors.primaryGradient.withOpacity(0.64),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elly',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your smart health companion',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      Text(
                        'Track, learn, and improve with Elly.',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      SizedBox(height: 8),
                      Container(
                        margin: EdgeInsets.only(bottom: 5, top: 15),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: OutlinedButton(
                          onPressed: () {
                            Get.to(() => SnevvaAIChatScreen());
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.transparent),
                            fixedSize: const Size(137, 41),
                            padding: EdgeInsets.zero,
                          ),

                          child: const Text(
                            "Chat now",
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: -30,
              bottom: -15,
              child: Image.asset(mascotAi, height: 200),
            ),
          ],
        ),
      ),
    );
  }
}
