import 'package:cloud_firestore/cloud_firestore.dart';

class BibleOutline {
  final String id;
  final String title;
  final String theme;
  final String type; // Expositivo, Temático, etc.
  final String version;
  final String reference; // Livro, Capítulo, Versículos
  final List<String> associatedVerses; // Keys: LIVRO_CAP_VER
  final List<String> associatedPdfs; // IDs dos PDFs do OneDrive
  final DateTime createdAt;
  final List<String> analyses; // IDs das análises incluídas
  final String? content; // O texto do esboço gerado
  final bool isGenerating;

  BibleOutline({
    required this.id,
    required this.title,
    required this.theme,
    required this.type,
    required this.version,
    required this.reference,
    required this.associatedVerses,
    required this.associatedPdfs,
    required this.createdAt,
    required this.analyses,
    this.content,
    this.isGenerating = false,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'theme': theme,
    'type': type,
    'version': version,
    'reference': reference,
    'associatedVerses': associatedVerses,
    'associatedPdfs': associatedPdfs,
    'createdAt': Timestamp.fromDate(createdAt),
    'analyses': analyses,
    'content': content,
    'isGenerating': isGenerating,
  };

  factory BibleOutline.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BibleOutline(
      id: doc.id,
      title: data['title'] ?? '',
      theme: data['theme'] ?? '',
      type: data['type'] ?? '',
      version: data['version'] ?? '',
      reference: data['reference'] ?? '',
      associatedVerses: List<String>.from(data['associatedVerses'] ?? []),
      associatedPdfs: List<String>.from(data['associatedPdfs'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      analyses: List<String>.from(data['analyses'] ?? []),
      content: data['content'],
      isGenerating: data['isGenerating'] ?? false,
    );
  }
}
