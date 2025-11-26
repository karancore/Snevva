
import '../../consts/consts.dart';

class WomenHealthQuotesWidget extends StatelessWidget {
  const WomenHealthQuotesWidget({
    super.key, required this.contColor, required this.img,
  });
final Color contColor;
final String img;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: contColor.withValues(alpha: 0.1),
                  ),
                  child: Text('Lorem ipsum', style: TextStyle(color: contColor),),
                ),
                SizedBox(height: 10,),
                AutoSizeText(
                  "At vero eos et accusamus et iusto odio",
                  minFontSize: 10,
                  maxFontSize: 16,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 10,),
                AutoSizeText(
                  "Author name",
                  minFontSize: 10,
                  maxFontSize: 14,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: mediumGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),

              ],
            ),
          ),
          Image.asset(img, height: 120,),

        ],
      ),
    );
  }
}
