import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/common/global_variables.dart';

void main() {
  group('buildDateTimeFromTimeString', () {
    test('converts UTC ISO timestamps to local time', () {
      const raw = '2026-04-15T05:03:00.000Z';

      expect(
        buildDateTimeFromTimeString(time: raw),
        DateTime.parse(raw).toLocal(),
      );
    });
  });
}
