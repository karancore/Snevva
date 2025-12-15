class WeightVM {
  final int day;
  final int month;
  final int year;
  final String time;
  final double value;

  WeightVM({
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.value,
  });

  @override
  String toString() {
    return 'WeightVM(day: $day, month: $month, year: $year, time: $time, value: $value)';
  }
}
