import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  final List<String> periods;
  final String selected;
  final ValueChanged<String> onChanged;

  const FilterBar({
    super.key,
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final isSelected = period == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (_) => onChanged(period),
            ),
          );
        }).toList(),
      ),
    );
  }
}
