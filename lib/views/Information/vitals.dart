import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snevva/common/custom_snackbar.dart';
import 'package:snevva/consts/consts.dart';
import 'package:snevva/models/queryParamViewModels/bloodpressure.dart';
import 'package:snevva/views/information/bmi_status.dart';

import '../../Controllers/Vitals/vitalsController.dart';
import '../../common/global_variables.dart';
import '../../widgets/CommonWidgets/custom_appbar.dart';
import '../../widgets/CommonWidgets/custom_outlined_button.dart';
import '../../widgets/Drawer/drawer_menu_wigdet.dart';

// ✅ SEPARATE WIDGET — Flutter never destroys this, focus is permanent
class BpmInputWidget extends StatefulWidget {
  final TextEditingController bpmController;
  final double scale;

  const BpmInputWidget({
    super.key,
    required this.bpmController,
    required this.scale,
  });

  @override
  State<BpmInputWidget> createState() => _BpmInputWidgetState();
}

class _BpmInputWidgetState extends State<BpmInputWidget> {
  // ✅ FocusNode lives HERE — in its own stable state, never recreated
  final FocusNode _bpmFocusNode = FocusNode();

  @override
  void dispose() {
    _bpmFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;
    double scale = widget.scale;

    return GestureDetector(
      onTap: () => _bpmFocusNode.requestFocus(),
      child: Container(
        height: 188 * scale,
        width: 188 * scale,
        decoration: BoxDecoration(
          color: isDarkMode ? black : white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.08),
              offset: const Offset(0, 0),
              blurRadius: 8,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 69 * scale,
                    height: 57 * scale,
                    child: TextFormField(
                      focusNode: _bpmFocusNode,
                      controller: widget.bpmController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [MaxValueTextInputFormatter(200)],
                      style: TextStyle(
                        fontSize: 44,
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '--',
                        hintStyle: TextStyle(
                          color: textColor.withOpacity(0.3),
                          fontSize: 56,
                          fontWeight: FontWeight.w600,
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
                  Column(
                    children: [
                      // ✅ Tapping image also focuses the field
                      GestureDetector(
                        onTap: () => _bpmFocusNode.requestFocus(),
                        child: Image.asset(strokeAndHeart),
                      ),
                      Text(
                        'BPM',
                        style: TextStyle(
                          color: Color(0xff878787),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable: widget.bpmController,
                    builder: (context, value, child) {
                      final hasData =
                          widget.bpmController.text
                              .trim()
                              .isNotEmpty;

                      final bpmStatus = getBpmStatus(
                        int.tryParse(widget.bpmController.text) ?? 0,
                      );

                      return Text(
                        hasData ? bpmStatus.label : "Enter BPM",
                        style: TextStyle(
                            color: hasData
                                ? bpmStatus.color
                                : textColor.withOpacity(0.4),
                            fontSize: 20,
                            fontWeight: FontWeight.w500

                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                  SvgPicture.asset(editIcon, height: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class VitalScreen extends StatefulWidget {
  const VitalScreen({super.key});

  @override
  State<VitalScreen> createState() => _VitalScreenState();
}

class _VitalScreenState extends State<VitalScreen> {
  final ValueNotifier<int> heartRateNotifier = ValueNotifier<int>(0);

  int systolic = 120;
  int diastolic = 80;
  int bloodGlucose = 93;

  final TextEditingController systolicController = TextEditingController();
  final TextEditingController diastolicController = TextEditingController();
  final TextEditingController glucoseController = TextEditingController();
  final TextEditingController bpmController = TextEditingController();

  static const bpmMax = 200;
  static const sysMax = 200;
  static const diaMax = 120;
  static const glucoseMax = 300;

  final vitalsKey = GlobalKey<FormState>();
  final _controller = Get.put(VitalsController());

  @override
  void initState() {
    super.initState();
    toggleVitalsCard();

    if (_controller.bpm.value > 0) {
      bpmController.text = _controller.bpm.value.toString();
      heartRateNotifier.value = _controller.bpm.value;
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

    _controller.loadVitalsFromLocalStorage().then((_) {
      if (!mounted) return;
      if (_controller.bpm.value > 0) {
        bpmController.text = _controller.bpm.value.toString();
        heartRateNotifier.value = _controller.bpm.value;
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
    });

    bpmController.addListener(() {
      final parsed = int.tryParse(bpmController.text);
      if (parsed != null) {
        heartRateNotifier.value = parsed;
      }
    });
  }

  @override
  void dispose() {
    heartRateNotifier.dispose();
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
        heartRate: bpm.toDouble(),
        sys: sys.toDouble(),
        dia: dia.toDouble(),
        bloodGlucose: glucose.toDouble(),
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
          Get.until((route) => route.isFirst);
        }
      });
    }
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
    double screenWidth = mediaQuery.size.width;
    double scale = screenWidth / 360;

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
          if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
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

                Stack(
                  alignment: Alignment.center,
                  children: [
                    // ✅ Only ring rebuilds
                    ValueListenableBuilder<int>(
                      valueListenable: heartRateNotifier,
                      builder: (context, heartRate, _) {
                        final bpmStatus = getBpmStatus(heartRate);
                        return SizedBox(
                          width: 260 * scale,
                          height: 260 * scale,
                          child: CircularProgressIndicator(
                            value: (heartRate / 200).clamp(0.0, 1.0),
                            strokeWidth: 25 * scale,
                            strokeCap: StrokeCap.round,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              bpmStatus.color,
                            ),
                            backgroundColor: bpmStatus.color.withOpacity(0.05),
                          ),
                        );
                      },
                    ),

                    // ✅ Proper widget — Flutter NEVER recreates it
                    BpmInputWidget(
                      key: const ValueKey('bpm_input'),
                      bpmController: bpmController,
                      scale: scale,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                        isDarkMode ? Colors.transparent : Colors.black12,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Image.asset(heartVitalIcon, width: 24, height: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Blood Pressure:',
                              style:
                              TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 45,
                            child: TextFormField(
                              controller: systolicController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style:
                              TextStyle(color: textColor, fontSize: 14),
                              inputFormatters: [
                                MaxValueTextInputFormatter(200),
                              ],
                              decoration: InputDecoration(
                                hintText: '$systolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.3),
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
                          ListenableBuilder(
                            listenable: Listenable.merge([
                              systolicController,
                              diastolicController,
                            ]),
                            builder: (context, child) {
                              final hasData =
                                  systolicController.text
                                      .trim()
                                      .isNotEmpty &&
                                      diastolicController.text
                                          .trim()
                                          .isNotEmpty;
                              return Text(
                                '/',
                                style: TextStyle(
                                  color: hasData
                                      ? (isDarkMode
                                      ? Colors.white
                                      : Colors.black)
                                      : textColor.withOpacity(0.4),
                                ),
                              );
                            },
                          ),
                          SizedBox(
                            width: 45,
                            child: TextFormField(
                              controller: diastolicController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style:
                              TextStyle(color: textColor, fontSize: 14),
                              inputFormatters: [
                                MaxValueTextInputFormatter(120),
                              ],
                              decoration: InputDecoration(
                                hintText: '$diastolic',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.3),
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
                      Row(
                        children: [
                          Image.asset(bloodDropsIcon, width: 24, height: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Blood Glucose:',
                              style:
                              TextStyle(color: textColor, fontSize: 13),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: TextFormField(
                              controller: glucoseController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              inputFormatters: [
                                MaxValueTextInputFormatter(300),
                              ],
                              style:
                              TextStyle(color: textColor, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: '$bloodGlucose',
                                hintStyle: TextStyle(
                                  color: textColor.withOpacity(0.3),
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