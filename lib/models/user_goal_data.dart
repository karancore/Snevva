class UserGoalData {
  final String patientCode;
  final HeightData? heightData;
  final WeightData? weightData;
  final SleepGoalData? sleepGoalData;
  final StepGoalData? stepGoalData;
  final WaterGoalData? waterGoalData;
  final HobbiesData? hobbiesData;
  final UsingAppData? usingAppData;
  final bool? trackWomenData;
  final dynamic dietPlanData;
  final String? activityLevel;
  final String? healthGoal;

  UserGoalData({
    required this.patientCode,
    this.heightData,
    this.weightData,
    this.sleepGoalData,
    this.stepGoalData,
    this.waterGoalData,
    this.hobbiesData,
    this.usingAppData,
    this.trackWomenData,
    this.dietPlanData,
    this.activityLevel,
    this.healthGoal,
  });

  factory UserGoalData.fromJson(Map<String, dynamic> json) {
    return UserGoalData(
      patientCode: json['PatientCode'],
      heightData:
          json['HeightData'] != null
              ? HeightData.fromJson(json['HeightData'])
              : null,
      weightData:
          json['WeightData'] != null
              ? WeightData.fromJson(json['WeightData'])
              : null,
      sleepGoalData:
          json['SleepGoalData'] != null
              ? SleepGoalData.fromJson(json['SleepGoalData'])
              : null,
      stepGoalData:
          json['StepGoalData'] != null
              ? StepGoalData.fromJson(json['StepGoalData'])
              : null,
      waterGoalData:
          json['WaterGoalData'] != null
              ? WaterGoalData.fromJson(json['WaterGoalData'])
              : null,
      hobbiesData:
          json['HobbiesData'] != null
              ? HobbiesData.fromJson(json['HobbiesData'])
              : null,
      usingAppData:
          json['UsingAppData'] != null
              ? UsingAppData.fromJson(json['UsingAppData'])
              : null,
      trackWomenData: json['TrackWomenData'],
      dietPlanData: json['DietPlanData'],
      activityLevel: json['ActivityLevel'],
      healthGoal: json['HealthGoal'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "PatientCode": patientCode,
      "HeightData": heightData?.toJson(),
      "WeightData": weightData?.toJson(),
      "SleepGoalData": sleepGoalData?.toJson(),
      "StepGoalData": stepGoalData?.toJson(),
      "WaterGoalData": waterGoalData?.toJson(),
      "HobbiesData": hobbiesData?.toJson(),
      "UsingAppData": usingAppData?.toJson(),
      "TrackWomenData": trackWomenData,
      "DietPlanData": dietPlanData,
      "ActivityLevel": activityLevel,
      "HealthGoal": healthGoal,
    };
  }
}

class HeightData {
  final int id;
  final int day;
  final int month;
  final int year;
  final String time;
  final int value;
  final bool isCurrent;

  HeightData({
    required this.id,
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.value,
    required this.isCurrent,
  });

  factory HeightData.fromJson(Map<String, dynamic> json) {
    return HeightData(
      id: json['Id'],
      day: json['Day'],
      month: json['Month'],
      year: json['Year'],
      time: json['Time'],
      value: json['Value'],
      isCurrent: json['IsCurrent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "Day": day,
      "Month": month,
      "Year": year,
      "Time": time,
      "Value": value,
      "IsCurrent": isCurrent,
    };
  }
}

class WeightData extends HeightData {
  WeightData({
    required super.id,
    required super.day,
    required super.month,
    required super.year,
    required super.time,
    required super.value,
    required super.isCurrent,
  });

  factory WeightData.fromJson(Map<String, dynamic> json) {
    return WeightData(
      id: json['Id'],
      day: json['Day'],
      month: json['Month'],
      year: json['Year'],
      time: json['Time'],
      value: json['Value'],
      isCurrent: json['IsCurrent'],
    );
  }
}

class SleepGoalData {
  final int id;
  final int day;
  final int month;
  final int year;
  final String time;
  final String sleepingFrom;
  final String sleepingTo;
  final bool isCurrent;

  SleepGoalData({
    required this.id,
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.sleepingFrom,
    required this.sleepingTo,
    required this.isCurrent,
  });

  factory SleepGoalData.fromJson(Map<String, dynamic> json) {
    return SleepGoalData(
      id: json['Id'],
      day: json['Day'],
      month: json['Month'],
      year: json['Year'],
      time: json['Time'],
      sleepingFrom: json['SleepingFrom'],
      sleepingTo: json['SleepingTo'],
      isCurrent: json['IsCurrent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "Day": day,
      "Month": month,
      "Year": year,
      "Time": time,
      "SleepingFrom": sleepingFrom,
      "SleepingTo": sleepingTo,
      "IsCurrent": isCurrent,
    };
  }
}

class StepGoalData {
  final int id;
  final int day;
  final int month;
  final int year;
  final String time;
  final int count;
  final bool isCurrent;

  StepGoalData({
    required this.id,
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.count,
    required this.isCurrent,
  });

  factory StepGoalData.fromJson(Map<String, dynamic> json) {
    return StepGoalData(
      id: json['Id'],
      day: json['Day'],
      month: json['Month'],
      year: json['Year'],
      time: json['Time'],
      count: json['Count'],
      isCurrent: json['IsCurrent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "Day": day,
      "Month": month,
      "Year": year,
      "Time": time,
      "Count": count,
      "IsCurrent": isCurrent,
    };
  }
}

class WaterGoalData {
  final int id;
  final int day;
  final int month;
  final int year;
  final String time;
  final int value;
  final bool isCurrent;

  WaterGoalData({
    required this.id,
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.value,
    required this.isCurrent,
  });

  factory WaterGoalData.fromJson(Map<String, dynamic> json) {
    return WaterGoalData(
      id: json['Id'],
      day: json['Day'],
      month: json['Month'],
      year: json['Year'],
      time: json['Time'],
      value: json['Value'],
      isCurrent: json['IsCurrent'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "Day": day,
      "Month": month,
      "Year": year,
      "Time": time,
      "Value": value,
      "IsCurrent": isCurrent,
    };
  }
}

class HobbiesData {
  final List<String> hobbies;

  HobbiesData({required this.hobbies});

  factory HobbiesData.fromJson(Map<String, dynamic> json) {
    return HobbiesData(hobbies: List<String>.from(json['Hobbies']));
  }

  Map<String, dynamic> toJson() {
    return {"Hobbies": hobbies};
  }
}

class UsingAppData {
  final List<String> goals;

  UsingAppData({required this.goals});

  factory UsingAppData.fromJson(Map<String, dynamic> json) {
    return UsingAppData(goals: List<String>.from(json['Goals']));
  }

  Map<String, dynamic> toJson() {
    return {"Goals": goals};
  }
}
