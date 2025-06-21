import 'package:flutter/foundation.dart';

@immutable
class Ingredient {
  final String id;
  final String name;
  final String image;
  final String imageName; // e.g., "apple.jpg"
  final String? aisle;

  const Ingredient({
    required this.id,
    required this.name,
    required this.image,
    required this.imageName,
    this.aisle,
  });

  String get imageUrl =>
      'https://spoonacular.com/cdn/ingredients_100x100/$imageName';

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: json['id'].toString(),
      name: json['name'] as String,
      image: json['image'] as String,
      imageName: json['image'] as String,
      aisle: json['aisle'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image': image, // Match Spoonacular response
      'aisle': aisle,
    };
  }

  // Override equality and hashCode for proper comparison in sets and maps
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ingredient && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
