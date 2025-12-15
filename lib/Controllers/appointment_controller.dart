import 'package:get/get.dart';

import '../consts/images.dart';

class AppointmentController extends GetxController {
  var selectedTab = 0.obs;

  void changeTab(int index) {
    selectedTab.value = index;
  }

  final upcomingAppointments = [
    {
      'doctorName': 'Dr. Jerry Jones',
      'specialty': 'Neuromedicine',
      'image': avatar1,
      'date': 'Monday, 17 June',
      'time': '10:00 - 11:00',
    },
    {
      'doctorName': 'Dr. Jerry Jones',
      'specialty': 'Neuromedicine',
      'image': avatar1,
      'date': 'Monday, 17 June',
      'time': '10:00 - 11:00',
    },
  ];

  final historyAppointments = [
    {
      'doctorName': 'Dr. Susan Lee',
      'specialty': 'Cardiology',
      'image': avatar2,
      'date': 'Tuesday, 4 June',
      'time': '14:00 - 15:00',
    },
    {
      'doctorName': 'Dr. Susan Lee',
      'specialty': 'Cardiology',
      'image': avatar2,
      'date': 'Tuesday, 4 June',
      'time': '14:00 - 15:00',
    },
  ];

  List<Map<String, String>> get currentAppointments =>
      selectedTab.value == 0 ? upcomingAppointments : historyAppointments;
}
