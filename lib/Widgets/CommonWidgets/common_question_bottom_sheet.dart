import 'package:flutter_svg/flutter_svg.dart';
import 'package:snevva/Widgets/CommonWidgets/custom_outlined_button.dart';
import 'package:snevva/Widgets/CommonWidgets/common_date_widget.dart';
import 'package:snevva/consts/consts.dart';
import 'package:wheel_picker/wheel_picker.dart';

class CommonQuestionBottomSheet extends StatefulWidget {
  final WheelPickerController wheel;
  final bool isDarkMode;
  final double width;
  final double topPosition;
  final String questionHeading;
  final String unit;
  final String img;
  final bool? isDatePickerReq;
  final String questionSubHeading;
  final VoidCallback onNext;
  final bool? rightPadReq;
  final bool? isSizedBoxReq;
  final void Function(DateTime date)? setDate;
  final void Function(String day)? setDay;

  const CommonQuestionBottomSheet({
    super.key,
    required this.wheel,
    required this.isDarkMode,
    required this.width,
    required this.questionHeading,
    required this.questionSubHeading,
    required this.onNext,
    this.isDatePickerReq = false,
    required this.img,
    required this.unit,
    this.rightPadReq = false,
    required this.topPosition,
    this.setDate,
    this.setDay,
    this.isSizedBoxReq = false,
  });

  @override
  State<CommonQuestionBottomSheet> createState() =>
      _CommonQuestionBottomSheetState();
}

class _CommonQuestionBottomSheetState extends State<CommonQuestionBottomSheet> {
  @override
  Widget build(BuildContext context) {
    // Directly return the Stack.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.isSizedBoxReq!
              ? widget.width > 800
                  ? SizedBox(height: 100)
                  : SizedBox.shrink()
              : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.only(top: 0),
            child: Stack(
              alignment: AlignmentDirectional.bottomEnd,
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 100),
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 60,
                    bottom: 20,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode ? darkGray : scaffoldColorLight,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    // Essential for content-based height
                    children: [
                      AutoSizeText(
                        widget.questionHeading,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        minFontSize: 16,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.questionSubHeading,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mediumGrey,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Wheel and overlay
                      Transform.translate(
                        offset: Offset(0, -5),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              margin: EdgeInsets.only(bottom: 12),
                              height: 30,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color:
                                    widget.isDatePickerReq!
                                        ? Colors.transparent
                                        : mediumGrey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Text(
                                  widget.isDatePickerReq! ? "" : widget.unit,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  widget.isDatePickerReq!
                                      ? Flexible(
                                        flex: 1,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 30,
                                          ),
                                          child: CommonDateWidget(
                                            width: widget.width,
                                            isDarkMode: widget.isDarkMode,
                                            isPeriodScreen: true,
                                            setDate: widget.setDate!,
                                          ),
                                        ),
                                      )
                                      : Flexible(
                                        flex: 1,
                                        child: WheelPicker(
                                          builder:
                                              (context, index) => Text(
                                                widget.rightPadReq!
                                                    ? "${(index + 1) * 1000}"
                                                    : "${index + 1}",
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                              ),
                                          controller: widget.wheel,
                                          onIndexChanged: (index, _) {
                                            setState(() {
                                              if (widget.setDay != null) {
                                                widget.setDay!(
                                                  (index + 1).toString(),
                                                );
                                              }
                                            });
                                          },

                                          looping: false,
                                          selectedIndexColor:
                                              widget.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black,
                                          style: const WheelPickerStyle(
                                            itemExtent: 30,
                                            squeeze: 1.25,
                                            diameterRatio: 0.8,
                                            surroundingOpacity: 0.25,
                                            magnification: 1.3,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SafeArea(
                        child: CustomOutlinedButton(
                          width: widget.width,
                          isDarkMode: widget.isDarkMode,
                          backgroundColor: AppColors.primaryColor,
                          buttonName: "Next",
                          onTap: widget.onNext,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: widget.topPosition,
                  left: 0,
                  right: 0,
                  child: SvgPicture.asset(widget.img, height: 150, width: 150),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
