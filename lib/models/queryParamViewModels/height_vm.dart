class HeightVM {
  final int day;
  final int month;
  final int year;
  final String time;
  final double value;

  HeightVM({
    required this.day,
    required this.month,
    required this.year,
    required this.time,
    required this.value,
  });

  @override
  String toString() {
    return 'HeightVM(day: $day, month: $month, year: $year, time: $time, value: $value)';
  }
}
