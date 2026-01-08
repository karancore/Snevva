import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart'
    show CustomAppBar;
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';

import '../../Controllers/Vitals/vitalsController.dart';
import '../../Widgets/CommonWidgets/custom_outlined_button.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/global_variables.dart';

class VitalScreen extends StatefulWidget {
  const VitalScreen({super.key});
  @override
  State<VitalScreen> createState() => _VitalScreenState();
}

class _VitalScreenState extends State<VitalScreen> {
  int heartRate = 73;
  int systolic = 120;
  int diastolic = 80;
  int bloodGlucose = 93;

  final TextEditingController systolicController = TextEditingController();
  final TextEditingController diastolicController = TextEditingController();
  final TextEditingController glucoseController = TextEditingController();
  final TextEditingController bpmController = TextEditingController();
  final vitalsKey = GlobalKey<FormState>();

  final _controller = Get.find<VitalsController>();

  @override
  void initState() {
    super.initState();
    toggleVitalsCard();

    if (_controller.bpm.value > 0) {
      bpmController.text = _controller.bpm.value.toString();
    }
    if (_controller.sys.value > 0) {
      systolicController.text = _controller.sys.value.toString();
    }

    if (_controller.dia.value > 0) {
      diastolicController.text = _controller.dia.value.toString();
    }

    if (_controller.bloodGlucose.value > 0) {
      glucoseController.text = _controller.bloodGlucose.value.toString();
    }

    //bpmController.text = heartRate.toString();
    // systolicController.text = systolic.toString();
    // diastolicController.text = diastolic.toString();
    // glucoseController.text = bloodGlucose.toString();

    _controller.loadVitalsFromLocalStorage().then((_) {
      setState(() {
        //bpmController.text = _controller.bpm.value.toString();
        if (_controller.bpm.value > 0) {
          bpmController.text = _controller.bpm.value.toString();
        }

        if (_controller.sys.value > 0) {
          systolicController.text = _controller.sys.value.toString();
        }

        if (_controller.dia.value > 0) {
          diastolicController.text = _controller.dia.value.toString();
        }
        if (_controller.bloodGlucose.value > 0) {
          glucoseController.text = _controller.bloodGlucose.value.toString();
        }
        heartRate = _controller.bpm.value;
      });
    });

    bpmController.addListener(() {
      setState(() {
        final parsed = int.tryParse(bpmController.text);
        if (parsed != null) {
          heartRate = parsed;
        }
        // heartRate = int.tryParse(bpmController.text) ?? 0;
        // systolic = int.tryParse(systolicController.text) ?? 0;
        // diastolic = int.tryParse(diastolicController.text) ?? 0;
        // bloodGlucose = int.tryParse(glucoseController.text) ?? 0;

        if (_controller.sys.value > 0) {
          systolicController.text = _controller.sys.value.toString();
        }

        if (_controller.dia.value > 0) {
          diastolicController.text = _controller.dia.value.toString();
        }

        if (_controller.bloodGlucose.value > 0) {
          glucoseController.text = _controller.bloodGlucose.value.toString();
        }
      });
    });
  }

  @override
  void dispose() {
    bpmController.dispose();
    systolicController.dispose();
    diastolicController.dispose();
    glucoseController.dispose();
    super.dispose();
  }

  Future<void> toggleVitalsCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', false);
  }

  void updateVitals() {
    List<String> missingFields = [];

    int bpm = int.tryParse(bpmController.text.trim()) ?? 0;
    int sys = int.tryParse(systolicController.text.trim()) ?? 0;
    int dia = int.tryParse(diastolicController.text.trim()) ?? 0;
    int glucose = int.tryParse(glucoseController.text.trim()) ?? 0;

    if (bpm <= 0) missingFields.add("Heart Rate (BPM)");
    if (sys <= 0) missingFields.add("Systolic (SYS)");
    if (dia <= 0) missingFields.add("Diastolic (DIA)");
    if (glucose <= 0) missingFields.add("Blood Glucose");

    if (missingFields.isNotEmpty) {
      CustomSnackbar.showError(
        context: context,
        title: "Missing Information",
        message: "Please enter:\n• ${missingFields.join("\n• ")}",
      );
      return;
    }

    final result = _controller.submitVitals(
      BloodPressureData(
        heartRate: bpm!.toDouble(),
        sys: sys!.toDouble(),
        dia: dia!.toDouble(),
        bloodGlucose: glucose!.toDouble(),
        day: DateTime.now().day,
        month: DateTime.now().month,
        year: DateTime.now().year,
        time: DateTime.now().toIso8601String(),
      ),
      context,
    );

    if (result != null) {
      result.then((success) {
        if (success) {
          bpmController.clear();
          systolicController.clear();
          diastolicController.clear();
          glucoseController.clear();
          Get.to(() => HomeWrapper(key: UniqueKey()));
        }
      });
    }
  }

  // Future<void> updateVitals() async {
  //   int? newBPM = int.tryParse(bpmController.text);
  //   int? newSystolic = int.tryParse(systolicController.text);
  //   int? newDiastolic = int.tryParse(diastolicController.text);
  //   int? newGlucose = int.tryParse(glucoseController.text);
  //
  //   showMissingFieldsSnackbar(context);
  //
  //   if (vitalsKey.currentState!.validate()) {
  //     if (newBPM != 0 &&
  //         newSystolic != null &&
  //         newDiastolic != null &&
  //         newGlucose != null) {
  //       setState(() {
  //         heartRate = newBPM ?? 72;
  //         systolic = newSystolic;
  //         diastolic = newDiastolic;
  //         bloodGlucose = newGlucose;
  //       });
  //
  //       if (isValidVitals(
  //         bpm: newBPM!,
  //         sys: newSystolic!,
  //         dia: newDiastolic!,
  //         glucose: newGlucose!,
  //       )) {
  //         final res = _controller.submitVitals(
  //           BloodPressureData(
  //             heartRate: heartRate.toDouble(),
  //             sys: systolic.toDouble(),
  //             dia: diastolic.toDouble(),
  //             bloodGlucose: bloodGlucose.toDouble(),
  //             day: DateTime.now().day,
  //             month: DateTime.now().month,
  //             year: DateTime.now().year,
  //             time: TimeOfDay.now().format(context),
  //           ),
  //           context,
  //         );
  //         if (await res) {
  //           bpmController.clear();
  //           systolicController.clear();
  //           diastolicController.clear();
  //           glucoseController.clear();
  //           Get.to(() => HomeWrapper(key: UniqueKey()));
  //         }
  //       }
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Please enter valid numeric values")),
  //       );
  //     }
  //   }
  // }

  void showMissingFieldsSnackbar(BuildContext context) {
    List<String> missingFields = [];

    if (bpmController.text.trim().isEmpty) {
      missingFields.add("Heart Rate (BPM)");
    }

    if (systolicController.text.trim().isEmpty ||
        diastolicController.text.trim().isEmpty) {
      missingFields.add("Blood Pressure");
    }

    if (glucoseController.text.trim().isEmpty) {
      missingFields.add("Blood Glucose");
    }

    if (missingFields.isEmpty) return;

    CustomSnackbar.showError(
      context: context,
      title: "Missing Information",
      message: "Please enter:\n• ${missingFields.join("\n• ")}",
    );
  }

  bool isValidVitals({
    required int bpm,
    required int sys,
    required int dia,
    required int glucose,
  }) {
    return bpm >= 40 &&
        bpm <= 200 &&
        sys >= 90 &&
        sys <= 200 &&
        dia >= 60 &&
        dia <= 120 &&
        glucose >= 70 &&
        glucose <= 300;
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height;
    final width = mediaQuery.size.width;

    return Scaffold(
      drawer: Drawer(child: DrawerMenuWidget(height: height, width: width)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: CustomOutlinedButton(
            width: double.infinity,
            isDarkMode: isDarkMode,
            backgroundColor: AppColors.primaryColor,
            buttonName: 'Save Vitals',
            onTap: updateVitals,
          ),
        ),
      ),
      appBar: CustomAppBar(
        appbarText: "Vitals",
        onClose: () {
          if (Get.isSnackbarOpen) {
            Get.closeCurrentSnackbar();
          }
          Get.back();
        },
      ),
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: vitalsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Heart Rate Indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: ((int.tryParse(bpmController.text) ?? 0) / 200)
                            .clamp(0.0, 1.0),
                        strokeWidth: 15,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                        backgroundColor: Colors.grey.shade800,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: bpmController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [MaxValueTextInputFormatter(120)],
                            style: TextStyle(
                              fontSize: 44,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: heartRate > 0 ? '$heartRate' : '72',
                              hintStyle: TextStyle(
                                color: textColor.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,

                              isDense: true,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite, color: Colors.pink, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'BPM',
                              style: TextStyle(
                                color: textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Vitals Input Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.transparent : Colors.black12,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Blood Pressure Input
                      Row(
                        children: [
                          Image.asset(heartVitalIcon, width: 24, height: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Blood Pressure:',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 45,
                            child: TextFormField(
                              controller: systolicController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 14),
                              inputFormatters: [
                                MaxValueTextInputFormatter(120),
                              ],
                              decoration: InputDecoration(
                                hintText: '$systolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Text('/', style: TextStyle(color: textColor)),
                          SizedBox(
                            width: 45,
                            child: TextFormField(
                              controller: diastolicController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 14),
                              inputFormatters: [MaxValueTextInputFormatter(80)],
                              decoration: InputDecoration(
                                hintText: '$diastolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Text(
                            ' mm/Hg',
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Blood Glucose Input
                      Row(
                        children: [
                          Image.asset(bloodDropsIcon, width: 24, height: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Blood Glucose:',
                              style: TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: glucoseController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                MaxValueTextInputFormatter(140),
                              ],
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '$bloodGlucose',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Text(
                            ' mg/dL',
                            style: TextStyle(color: textColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
