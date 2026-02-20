import 'package:flutter/material.dart';

class DataTableCard extends StatelessWidget {
  final String title;
  final Widget table;
  final Widget? headerAction;

  const DataTableCard({
    super.key,
    required this.title,
    required this.table,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          table,
        ],
      ),
    );
  }
}
