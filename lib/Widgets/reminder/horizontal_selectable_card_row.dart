import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../consts/colors.dart';

class HorizontalSelectableCardRow<T> extends StatelessWidget {
  final List<T> items;
  final T selectedItem;
  final ValueChanged<T> onSelected;

  final Widget Function(T item, bool isSelected)? iconBuilder;
  final String Function(T item) labelBuilder;

  final double spacing;

  const HorizontalSelectableCardRow({
    super.key,
    required this.items,
    required this.selectedItem,
    required this.onSelected,
    this.iconBuilder,
    required this.labelBuilder,
    this.spacing = 18,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = item == selectedItem;

              return GestureDetector(
                onTap: () => onSelected(item),
                child: Card(
                  margin: EdgeInsets.only(left: index == 0 ? 0 : spacing),
                  color:
                      isSelected
                          ? AppColors.primaryColor
                          : (isDarkMode ? black : white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (iconBuilder != null) ...[
                          iconBuilder!(item, isSelected),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          labelBuilder(item)?.capitalizeFirst ?? '',
                          style: TextStyle(
                            color: isSelected ? white : grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}
