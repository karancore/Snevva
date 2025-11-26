// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'intl/messages_all.dart';

// **************************************************************************
// Generator: Flutter Intl IDE plugin
// Made by Localizely
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: join_return_with_assignment, prefer_final_in_for_each
// ignore_for_file: avoid_redundant_argument_values, avoid_escaping_inner_quotes

class S {
  S();

  static S? _current;

  static S get current {
    assert(
      _current != null,
      'No instance of S was loaded. Try to initialize the S delegate before accessing S.current.',
    );
    return _current!;
  }

  static const AppLocalizationDelegate delegate = AppLocalizationDelegate();

  static Future<S> load(Locale locale) {
    final name = (locale.countryCode?.isEmpty ?? false)
        ? locale.languageCode
        : locale.toString();
    final localeName = Intl.canonicalizedLocale(name);
    return initializeMessages(localeName).then((_) {
      Intl.defaultLocale = localeName;
      final instance = S();
      S._current = instance;

      return instance;
    });
  }

  static S of(BuildContext context) {
    final instance = S.maybeOf(context);
    assert(
      instance != null,
      'No instance of S present in the widget tree. Did you add S.delegate in localizationsDelegates?',
    );
    return instance!;
  }

  static S? maybeOf(BuildContext context) {
    return Localizations.of<S>(context, S);
  }

  /// `Hello`
  String get hello {
    return Intl.message('Hello', name: 'hello', desc: '', args: []);
  }

  /// `Welcome to your app!`
  String get welcome {
    return Intl.message(
      'Welcome to your app!',
      name: 'welcome',
      desc: '',
      args: [],
    );
  }

  /// `Sign In and Sign Up Text`
  String get one {
    return Intl.message(
      'Sign In and Sign Up Text',
      name: 'one',
      desc: '',
      args: [],
    );
  }

  /// `Choose the language familiar to you`
  String get chooseLanguageLabel {
    return Intl.message(
      'Choose the language familiar to you',
      name: 'chooseLanguageLabel',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Language`
  String get confirmLanguageButton {
    return Intl.message(
      'Confirm Language',
      name: 'confirmLanguageButton',
      desc: '',
      args: [],
    );
  }

  /// `Already have an account`
  String get alreadyHaveAccount {
    return Intl.message(
      'Already have an account',
      name: 'alreadyHaveAccount',
      desc: '',
      args: [],
    );
  }

  /// `Log in here`
  String get loginInText {
    return Intl.message('Log in here', name: 'loginInText', desc: '', args: []);
  }

  /// `Next`
  String get nextText {
    return Intl.message('Next', name: 'nextText', desc: '', args: []);
  }

  /// `Sign Up with Google`
  String get googleText {
    return Intl.message(
      'Sign Up with Google',
      name: 'googleText',
      desc: '',
      args: [],
    );
  }

  /// `Sign Up with Apple`
  String get appleText {
    return Intl.message(
      'Sign Up with Apple',
      name: 'appleText',
      desc: '',
      args: [],
    );
  }

  /// `Sign In with Google`
  String get googleTextSignIn {
    return Intl.message(
      'Sign In with Google',
      name: 'googleTextSignIn',
      desc: '',
      args: [],
    );
  }

  /// `Apple`
  String get appleTextSignIn {
    return Intl.message('Apple', name: 'appleTextSignIn', desc: '', args: []);
  }

  /// `Facebook`
  String get fbTextSignIn {
    return Intl.message('Facebook', name: 'fbTextSignIn', desc: '', args: []);
  }

  /// `Sign in with`
  String get socialSignInSingIn {
    return Intl.message(
      'Sign in with',
      name: 'socialSignInSingIn',
      desc: '',
      args: [],
    );
  }

  /// `Sign up with`
  String get socialSignIn {
    return Intl.message(
      'Sign up with',
      name: 'socialSignIn',
      desc: '',
      args: [],
    );
  }

  /// `Create Account`
  String get createAccount {
    return Intl.message(
      'Create Account',
      name: 'createAccount',
      desc: '',
      args: [],
    );
  }

  /// `Enter your email or phone number`
  String get enterEmailOrPhone {
    return Intl.message(
      'Enter your email or phone number',
      name: 'enterEmailOrPhone',
      desc: '',
      args: [],
    );
  }

  /// `Sign in`
  String get signInButtonText {
    return Intl.message(
      'Sign in',
      name: 'signInButtonText',
      desc: '',
      args: [],
    );
  }

  /// `Not a member?`
  String get notMemberText {
    return Intl.message(
      'Not a member?',
      name: 'notMemberText',
      desc: '',
      args: [],
    );
  }

  /// `Create new account`
  String get createNewAccountText {
    return Intl.message(
      'Create new account',
      name: 'createNewAccountText',
      desc: '',
      args: [],
    );
  }

  /// `Remember me`
  String get checkboxRememberMe {
    return Intl.message(
      'Remember me',
      name: 'checkboxRememberMe',
      desc: '',
      args: [],
    );
  }

  /// `Forgot Password`
  String get linkForgotPassword {
    return Intl.message(
      'Forgot Password',
      name: 'linkForgotPassword',
      desc: '',
      args: [],
    );
  }

  /// `Email / Mobile Number`
  String get inputEmailOrMobile {
    return Intl.message(
      'Email / Mobile Number',
      name: 'inputEmailOrMobile',
      desc: '',
      args: [],
    );
  }

  /// `Password`
  String get inputPassword {
    return Intl.message('Password', name: 'inputPassword', desc: '', args: []);
  }

  /// `Forgot Password And Otp Screen`
  String get two {
    return Intl.message(
      'Forgot Password And Otp Screen',
      name: 'two',
      desc: '',
      args: [],
    );
  }

  /// `Please Enter Your E-mail / Phone Address To\nRecieve A Verification Code`
  String get forgetPasswordScreenText {
    return Intl.message(
      'Please Enter Your E-mail / Phone Address To\\nRecieve A Verification Code',
      name: 'forgetPasswordScreenText',
      desc: '',
      args: [],
    );
  }

  /// `Send Code`
  String get sendCode {
    return Intl.message('Send Code', name: 'sendCode', desc: '', args: []);
  }

  /// `Verify`
  String get verify {
    return Intl.message('Verify', name: 'verify', desc: '', args: []);
  }

  /// `Resend Code`
  String get resendCode {
    return Intl.message('Resend Code', name: 'resendCode', desc: '', args: []);
  }

  /// `Please Enter The 6 Digit Code Sent To`
  String get enter6DigitCodeText {
    return Intl.message(
      'Please Enter The 6 Digit Code Sent To',
      name: 'enter6DigitCodeText',
      desc: '',
      args: [],
    );
  }

  /// `Verify Your Phone Number`
  String get verifyPhoneNumber {
    return Intl.message(
      'Verify Your Phone Number',
      name: 'verifyPhoneNumber',
      desc: '',
      args: [],
    );
  }

  /// `Verify Your Email Address`
  String get verifyEmailAddress {
    return Intl.message(
      'Verify Your Email Address',
      name: 'verifyEmailAddress',
      desc: '',
      args: [],
    );
  }

  /// `New Password And Update Screen`
  String get three {
    return Intl.message(
      'New Password And Update Screen',
      name: 'three',
      desc: '',
      args: [],
    );
  }

  /// `I agree to the `
  String get agreeToTerms {
    return Intl.message(
      'I agree to the ',
      name: 'agreeToTerms',
      desc: '',
      args: [],
    );
  }

  /// `terms and conditions`
  String get agreeToConditions {
    return Intl.message(
      'terms and conditions',
      name: 'agreeToConditions',
      desc: '',
      args: [],
    );
  }

  /// `Passwords Match`
  String get passwordsMatch {
    return Intl.message(
      'Passwords Match',
      name: 'passwordsMatch',
      desc: '',
      args: [],
    );
  }

  /// `Passwords Do Not Match`
  String get passwordsDoNotMatch {
    return Intl.message(
      'Passwords Do Not Match',
      name: 'passwordsDoNotMatch',
      desc: '',
      args: [],
    );
  }

  /// `10 characters`
  String get passwordMinLength {
    return Intl.message(
      '10 characters',
      name: 'passwordMinLength',
      desc: '',
      args: [],
    );
  }

  /// `1 number or special character (example: # ? ! &)`
  String get passwordSpecialChar {
    return Intl.message(
      '1 number or special character (example: # ? ! &)',
      name: 'passwordSpecialChar',
      desc: '',
      args: [],
    );
  }

  /// `1 letter`
  String get passwordLetterRequirement {
    return Intl.message(
      '1 letter',
      name: 'passwordLetterRequirement',
      desc: '',
      args: [],
    );
  }

  /// `Your password must contain at least`
  String get passwordMustContain {
    return Intl.message(
      'Your password must contain at least',
      name: 'passwordMustContain',
      desc: '',
      args: [],
    );
  }

  /// `Confirm Your Password`
  String get confirmPassword {
    return Intl.message(
      'Confirm Your Password',
      name: 'confirmPassword',
      desc: '',
      args: [],
    );
  }

  /// `Password is strong`
  String get passwordStrengthStrong {
    return Intl.message(
      'Password is strong',
      name: 'passwordStrengthStrong',
      desc: '',
      args: [],
    );
  }

  /// `Weak password`
  String get passwordStrengthWeak {
    return Intl.message(
      'Weak password',
      name: 'passwordStrengthWeak',
      desc: '',
      args: [],
    );
  }

  /// `Enter your new password and make sure it is different from the previous one`
  String get newPasswordInstruction {
    return Intl.message(
      'Enter your new password and make sure it is different from the previous one',
      name: 'newPasswordInstruction',
      desc: '',
      args: [],
    );
  }

  /// `Update Password`
  String get updatePassword {
    return Intl.message(
      'Update Password',
      name: 'updatePassword',
      desc: '',
      args: [],
    );
  }

  /// `Create Password`
  String get createPassword {
    return Intl.message(
      'Create Password',
      name: 'createPassword',
      desc: '',
      args: [],
    );
  }

  /// `New Password`
  String get newPassword {
    return Intl.message(
      'New Password',
      name: 'newPassword',
      desc: '',
      args: [],
    );
  }

  /// `Update`
  String get update {
    return Intl.message('Update', name: 'update', desc: '', args: []);
  }

  /// `Enter Your Password`
  String get enterPassword {
    return Intl.message(
      'Enter Your Password',
      name: 'enterPassword',
      desc: '',
      args: [],
    );
  }

  /// `Profile Setup And Questionnaire Screen`
  String get four {
    return Intl.message(
      'Profile Setup And Questionnaire Screen',
      name: 'four',
      desc: '',
      args: [],
    );
  }

  /// `Let's setup your profile 😊`
  String get setupProfile {
    return Intl.message(
      'Let\'s setup your profile 😊',
      name: 'setupProfile',
      desc: '',
      args: [],
    );
  }

  /// `Please enter your name`
  String get pleaseEnterYourName {
    return Intl.message(
      'Please enter your name',
      name: 'pleaseEnterYourName',
      desc: '',
      args: [],
    );
  }

  /// `Select Gender`
  String get selectGender {
    return Intl.message(
      'Select Gender',
      name: 'selectGender',
      desc: '',
      args: [],
    );
  }

  /// `When’s your birthday?`
  String get birthdayPrompt {
    return Intl.message(
      'When’s your birthday?',
      name: 'birthdayPrompt',
      desc: '',
      args: [],
    );
  }

  /// `Submit`
  String get submit {
    return Intl.message('Submit', name: 'submit', desc: '', args: []);
  }

  /// `Other`
  String get other {
    return Intl.message('Other', name: 'other', desc: '', args: []);
  }

  /// `Prefer Not To Say`
  String get preferNotToSay {
    return Intl.message(
      'Prefer Not To Say',
      name: 'preferNotToSay',
      desc: '',
      args: [],
    );
  }

  /// `Male`
  String get male {
    return Intl.message('Male', name: 'male', desc: '', args: []);
  }

  /// `Female`
  String get female {
    return Intl.message('Female', name: 'female', desc: '', args: []);
  }
}

class AppLocalizationDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationDelegate();

  List<Locale> get supportedLocales {
    return const <Locale>[
      Locale.fromSubtags(languageCode: 'en'),
      Locale.fromSubtags(languageCode: 'hi'),
    ];
  }

  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<S> load(Locale locale) => S.load(locale);
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;

  bool _isSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }
}
