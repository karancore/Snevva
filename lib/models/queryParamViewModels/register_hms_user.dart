class RegisterHmsUser {
  final String? name;
  final String? phoneNumber;
  final String? email;

  final String? gender;

  final int? dayOfBirth;
  final int? monthOfBirth;
  final int? yearOfBirth;
  final String? birthTime;

  final String? bloodGroup;

  // ABHA details
  final String? abhaNumber;
  final String? abhaAddress;

  // Contact and address details
  final String? addressByAbha;
  final String? postalCodeByAbha;

  final String? addressByUser;
  final String? postalCodeUser;

  final String? profilePicture;
  final String? facilityCode;

  final bool? linkWithAbdm;
  final String? linkToken;

  RegisterHmsUser({
    this.name,
    this.phoneNumber,
    this.email,
    this.gender,
    this.dayOfBirth,
    this.monthOfBirth,
    this.yearOfBirth,
    this.birthTime,
    this.bloodGroup,
    this.abhaNumber,
    this.abhaAddress,
    this.addressByAbha,
    this.postalCodeByAbha,
    this.addressByUser,
    this.postalCodeUser,
    this.profilePicture,
    this.facilityCode,
    this.linkWithAbdm,
    this.linkToken,
  });
}
