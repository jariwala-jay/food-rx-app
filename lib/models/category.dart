import 'package:flutter/material.dart';

class Category {
  final String name;
  final bool isSelected;
  final IconData? icon;

  const Category({
    required this.name,
    this.isSelected = false,
    this.icon,
  });

  Category copyWith({
    String? name,
    bool? isSelected,
    IconData? icon,
  }) {
    return Category(
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
      icon: icon ?? this.icon,
    );
  }
}
