import 'package:cloud_firestore/cloud_firestore.dart';

class Sermon {
  final String id;
  final String title;
  final String? book;
  final int? chapter;
  final String? version;
  final String? referenceText;
  final String? introduction;
  final List<SermonPoint> points;
  final String? conclusion;
  final DateTime createdAt;
  final bool useTimer;
  
  // Title Formatting
  final String? titleAlign;
  final double? titleSize;
  final String? titleFont;
  final int? titleColor;

  // Intro Formatting
  final String? introAlign;
  final double? introSize;
  final String? introFont;
  final int? introColor;

  // Conclusion Formatting
  final String? concAlign;
  final double? concSize;
  final String? concFont;
  final int? concColor;

  Sermon({
    required this.id,
    required this.title,
    this.book,
    this.chapter,
    this.version,
    this.referenceText,
    this.introduction,
    required this.points,
    this.conclusion,
    required this.createdAt,
    this.useTimer = false,
    this.titleAlign = 'left',
    this.titleSize = 20,
    this.titleFont,
    this.titleColor,
    this.introAlign = 'left',
    this.introSize = 14,
    this.introFont,
    this.introColor,
    this.concAlign = 'left',
    this.concSize = 14,
    this.concFont,
    this.concColor,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'book': book,
        'chapter': chapter,
        'version': version,
        'referenceText': referenceText,
        'introduction': introduction,
        'points': points.map((p) => p.toMap()).toList(),
        'conclusion': conclusion,
        'createdAt': Timestamp.fromDate(createdAt),
        'useTimer': useTimer,
        'introAlign': introAlign,
        'introSize': introSize,
        'introFont': introFont,
        'introColor': introColor,
        'concAlign': concAlign,
        'concSize': concSize,
        'concFont': concFont,
        'concColor': concColor,
        'titleAlign': titleAlign,
        'titleSize': titleSize,
        'titleFont': titleFont,
        'titleColor': titleColor,
      };

  factory Sermon.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Sermon(
      id: doc.id,
      title: data['title'] ?? '',
      book: data['book'],
      chapter: data['chapter'],
      version: data['version'],
      referenceText: data['referenceText'],
      introduction: data['introduction'],
      points: (data['points'] as List? ?? [])
          .map((p) => SermonPoint.fromMap(p))
          .toList(),
      conclusion: data['conclusion'],
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      useTimer: data['useTimer'] ?? false,
      introAlign: data['introAlign'] ?? 'left',
      introSize: (data['introSize'] as num?)?.toDouble() ?? 14,
      introFont: data['introFont'],
      introColor: data['introColor'],
      concAlign: data['concAlign'] ?? 'left',
      concSize: (data['concSize'] as num?)?.toDouble() ?? 14,
      concFont: data['concFont'],
      concColor: data['concColor'],
      titleAlign: data['titleAlign'] ?? 'left',
      titleSize: (data['titleSize'] as num?)?.toDouble() ?? 20,
      titleFont: data['titleFont'],
      titleColor: data['titleColor'],
    );
  }
}

class SermonPoint {
  String title;
  List<SermonSubdivision> subdivisions;
  List<String> keyVerses;
  String? textAlign; // 'left', 'center', 'right', 'justify'
  double? fontSize;
  String? fontFamily;
  int? colorValue;

  SermonPoint({
    required this.title,
    required this.subdivisions,
    required this.keyVerses,
    this.textAlign = 'left',
    this.fontSize = 16,
    this.fontFamily,
    this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'subdivisions': subdivisions.map((s) => s.toMap()).toList(),
        'keyVerses': keyVerses,
        'textAlign': textAlign,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'colorValue': colorValue,
      };

  factory SermonPoint.fromMap(Map<String, dynamic> map) {
    return SermonPoint(
      title: map['title'] ?? '',
      subdivisions: (map['subdivisions'] as List? ?? [])
          .map((s) => SermonSubdivision.fromMap(s))
          .toList(),
      keyVerses: List<String>.from(map['keyVerses'] ?? []),
      textAlign: map['textAlign'] ?? 'left',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 16,
      fontFamily: map['fontFamily'],
      colorValue: map['colorValue'],
    );
  }
}

class SermonSubdivision {
  String text;
  String? illustration;
  List<String> supportingVerses;
  String? textAlign;
  double? fontSize;
  String? fontFamily;
  int? colorValue;

  SermonSubdivision({
    required this.text,
    this.illustration,
    required this.supportingVerses,
    this.textAlign = 'left',
    this.fontSize = 14,
    this.fontFamily,
    this.colorValue,
  });

  Map<String, dynamic> toMap() => {
        'text': text,
        'illustration': illustration,
        'supportingVerses': supportingVerses,
        'textAlign': textAlign,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'colorValue': colorValue,
      };

  factory SermonSubdivision.fromMap(Map<String, dynamic> map) {
    return SermonSubdivision(
      text: map['text'] ?? '',
      illustration: map['illustration'],
      supportingVerses: List<String>.from(map['supportingVerses'] ?? []),
      textAlign: map['textAlign'] ?? 'left',
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 14,
      fontFamily: map['fontFamily'],
      colorValue: map['colorValue'],
    );
  }
}
