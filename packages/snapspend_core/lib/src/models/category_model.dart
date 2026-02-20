import 'package:equatable/equatable.dart';

class CategoryModel extends Equatable {
  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final List<String> keywords;
  final bool isDefault;
  final bool taxDeductibleByDefault;

  const CategoryModel({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.keywords,
    required this.isDefault,
    required this.taxDeductibleByDefault,
  });

  CategoryModel copyWith({
    String? categoryId,
    String? name,
    String? icon,
    String? color,
    List<String>? keywords,
    bool? isDefault,
    bool? taxDeductibleByDefault,
  }) {
    return CategoryModel(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      keywords: keywords ?? this.keywords,
      isDefault: isDefault ?? this.isDefault,
      taxDeductibleByDefault:
          taxDeductibleByDefault ?? this.taxDeductibleByDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'icon': icon,
      'color': color,
      'keywords': keywords,
      'isDefault': isDefault,
      'taxDeductibleByDefault': taxDeductibleByDefault,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      categoryId: map['categoryId'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      keywords: List<String>.from(map['keywords'] as List),
      isDefault: map['isDefault'] as bool,
      taxDeductibleByDefault: map['taxDeductibleByDefault'] as bool,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel.fromMap(json);

  @override
  List<Object?> get props => [
        categoryId,
        name,
        icon,
        color,
        keywords,
        isDefault,
        taxDeductibleByDefault,
      ];
}
