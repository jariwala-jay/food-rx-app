class Tip {
  final String id;
  final String title;
  final String description;
  final String category;
  final String imageUrl;
  final Map<String, DateTime> lastShownToUsers;
  final Map<String, int> viewCountByUser;

  Tip({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.imageUrl,
    Map<String, DateTime>? lastShownToUsers,
    Map<String, int>? viewCountByUser,
  })  : lastShownToUsers = lastShownToUsers ?? {},
        viewCountByUser = viewCountByUser ?? {};

  Tip copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? imageUrl,
    Map<String, DateTime>? lastShownToUsers,
    Map<String, int>? viewCountByUser,
  }) {
    return Tip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      lastShownToUsers: lastShownToUsers ?? this.lastShownToUsers,
      viewCountByUser: viewCountByUser ?? this.viewCountByUser,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'imageUrl': imageUrl,
      'lastShownToUsers': lastShownToUsers.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
      'viewCountByUser': viewCountByUser,
    };
  }

  factory Tip.fromJson(Map<String, dynamic> json) {
    return Tip(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      imageUrl: json['imageUrl'],
      lastShownToUsers:
          (json['lastShownToUsers'] as Map<String, dynamic>?)?.map(
                (key, value) => MapEntry(key, DateTime.parse(value)),
              ) ??
              {},
      viewCountByUser: (json['viewCountByUser'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as int),
          ) ??
          {},
    );
  }

  DateTime? getLastShownForUser(String userId) => lastShownToUsers[userId];
  int getViewCountForUser(String userId) => viewCountByUser[userId] ?? 0;
}
