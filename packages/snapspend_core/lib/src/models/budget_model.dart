import 'package:equatable/equatable.dart';

class BudgetModel extends Equatable {
  final String budgetId;
  final String name;
  final double limitAmount;
  final String period;
  final String? categoryId;
  final double alertAt;
  final DateTime createdAt;

  const BudgetModel({
    required this.budgetId,
    required this.name,
    required this.limitAmount,
    required this.period,
    this.categoryId,
    required this.alertAt,
    required this.createdAt,
  });

  BudgetModel copyWith({
    String? budgetId,
    String? name,
    double? limitAmount,
    String? period,
    String? categoryId,
    double? alertAt,
    DateTime? createdAt,
  }) {
    return BudgetModel(
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      limitAmount: limitAmount ?? this.limitAmount,
      period: period ?? this.period,
      categoryId: categoryId ?? this.categoryId,
      alertAt: alertAt ?? this.alertAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'budgetId': budgetId,
      'name': name,
      'limitAmount': limitAmount,
      'period': period,
      'categoryId': categoryId,
      'alertAt': alertAt,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      budgetId: map['budgetId'] as String,
      name: map['name'] as String,
      limitAmount: (map['limitAmount'] as num).toDouble(),
      period: map['period'] as String,
      categoryId: map['categoryId'] as String?,
      alertAt: (map['alertAt'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory BudgetModel.fromJson(Map<String, dynamic> json) =>
      BudgetModel.fromMap(json);

  @override
  List<Object?> get props => [
        budgetId,
        name,
        limitAmount,
        period,
        categoryId,
        alertAt,
        createdAt,
      ];
}
