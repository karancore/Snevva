import 'package:flutter/foundation.dart';

import '../../consts/consts.dart';
import '../../services/google_auth.dart';

class SignInFooterWidget extends StatefulWidget {
  final String bottomText;
  final String bottomText2;
  final String buttonText;
  final String googleText;
  final String? facebookText;
  final String? appleText;
  final VoidCallback onBottomTextPressed;
  final VoidCallback onElevatedButtonPress;
  final bool isLoading;

  const SignInFooterWidget({
    super.key,
    required this.bottomText,
    required this.bottomText2,
    required this.buttonText,
    required this.googleText,
    this.facebookText,
    this.appleText,
    required this.onBottomTextPressed,
    required this.onElevatedButtonPress,
    required this.isLoading,
  });

  @override
  _SignInFooterWidgetState createState() => _SignInFooterWidgetState();
}

class _SignInFooterWidgetState extends State<SignInFooterWidget> {
  bool isSigningIn = false; // Track sign-in loading state

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main Button
        Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onElevatedButtonPress,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(widget.buttonText),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            const Expanded(child: Divider(thickness: 0.4)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(AppLocalizations.of(context)!.socialSignIn),
            ),
            const Expanded(child: Divider(thickness: 0.4)),
          ],
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google icon (always shown)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () async {
                  setState(() {
                    isSigningIn = true; // Start the sign-in process
                  });
                  await GoogleAuthService.signInWithGoogle(context);
                  setState(() {
                    isSigningIn = false; // Sign-in complete, stop the loading indicator
                  });
                },
                icon: isSigningIn
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                  ),
                )
                    : Image.asset(
                  google,
                  height: 28,
                  width: 28,
                ),
                padding: const EdgeInsets.all(12),
                splashRadius: 28,
              ),
            ),


            // Facebook icon (conditionally shown)
            if (widget.facebookText != null)
              IconButton(
                onPressed: () {
                  // TODO: Handle Facebook login
                },
                icon: Image.asset(facebook, height: 32, width: 32),
              ),

            // Apple icon (conditionally shown)
            if (widget.appleText != null)
              IconButton(
                onPressed: () {
                  // TODO: Handle Apple login
                },
                icon: Image.asset(apple, height: 32, width: 32),
              ),
          ],
        ),

        const SizedBox(height: 20),
        const Divider(thickness: 0.4),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutoSizeText(
              widget.bottomText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: widget.onBottomTextPressed,
              child: Text(
                widget.bottomText2,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFFB579FF),
                  color: AppColors.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
