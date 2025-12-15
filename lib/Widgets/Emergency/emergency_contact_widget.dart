import 'package:flutter_svg/svg.dart';
import '../../consts/consts.dart';

class EmergencyContactWidget extends StatelessWidget {
  final String name;
  final String relation;
  final String img;
  final String phone;

  const EmergencyContactWidget({
    super.key,
    required this.name,
    required this.img,
    required this.phone,
    required this.relation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image(image: AssetImage(img), height: 64),
          SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 5),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      relation,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  SvgPicture.asset(phoneIcon, height: 24),

                  SizedBox(width: 5),

                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 20,
                      color: mediumGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Spacer(),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.all(5.0),
              child: SvgPicture.asset(editIcon, height: 24),
            ),
          ),
        ],
      ),
    );
  }
}
