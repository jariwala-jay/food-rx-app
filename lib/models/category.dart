class Category {
  final String name;
  final bool isSelected;

  const Category({
    required this.name,
    this.isSelected = false,
  });

  Category copyWith({
    String? name,
    bool? isSelected,
  }) {
    return Category(
      name: name ?? this.name,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
