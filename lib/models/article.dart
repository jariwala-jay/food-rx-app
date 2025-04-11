class Article {
  final String title;
  final String category;
  final String imageUrl;
  final bool isBookmarked;

  Article({
    required this.title,
    required this.category,
    required this.imageUrl,
    this.isBookmarked = false,
  });
}
