class UserProfileVM {
  final String? PatientCode;
  String? Name;
  final String? PhoneNumber;
  final String? Email;
  final String? Gender;
  final int? DayOfBirth;
  final int? MonthOfBirth;
  final int? YearOfBirth;
  final String? PostalCodeUser;
  final String? AddressByUser;
  final String? ProfilePicture;
  final Object? OccupationData;

  UserProfileVM({
    this.PatientCode,
    this.Name,
    this.PhoneNumber,
    this.Email,
    this.Gender,
    this.DayOfBirth,
    this.MonthOfBirth,
    this.YearOfBirth,
    this.PostalCodeUser,
    this.AddressByUser,
    this.ProfilePicture,
    this.OccupationData,
  });
}
