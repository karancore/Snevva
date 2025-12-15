import 'package:flutter/material.dart';

import '../consts/colors.dart';

class IphoneBackButton extends StatelessWidget {
  const IphoneBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      padding: EdgeInsets.only(left: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: mediumGrey,
      ),
      child: IconButton(
        icon: Icon(Icons.arrow_back_ios, size: 18, color: Colors.white),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}
