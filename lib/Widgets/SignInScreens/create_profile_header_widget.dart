import '../../consts/consts.dart';

class CreateProfileHeaderWidget extends StatelessWidget {
  final TextEditingController textController;
  final Icon icon;

  const CreateProfileHeaderWidget({
    super.key,
    required this.textController,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {

    final mediaQuery =  MediaQuery.of(context);
    final bool isDarkMode = mediaQuery.platformBrightness == Brightness.dark;

    return Column(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            height: 32,
            width: 32,
            padding: EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: mediumGrey,
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),

        SizedBox(height: 16),
        Image.asset(mascot2, height: 100),
        SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)!.createAccount,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          AppLocalizations.of(context)!.enterEmailOrPhone,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),

        SizedBox(height: 30),
        Form(
          child: Column(
            children: [
              Material(
                elevation: 1,
                color: isDarkMode? AppColors.primaryColor.withValues(alpha: .02) : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(4),
                child: TextFormField(
                  controller: textController,
                  decoration: InputDecoration(
                   filled: true,
                   fillColor: Colors.transparent,
                    prefixIcon: icon,
                    labelText: AppLocalizations.of(context)!.inputEmailOrMobile,
                  ),
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
      ],
    );
  }
}
