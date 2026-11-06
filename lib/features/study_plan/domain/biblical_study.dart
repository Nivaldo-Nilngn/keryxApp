class BiblicalStudy {
  final int id;
  final String title;
  final String slug;
  final String date;
  final List<String> categories;
  final String excerpt;
  final String? content;

  const BiblicalStudy({
    required this.id,
    required this.title,
    required this.slug,
    required this.date,
    required this.categories,
    required this.excerpt,
    this.content,
  });

  factory BiblicalStudy.fromJson(Map<String, dynamic> json) {
    return BiblicalStudy(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      date: json['date'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      excerpt: json['excerpt'] as String? ?? '',
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'date': date,
      'categories': categories,
      'excerpt': excerpt,
      if (content != null) 'content': content,
    };
  }

  String get estimatedReadTime {
    final wordCount = (content ?? excerpt).split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 180).ceil();
    return '$minutes min de leitura';
  }

  String get formattedDate {
    if (date.isEmpty) return '';
    try {
      final parsed = DateTime.parse(date);
      return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
    } catch (_) {
      return date.split('T').first;
    }
  }

  BiblicalStudy copyWith({
    int? id,
    String? title,
    String? slug,
    String? date,
    List<String>? categories,
    String? excerpt,
    String? content,
  }) {
    return BiblicalStudy(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      date: date ?? this.date,
      categories: categories ?? this.categories,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
    );
  }
}

class StudyCategory {
  final int id;
  final String name;
  final String slug;
  final int count;

  const StudyCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
  });

  factory StudyCategory.fromJson(Map<String, dynamic> json) {
    return StudyCategory(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      count: json['count'] as int? ?? 0,
    );
  }
}

