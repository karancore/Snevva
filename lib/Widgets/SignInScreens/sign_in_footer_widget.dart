import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:snevva/services/apple_auth.dart';

import '../../common/custom_snackbar.dart';
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
  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
            child: AppLoadingButtonChild(
              isLoading: widget.isLoading,
              loaderSize: 24,
              child: Text(widget.buttonText),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            const Expanded(child: Divider(thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(AppLocalizations.of(context)!.socialSignInSingIn),
            ),
            const Expanded(child: Divider(thickness: 1)),
          ],
        ),

        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google icon (always shown)
            Obx(() {
              final googleAuth = Get.find<GoogleAuthService>();
              var isBusy = googleAuth.isLoading.value;
              return Container(
                height: 50,
                width: 50,

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
                  onPressed:
                      isBusy
                          ? null
                          : () async {
                            setState(() => isBusy = true);
                            try {
                              await googleAuth.signIn();
                            } catch (e, st) {
                              print("❌ Google sign-in failed: $e");
                              print("❌ Google sign-in failed stackTrace: $st");

                              CustomSnackbar.showError(
                                context: context,
                                title: 'Sign-in Required',
                                message:
                                    'Please sign in with Google to continue.',
                              );
                            } finally {
                              // Reset local flag — if auth succeeded, googleAuth.isLoading
                              // is already true so isBusy stays true until backend finishes.
                              if (mounted) setState(() => isBusy = false);
                            }
                          },
                  icon:
                      isBusy
                          ? CircularProgressIndicator(
                            backgroundColor: isDarkMode ? white : black,
                          )
                          : Image.asset(google, height: 28, width: 28),
                  padding: const EdgeInsets.all(12),
                  splashRadius: 28,
                ),
              );
            }),

            // Facebook icon (conditionally shown)
            if (widget.facebookText != null)
              IconButton(
                onPressed: () {
                  // TODO: Handle Facebook login
                },
                icon: Image.asset(facebook, height: 32, width: 32),
              ),
            const SizedBox(width: 12),

            // Apple icon (conditionally shown)
            if (Platform.isIOS)
              Obx(() {
                final appleAuth = Get.find<AppleAuthService>();
                var isBusy = appleAuth.isLoading.value;

                return Container(
                  height: 50,
                  width: 50,

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
                    onPressed:
                        isBusy
                            ? null
                            : () async {
                              setState(() => isBusy = true);
                              try {
                                await appleAuth.handleAppleSignIn();
                              } catch (e, st) {
                                print("❌ Apple sign-in failed: $e");
                                print("❌ Apple sign-in failed stackTrace: $st");

                                CustomSnackbar.showError(
                                  context: context,
                                  title: 'Sign-in Required',
                                  message:
                                      'Please sign in with Google to continue.',
                                );
                              } finally {
                                // Reset local flag — if auth succeeded, googleAuth.isLoading
                                // is already true so isBusy stays true until backend finishes.
                                if (mounted) setState(() => isBusy = false);
                              }
                            },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon:
                        isBusy
                            ? CircularProgressIndicator(
                              backgroundColor: isDarkMode ? white : black,
                            )
                            : FaIcon(
                              FontAwesomeIcons.apple,
                              size: 28,
                              color: black,
                            ),
                  ),
                );
              }),
          ],
        ),

        const SizedBox(height: 12),
        const Divider(thickness: 1),
        const SizedBox(height: 12),

        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: widget.bottomText,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
              TextSpan(text: " "),
              TextSpan(
                text: widget.bottomText2,

                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  decorationColor: AppColors.primaryColor,

                  decoration: TextDecoration.underline,
                ),
                recognizer:
                    TapGestureRecognizer()..onTap = widget.onBottomTextPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
