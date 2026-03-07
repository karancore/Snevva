import 'package:snevva/consts/consts.dart';
import 'package:wheel_picker/wheel_picker.dart';

class TimeWheelPicker extends StatefulWidget {
  const TimeWheelPicker({
    super.key,
    required this.hourController,
    required this.minuteController,
    required this.periodController,
    this.height = 220,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.borderRadius = 20,
    this.wheelStyle = const WheelPickerStyle(
      itemExtent: 44,
      squeeze: 1.05,
      diameterRatio: 1.08,
      surroundingOpacity: 0.35,
      magnification: 1.18,
      shiftAnimationStyle: WheelShiftAnimationStyle(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    ),
  });

  final WheelPickerController hourController;
  final WheelPickerController minuteController;
  final WheelPickerController periodController;
  final double height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final WheelPickerStyle wheelStyle;

  @override
  State<TimeWheelPicker> createState() => _TimeWheelPickerState();
}

class _TimeWheelPickerState extends State<TimeWheelPicker> {
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedPeriod;

  int _safeSelectedIndex(WheelPickerController controller) {
    final selected = controller.selected;
    return selected >= 0 ? selected : controller.initialIndex;
  }

  @override
  void initState() {
    super.initState();
    _selectedHour = _safeSelectedIndex(widget.hourController);
    _selectedMinute = _safeSelectedIndex(widget.minuteController);
    _selectedPeriod = _safeSelectedIndex(widget.periodController);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final Color primaryColor = AppColors.primaryColor;
    final Color secondaryColor = colorScheme.secondary;
    final Color backgroundColor = theme.scaffoldBackgroundColor;
    final Color selectedTextColor =
        colorScheme.brightness == Brightness.dark ? white : black;
    final Color unselectedTextColor =
        textTheme.bodyMedium?.color?.withValues(alpha: 0.65) ??
        (colorScheme.brightness == Brightness.dark ? white : black).withValues(
          alpha: 0.65,
        );

    final Color containerColor = Color.alphaBlend(
      primaryColor.withValues(
        alpha: colorScheme.brightness == Brightness.dark ? 0.14 : 0.06,
      ),
      backgroundColor,
    );

    final Color overlayBorder = primaryColor.withValues(alpha: 0.35);
    final Color overlayFill = secondaryColor.withValues(alpha: 0.12);

    final TextStyle valueStyle =
        textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.w600);
    final TextStyle labelStyle =
        textTheme.bodySmall?.copyWith(
          color: unselectedTextColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ) ??
        TextStyle(
          color: unselectedTextColor,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
        final wheelWidth = ((availableWidth - 88) / 3).clamp(68.0, 104.0);

        return Container(
          width: double.infinity,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: black.withValues(
                  alpha:
                      colorScheme.brightness == Brightness.dark ? 0.30 : 0.08,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: wheelWidth,
                    child: Center(child: Text('Hour', style: labelStyle)),
                  ),
                  SizedBox(
                    width: wheelWidth,
                    child: Center(child: Text('Minute', style: labelStyle)),
                  ),
                  SizedBox(
                    width: wheelWidth,
                    child: Center(child: Text('Period', style: labelStyle)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: widget.height,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: Container(
                        height: widget.wheelStyle.itemExtent + 8,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: overlayFill,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: overlayBorder),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWheel(
                          width: wheelWidth,
                          controller: widget.hourController,
                          selectedIndex: _selectedHour,
                          selectedTextColor: selectedTextColor,
                          unselectedTextColor: unselectedTextColor,
                          valueStyle: valueStyle,
                          style: widget.wheelStyle,
                          looping: true,
                          formatValue:
                              (index) => (index + 1).toString().padLeft(2, '0'),
                          onIndexChanged: (index) {
                            setState(() => _selectedHour = index);
                          },
                        ),
                        Text(
                          ':',
                          style: valueStyle.copyWith(
                            color: primaryColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _buildWheel(
                          width: wheelWidth,
                          controller: widget.minuteController,
                          selectedIndex: _selectedMinute,
                          selectedTextColor: selectedTextColor,
                          unselectedTextColor: unselectedTextColor,
                          valueStyle: valueStyle,
                          style: widget.wheelStyle,
                          looping: true,
                          formatValue:
                              (index) => index.toString().padLeft(2, '0'),
                          onIndexChanged: (index) {
                            setState(() => _selectedMinute = index);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWheel(
                          width: wheelWidth,
                          controller: widget.periodController,
                          selectedIndex: _selectedPeriod,
                          selectedTextColor: selectedTextColor,
                          unselectedTextColor: unselectedTextColor,
                          valueStyle: valueStyle,
                          style: widget.wheelStyle,
                          looping: false,
                          formatValue: (index) => index == 0 ? 'AM' : 'PM',
                          onIndexChanged: (index) {
                            setState(() => _selectedPeriod = index);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWheel({
    required double width,
    required WheelPickerController controller,
    required int selectedIndex,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required TextStyle valueStyle,
    required WheelPickerStyle style,
    required bool looping,
    required String Function(int index) formatValue,
    required ValueChanged<int> onIndexChanged,
  }) {
    return SizedBox(
      width: width,
      child: WheelPicker(
        controller: controller,
        looping: looping,
        selectedIndexColor: AppColors.primaryColor,
        style: style,
        onIndexChanged: (index, _) => onIndexChanged(index),
        builder: (context, index) {
          final isSelected = index == selectedIndex;
          return Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              scale: isSelected ? 1.08 : 1.0,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: valueStyle.copyWith(
                  color: isSelected ? selectedTextColor : unselectedTextColor,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(formatValue(index)),
              ),
            ),
          );
        },
      ),
    );
  }
}
