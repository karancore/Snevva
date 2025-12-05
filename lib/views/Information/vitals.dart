import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/utils.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_appbar.dart'
    show CustomAppBar;
import 'package:snevva/Widgets/home_wrapper.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';

import '../../Controllers/Vitals/vitalsController.dart';
import '../../Widgets/Drawer/drawer_menu_wigdet.dart';
import '../../common/global_variables.dart';

void main() {
  runApp(VitalScreen());
}

class VitalScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitals App',
      themeMode: ThemeMode.system,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: VitalsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class VitalsScreen extends StatefulWidget {
  @override
  _VitalsScreenState createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
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

  Future<void> updateVitals() async {
    int? newBPM = int.tryParse(bpmController.text);
    int? newSystolic = int.tryParse(systolicController.text);
    int? newDiastolic = int.tryParse(diastolicController.text);
    int? newGlucose = int.tryParse(glucoseController.text);
    if (vitalsKey.currentState!.validate()) {
      if (newBPM != 0 &&
          newSystolic != null &&
          newDiastolic != null &&
          newGlucose != null) {
        setState(() {
          heartRate = newBPM ?? 0;
          systolic = newSystolic;
          diastolic = newDiastolic;
          bloodGlucose = newGlucose;
        });

        // ✅ Send all values to controller
        final res = _controller.submitVitals(
          BloodPressureData(
            heartRate: heartRate.toDouble(),
            sys: systolic.toDouble(),
            dia: diastolic.toDouble(),
            bloodGlucose: bloodGlucose.toDouble(),
            day: DateTime.now().day,
            month: DateTime.now().month,
            year: DateTime.now().year,
            time: TimeOfDay.now().format(context),
          ),
          context,
        );

        if (await res) {
          bpmController.clear();
          systolicController.clear();
          diastolicController.clear();
          glucoseController.clear();
          // Navigator.pop(context);
          Get.to(() => HomeWrapper(key: UniqueKey()));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please enter valid numeric values")),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    bpmController.text = heartRate.toString();
    systolicController.text = systolic.toString();
    diastolicController.text = diastolic.toString();
    glucoseController.text = bloodGlucose.toString();

    // Load BPM from local storage when the screen is initialized
    _controller.loadVitalsFromLocalStorage().then((_) {
      setState(() {
        bpmController.text = _controller.bpm.value.toString();
        systolicController.text = _controller.sys.value.toString();
        diastolicController.text = _controller.dia.value.toString();
        glucoseController.text = _controller.bloodGlucose.value.toString();
        heartRate = _controller.bpm.value;
      });
    });

    // Add a listener to bpmController to reflect real-time changes
    bpmController.addListener(() {
      setState(() {
        heartRate = int.tryParse(bpmController.text) ?? 0;
        systolic = int.tryParse(systolicController.text) ?? 0;
        diastolic = int.tryParse(diastolicController.text) ?? 0;
        bloodGlucose = int.tryParse(glucoseController.text) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    bpmController.dispose(); // Always dispose controllers
    super.dispose();
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: vitalsKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 40),

                // Heart Rate Indicator
                // Heart Rate Indicator (with editable input)
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
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: bpmController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [MaxValueTextInputFormatter(200)],
                            style: TextStyle(
                              fontSize: 48,
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              hintText: '$heartRate',
                              hintStyle: TextStyle(
                                color: textColor.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite, color: Colors.pink, size: 16),
                            SizedBox(width: 4),
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

                SizedBox(height: 40),

                // Vitals Input Card
                Container(
                  padding: EdgeInsets.all(16),
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
                    children: [
                      // Blood Pressure Input
                      Row(
                        children: [
                          Image.asset(heartVitalIcon, width: 24, height: 24),
                          SizedBox(width: 8),
                          Text(
                            'Blood Pressure:',
                            style: TextStyle(color: textColor),
                          ),
                          Spacer(),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: systolicController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              inputFormatters: [
                                MaxValueTextInputFormatter(120),
                              ],
                              decoration: InputDecoration(
                                hintText: '$systolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                ),
                                border: UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          Text('/', style: TextStyle(color: textColor)),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              controller: diastolicController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              inputFormatters: [MaxValueTextInputFormatter(80)],
                              decoration: InputDecoration(
                                hintText: '$diastolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                ),
                                border: UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          Text(' mm/Hg', style: TextStyle(color: textColor)),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Blood Glucose Input
                      Row(
                        children: [
                          Image.asset(bloodDropsIcon, width: 24, height: 24),
                          SizedBox(width: 8),
                          Text(
                            'Blood Glucose:',
                            style: TextStyle(color: textColor),
                          ),
                          Spacer(),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: glucoseController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                MaxValueTextInputFormatter(140),
                              ],
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: '$bloodGlucose',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.5),
                                ),
                                border: UnderlineInputBorder(),
                              ),
                            ),
                          ),
                          Text(' mg/dL', style: TextStyle(color: textColor)),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                // Detecting text
                // Column(
                //   children: [
                //     Text(
                //       'Detecting....',
                //       style: TextStyle(
                //         color: Colors.purpleAccent,
                //         fontSize: 18,
                //         fontWeight: FontWeight.bold,
                //       ),
                //     ),
                //     SizedBox(height: 8),
                //     Text(
                //       'Just Hold on!\nMeasuring your Vitals',
                //       textAlign: TextAlign.center,
                //       style: TextStyle(
                //         color: textColor.withOpacity(0.6),
                //         fontSize: 14,
                //       ),
                //     ),
                //   ],
                // ),
                Spacer(),

                // Enter Vitals Button
                GestureDetector(
                  onTap: updateVitals,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Center(
                      child: Text(
                        'Save Vitals',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
