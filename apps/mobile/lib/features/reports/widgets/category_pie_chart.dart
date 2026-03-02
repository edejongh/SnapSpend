import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../shared/theme/app_colors.dart';

class CategoryPieChart extends StatefulWidget {
  final Map<String, double> spendByCategory;

  const CategoryPieChart({super.key, required this.spendByCategory});

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int _touchedIndex = -1;

  static const _colors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    Colors.purple,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.spendByCategory.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    final total =
        widget.spendByCategory.values.fold(0.0, (a, b) => a + b);
    final entries = widget.spendByCategory.entries.toList();

    final sections = entries.indexed.map((e) {
      final (i, entry) = e;
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      final isTouched = i == _touchedIndex;
      return PieChartSectionData(
        value: entry.value,
        color: _colors[i % _colors.length],
        title: isTouched ? '' : '${pct.toStringAsFixed(1)}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: isTouched ? 72 : 64,
      );
    }).toList();

    // Build center overlay when a section is selected
    Widget? centerOverlay;
    if (_touchedIndex >= 0 && _touchedIndex < entries.length) {
      final entry = entries[_touchedIndex];
      final pct = total > 0
          ? '${(entry.value / total * 100).toStringAsFixed(1)}%'
          : '0%';
      centerOverlay = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CurrencyFormatter.format(entry.value, 'ZAR'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            pct,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sections: sections,
            sectionsSpace: 2,
            centerSpaceRadius: 36,
            centerSpaceColor: Theme.of(context).cardColor,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      pieTouchResponse == null ||
                      pieTouchResponse.touchedSection == null) {
                    _touchedIndex = -1;
                    return;
                  }
                  _touchedIndex =
                      pieTouchResponse.touchedSection!.touchedSectionIndex;
                });
              },
            ),
          ),
        ),
        if (centerOverlay != null)
          SizedBox(
            width: 64,
            child: centerOverlay,
          ),
      ],
    );
  }
}
