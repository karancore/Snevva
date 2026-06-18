import 'package:flutter_test/flutter_test.dart';
import 'package:snevva/models/alerts.dart';

void main() {
  group('AlertsResponse.fromJson', () {
    test('parses push notifications from API response casing', () {
      final response = AlertsResponse.fromJson({
        'status': true,
        'statusType': 'success',
        'message': 'Create Success',
        'data': {
          'PatientCode': '64962d72-eab1-442f-96c0-883e49c93a20',
          'PushNotifications': [
            {
              'Id': 3,
              'DataCode': 'c4d6d36c-d5af-4468-a6b0-1a4fbf528a7b',
              'Heading': 'Elly AI ',
              'Title': 'Our personal AI is coming soon on your devices.',
              'Tags': ['Male', 'Age 13 to 18'],
              'Type': 'alert',
              'Time': ['12:01', '13:01'],
              'IsActive': true,
            },
          ],
        },
      });

      final alert = response.alerts.single;

      expect(alert.dataCode, 'c4d6d36c-d5af-4468-a6b0-1a4fbf528a7b');
      expect(alert.heading, 'Elly AI ');
      expect(alert.title, 'Our personal AI is coming soon on your devices.');
      expect(alert.times, ['12:01', '13:01']);
      expect(alert.isActive, isTrue);
    });

    test('keeps support for lower camel case response keys', () {
      final response = AlertsResponse.fromJson({
        'data': {
          'pushNotifications': [
            {
              'dataCode': 'code-1',
              'heading': 'Heading',
              'title': 'Title',
              'time': ['08:00'],
              'isActive': true,
            },
          ],
        },
      });

      expect(response.alerts.single.dataCode, 'code-1');
    });
  });
}
