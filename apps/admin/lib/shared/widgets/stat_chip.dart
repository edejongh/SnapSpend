import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final String label;
  final Color color;
  final Widget? trailing;

  const StatChip(
      {super.key, required this.label, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
