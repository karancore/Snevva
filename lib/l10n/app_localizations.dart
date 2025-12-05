import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to your app!'**
  String get welcome;

  /// No description provided for @one.
  ///
  /// In en, this message translates to:
  /// **'Sign In and Sign Up Text'**
  String get one;

  /// No description provided for @chooseLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose the language familiar to you'**
  String get chooseLanguageLabel;

  /// No description provided for @confirmLanguageButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm Language'**
  String get confirmLanguageButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account'**
  String get alreadyHaveAccount;

  /// No description provided for @loginInText.
  ///
  /// In en, this message translates to:
  /// **'Log in here'**
  String get loginInText;

  /// No description provided for @nextText.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextText;

  /// No description provided for @googleText.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Google'**
  String get googleText;

  /// No description provided for @appleText.
  ///
  /// In en, this message translates to:
  /// **'Sign Up with Apple'**
  String get appleText;

  /// No description provided for @googleTextSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In with Google'**
  String get googleTextSignIn;

  /// No description provided for @appleTextSignIn.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get appleTextSignIn;

  /// No description provided for @fbTextSignIn.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get fbTextSignIn;

  /// No description provided for @socialSignInSingIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with'**
  String get socialSignInSingIn;

  /// No description provided for @socialSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign up with'**
  String get socialSignIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @enterEmailOrPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number'**
  String get enterEmailOrPhone;

  /// No description provided for @signInButtonText.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButtonText;

  /// No description provided for @notMemberText.
  ///
  /// In en, this message translates to:
  /// **'Not a member?'**
  String get notMemberText;

  /// No description provided for @createNewAccountText.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get createNewAccountText;

  /// No description provided for @checkboxRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get checkboxRememberMe;

  /// No description provided for @linkForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get linkForgotPassword;

  /// No description provided for @inputEmailOrMobile.
  ///
  /// In en, this message translates to:
  /// **'Email / Mobile Number'**
  String get inputEmailOrMobile;

  /// No description provided for @inputPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get inputPassword;

  /// No description provided for @two.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password And Otp Screen'**
  String get two;

  /// No description provided for @forgetPasswordScreenText.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or mobile number to receive a verification code'**
  String get forgetPasswordScreenText;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @enter6DigitCodeText.
  ///
  /// In en, this message translates to:
  /// **'Please Enter The 6 Digit Code Sent To'**
  String get enter6DigitCodeText;

  /// No description provided for @verifyPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Phone Number'**
  String get verifyPhoneNumber;

  /// No description provided for @verifyEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email Address'**
  String get verifyEmailAddress;

  /// No description provided for @three.
  ///
  /// In en, this message translates to:
  /// **'New Password And Update Screen'**
  String get three;

  /// No description provided for @agreeToTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get agreeToTerms;

  /// No description provided for @agreeToConditions.
  ///
  /// In en, this message translates to:
  /// **'terms and conditions'**
  String get agreeToConditions;

  /// No description provided for @passwordsMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords Match'**
  String get passwordsMatch;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords Do Not Match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'10 characters'**
  String get passwordMinLength;

  /// No description provided for @passwordSpecialChar.
  ///
  /// In en, this message translates to:
  /// **'1 number or special character (example: # ? ! &)'**
  String get passwordSpecialChar;

  /// No description provided for @passwordLetterRequirement.
  ///
  /// In en, this message translates to:
  /// **'1 letter'**
  String get passwordLetterRequirement;

  /// No description provided for @passwordMustContain.
  ///
  /// In en, this message translates to:
  /// **'Your password must contain at least'**
  String get passwordMustContain;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Your Password'**
  String get confirmPassword;

  /// No description provided for @passwordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Password is strong'**
  String get passwordStrengthStrong;

  /// No description provided for @passwordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak password'**
  String get passwordStrengthWeak;

  /// No description provided for @newPasswordInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your new password and make sure it is different from the previous one'**
  String get newPasswordInstruction;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @createPassword.
  ///
  /// In en, this message translates to:
  /// **'Create Password'**
  String get createPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Password'**
  String get enterPassword;

  /// No description provided for @four.
  ///
  /// In en, this message translates to:
  /// **'Profile Setup And Questionnaire Screen'**
  String get four;

  /// No description provided for @setupProfile.
  ///
  /// In en, this message translates to:
  /// **'Let\'s setup your profile 😊'**
  String get setupProfile;

  /// No description provided for @pleaseEnterYourName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get pleaseEnterYourName;

  /// No description provided for @selectGender.
  ///
  /// In en, this message translates to:
  /// **'Select Gender'**
  String get selectGender;

  /// No description provided for @birthdayPrompt.
  ///
  /// In en, this message translates to:
  /// **'When’s your birthday?'**
  String get birthdayPrompt;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer Not To Say'**
  String get preferNotToSay;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
