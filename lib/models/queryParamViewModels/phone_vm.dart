class PhoneVM {
  final String phoneNumber;
  final String? otp;
  final bool? isVerified;
  final String? password;

  PhoneVM({
    required this.phoneNumber,
    this.otp,
    this.isVerified,
    this.password,
  });
}

