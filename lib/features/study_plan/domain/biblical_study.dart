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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'count': count,
    };
  }
}

class StudySectionGroup {
  final String title;
  final List<String> subcategories;

  const StudySectionGroup({
    required this.title,
    required this.subcategories,
  });

  bool matches(List<String> studyCategories) {
    final targets = [
      title.toLowerCase(),
      ...subcategories.map((s) => s.toLowerCase()),
    ];
    return studyCategories.any((cat) => targets.contains(cat.toLowerCase()));
  }
}

const List<StudySectionGroup> kStudyGroups = [
  StudySectionGroup(
    title: 'Antigo Testamento',
    subcategories: [
      'Pentateuco',
      'Históricos',
      'Jó',
      'Provérbios',
      'Isaías',
      'Jeremias',
      'Joel',
      'Habacuque',
      'Ageu',
      'Malaquias',
      'Zacarias',
    ],
  ),
  StudySectionGroup(
    title: 'Defesa da Fé',
    subcategories: [
      'Adoração e louvor',
      'Artigos Teológicos',
      'Comportamento',
      'Crítica',
      'Evangelismo',
      'Interpretação bíblica',
      'Lições bíblicas',
      'Lições para EBD',
      'Milagres',
      'Oração',
      'Parábolas',
      'Polêmicos',
      'Propósito Eterno',
      'Sermões e esboços',
    ],
  ),
  StudySectionGroup(
    title: 'Doutrinas',
    subcategories: [
      'Arrependimento',
      'Cristologia',
      'Eleição e Predestinação',
      'Escatologia',
      'Igreja',
      'Justificação',
      'Pecado',
      'Regeneração',
      'Santificação',
      'Salvação',
    ],
  ),
  StudySectionGroup(
    title: 'Salmos',
    subcategories: [
      'Salmos I',
      'Salmos II',
      'Salmos III',
      'Salmos IV',
      'Salmos V',
    ],
  ),
  StudySectionGroup(
    title: 'Novo Testamento',
    subcategories: [
      'Evangelho Mateus',
      'Evangelho Marcos',
      'Evangelho Lucas',
      'Evangelho João',
      'Romanos',
      'I Coríntios',
      'II Coríntios',
      'Gálatas',
      'Efésios',
      'Colossenses',
      'Tito',
      'Filemom',
      'Hebreus',
      'Tiago',
      'I Pedro',
      'Judas',
      'Apocalipse',
    ],
  ),
];


