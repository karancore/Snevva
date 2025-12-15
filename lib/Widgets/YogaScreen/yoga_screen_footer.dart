import '../../consts/consts.dart';

class YogaScreenFooterWidget extends StatelessWidget {
  final String containerText;
  final String containerImg;
  const YogaScreenFooterWidget({
    super.key,
    required this.containerText,
    required this.containerImg,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Image(image: AssetImage(containerImg)),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              containerText,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
