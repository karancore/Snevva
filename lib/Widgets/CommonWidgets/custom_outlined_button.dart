import '../../consts/consts.dart';

class CustomOutlinedButton extends StatelessWidget {
  const CustomOutlinedButton({
    super.key,
    required this.width,
    this.backgroundColor = white,
    this.borderRadius = 8,
    required this.isDarkMode,
    required this.buttonName,
    required this.onTap,
    this.fontWeight = FontWeight.normal,
    this.isWhiteReq = false,
  });

  final double width;
  final String buttonName;
  final VoidCallback? onTap; // <- allow null to disable button
  final bool isDarkMode;
  final double? borderRadius;
  final Color? backgroundColor;
  final FontWeight? fontWeight;
  final bool? isWhiteReq;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return Container(
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius ?? 8),
        color: backgroundColor,
      ),

      child: OutlinedButton(
        onPressed: onTap,

        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.transparent),

          fixedSize: Size(width, 40),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 8),
          ),

          padding: EdgeInsets.zero,
        ),

        child: Text(
          buttonName,
          style: TextStyle(
            fontSize: 16,
            color: isWhiteReq! ? AppColors.primaryColor : white,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}
