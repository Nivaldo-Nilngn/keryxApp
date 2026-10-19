
enum BlockType {
  text,
  heading,
  subheading,
  verse,
  reference,
  lexicon,
  commentary,
  list,
  divider
}

class StudyBlock {
  final String id;
  final BlockType type;
  final String content;
  final Map<String, dynamic>? metadata;

  const StudyBlock({
    required this.id,
    required this.type,
    this.content = '',
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'content': content,
        'metadata': metadata,
      };

  factory StudyBlock.fromMap(Map<String, dynamic> map) {
    return StudyBlock(
      id: map['id'] ?? '',
      type: BlockType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => BlockType.text,
      ),
      content: map['content'] ?? '',
      metadata: map['metadata'],
    );
  }

  StudyBlock copyWith({
    String? id,
    BlockType? type,
    String? content,
    Map<String, dynamic>? metadata,
  }) {
    return StudyBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
    );
  }
}
