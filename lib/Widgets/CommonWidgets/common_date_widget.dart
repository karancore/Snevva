import 'package:intl/intl.dart';
import 'package:scroll_datetime_picker/scroll_datetime_picker.dart';
import '../../consts/consts.dart';

class CommonDateWidget extends StatefulWidget {
  const CommonDateWidget({
    super.key,
    required this.width,
    required this.isDarkMode,
    this.isPeriodScreen = false,
    required this.setDate,
    this.initialDate,
  });

  final double width;
  final bool isDarkMode;
  final bool? isPeriodScreen;
  final void Function(DateTime date) setDate;
  final DateTime? initialDate;

  @override
  State<CommonDateWidget> createState() => _CommonDateWidgetState();
}

class _CommonDateWidgetState extends State<CommonDateWidget> {
  late DateTime selectedDate;
  final controller = DateTimePickerController();

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate ?? DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -10),
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            // Align(
            //   alignment: Alignment.topCenter,
            //   child: Padding(
            //     padding: const EdgeInsets.only(top: 8.0),
            //     child: Text(
            //       DateFormat('dd/MM/yyyy').format(selectedDate),
            //       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            //     ),
            //   ),
            // ),
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (_) => _dateBox()),
                ),
              ),
            ),
            ScrollDateTimePicker(
              controller: controller,
              itemExtent: 54,
              infiniteScroll: false,
              dateOption: DateTimePickerOption(
                dateFormat: DateFormat('dd MMM yyyy'),
                minDate: DateTime(1900),
                maxDate: DateTime(2030),
                initialDate: selectedDate,
              ),
              onChange: (newDate) {
                setState(() => selectedDate = newDate);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.setDate(newDate);
                });
              },
              style: DateTimePickerStyle(
                activeDecoration: BoxDecoration(color: Colors.transparent),

                activeStyle: TextStyle(fontSize: 16, color: Colors.white),
                inactiveStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
                disabledStyle: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              wheelOption: const DateTimePickerWheelOption(
                diameterRatio: 5,
                squeeze: 1.5,
                perspective: 0.01,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBox() {
    return Material(
      borderRadius: BorderRadius.circular(4),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 44.0,
        width: widget.width / 4,
        decoration: BoxDecoration(
          border: Border.all(width: 1, color: white),
          borderRadius: BorderRadius.circular(4),
          color: AppColors.primaryColor,
        ),
      ),
    );
  }
}
