// import 'package:get/get_connect/http/src/response/response.dart' as http;
// import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';

// import '../../env/env.dart';
// import '../api_service.dart';

// class SleepApiService extends GetxService {
//   Future<void> uploadSleep({
//     required DateTime bed,
//     required DateTime wake,
//   }) async {
//     final payload = {
//       "Day": bed.day,
//       "Month": bed.month,
//       "Year": bed.year,
//       "SleepingFrom": "${bed.hour}:${bed.minute}",
//       "SleepingTo": "${wake.hour}:${wake.minute}",
//     };

//     final response = await ApiService.post(
//       sleepGoal,
//       payload,
//       withAuth: true,
//       encryptionRequired: true,
//     );

//     if (response is http.Response) {
//       throw Exception("Sleep upload failed");
//     }
//   }
// }
