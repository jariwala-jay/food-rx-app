import 'package:mongo_dart/mongo_dart.dart';

class Article {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final String? content;
  bool isBookmarked;

  Article({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    this.content,
    this.isBookmarked = false,
  });

  Article copyWith({
    String? id,
    String? title,
    String? category,
    String? imageUrl,
    String? content,
    bool? isBookmarked,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      content: content ?? this.content,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  factory Article.fromJson(Map<String, dynamic> json) {
    // Handle both string and ObjectId types for id
    String id;
    if (json['_id'] is ObjectId) {
      id = json['_id'].toHexString();
    } else {
      id = json['_id'].toString();
    }

    return Article(
      id: id,
      title: json['title'] as String,
      category: json['category'] as String,
      imageUrl: json['imageUrl'] as String,
      content: json['content'] as String?,
      isBookmarked: json['isBookmarked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'category': category,
      'imageUrl': imageUrl,
      'content': content,
      'isBookmarked': isBookmarked,
    };
  }

  // Helper method to get the hex string from an ObjectId string
  String getHexId() {
    if (id.startsWith('ObjectId(')) {
      return id.substring(9, 33);
    }
    return id;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Article &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          category == other.category &&
          imageUrl == other.imageUrl &&
          content == other.content &&
          isBookmarked == other.isBookmarked;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      category.hashCode ^
      imageUrl.hashCode ^
      content.hashCode ^
      isBookmarked.hashCode;
}
