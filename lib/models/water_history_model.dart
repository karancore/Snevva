import 'package:get/get.dart';

class WaterHistoryModel {
  int? id;
  int day;
  int month;
  int year;
  String? time;
  int? value; // ML
  RxBool isChecked; // Similar to the C# `IsChecked` (Reactive in Flutter)

  // Constructor with optional `isChecked` flag
  WaterHistoryModel({
    this.id,
    required this.day,
    required this.month,
    required this.year,
    this.time,
    this.value,
    bool checked = false,
  }) : isChecked = checked.obs; // Reactive `isChecked`

  // Factory method to create an instance from a JSON object (similar to C#'s `FromJson`)
  factory WaterHistoryModel.fromJson(Map<String, dynamic> item) {
    return WaterHistoryModel(
      id: item['Id'], // Assuming the JSON key is 'Id'
      day: item['Day'], // Assuming the JSON key is 'Day'
      month: item['Month'], // Assuming the JSON key is 'Month'
      year: item['Year'], // Assuming the JSON key is 'Year'
      time: item['Time'], // Assuming the JSON key is 'Time'
      value: item['Value'], // Assuming the JSON key is 'Value' (ML)
      checked: false, // Default to unchecked
    );
  }

  // ToString method for a similar representation as in C#
  @override
  String toString() {
    return '$value ml at $time';
  }
}
