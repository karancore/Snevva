// import 'package:flutter/material.dart';
// import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
//
// Widget _medicineFrequencyFields() {
//   return Obx(() {
//     final selected = medicineGetxController.medicineReminderOption.value;
//
//     final timesSelected = selected == Option.times;
//     final intervalSelected = selected == Option.interval;
//
//     if (medicineGetxController.selectedFrequency.value == 'Custom') {
//       medicineGetxController.timesPerDayController.text = 4.toString();
//       medicineGetxController.everyHourController.text = 4.toString();
//     }
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         /// -------- TIMES PER DAY --------
//         Wrap(
//           spacing: 8,
//           crossAxisAlignment: WrapCrossAlignment.center,
//           children: [
//             Theme(
//               data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
//               child: Radio<Option>(
//                 value: Option.times,
//                 groupValue: selected,
//                 activeColor: black,
//                 onChanged: (value) {
//                   medicineGetxController.medicineReminderOption.value =
//                   value!;
//                 },
//               ),
//             ),
//             _greyText("Remind me", timesSelected),
//             SizedBox(
//               width: 36,
//               child: TextField(
//                 controller: medicineGetxController.timesPerDayController,
//                 enabled: timesSelected,
//                 keyboardType: TextInputType.number,
//                 style: TextStyle(color: timesSelected ? black : grey),
//                 decoration: const InputDecoration(
//                   isDense: true,
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                 ),
//               ),
//             ),
//             _greyText("times a day", timesSelected),
//           ],
//         ),
//
//         const SizedBox(height: 8),
//
//         /// -------- INTERVAL --------
//         Wrap(
//           spacing: 8,
//           crossAxisAlignment: WrapCrossAlignment.center,
//           children: [
//             Theme(
//               data: Theme.of(context).copyWith(unselectedWidgetColor: grey),
//               child: Radio<Option>(
//                 value: Option.interval,
//                 groupValue: selected,
//                 activeColor: black,
//                 onChanged: (value) {
//                   medicineGetxController.medicineReminderOption.value =
//                   value!;
//                 },
//               ),
//             ),
//             _greyText("Remind me every", intervalSelected),
//             SizedBox(
//               width: 36,
//               child: TextField(
//                 controller: medicineGetxController.everyHourController,
//                 enabled: intervalSelected,
//                 keyboardType: TextInputType.number,
//                 style: TextStyle(color: intervalSelected ? black : grey),
//                 decoration: const InputDecoration(
//                   isDense: true,
//                   contentPadding: EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                 ),
//               ),
//             ),
//             _greyText("hours a day", intervalSelected),
//           ],
//         ),
//       ],
//     );
//   });
// }
