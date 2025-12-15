import 'package:flutter/material.dart';
import 'package:snevva/consts/colors.dart';

class NumberPickerExample extends StatefulWidget {
  const NumberPickerExample({super.key});

  @override
  NumberPickerExampleState createState() => NumberPickerExampleState();
}

class NumberPickerExampleState extends State<NumberPickerExample> {
  int selectedNumber = 1;
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Simple Number Picker')),
      body: Center(
        child: InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: AnimatedContainer(
            duration: Duration(milliseconds: 500),
            height: isExpanded ? 100 : 50,
            width: isExpanded ? 300 : 50,
            color: isExpanded ? Colors.blue : green,
            child:
                isExpanded
                    ? Icon(Icons.ac_unit_rounded)
                    : Icon(Icons.safety_check),
          ),
        ),
      ),
    );
  }
}
