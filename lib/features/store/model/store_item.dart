import 'package:flutter/material.dart';

enum StoreCategory {
  bibles,
  books,
  commentaries,
  expository,
  homiletics,
  culture,
  dictionaries,
  fonts,
  journals,
  audios,
  outros,
}

@immutable
class StoreItem {
  final String id;
  final String name;
  final String filename;
  final StoreCategory category;
  final String? downloadUrl;
  final int? sizeBytes;
  
  const StoreItem({
    required this.id,
    required this.name,
    required this.filename,
    required this.category,
    this.downloadUrl,
    this.sizeBytes,
  });
  
  String get categoryDisplayName {
    switch (category) {
      case StoreCategory.bibles:
        return 'BÍBLIAS';
      case StoreCategory.books:
        return 'LIVROS';
      case StoreCategory.commentaries:
        return 'COMENTÁRIOS';
      case StoreCategory.expository:
        return 'EXPOSITIVOS';
      case StoreCategory.homiletics:
        return 'ESBOÇOS E HOMILÉTICA';
      case StoreCategory.culture:
        return 'CULTURA E HISTÓRIA';
      case StoreCategory.dictionaries:
        return 'DICIONÁRIOS';
      case StoreCategory.fonts:
        return 'FONTES';
      case StoreCategory.journals:
        return 'JORNAIS';
      case StoreCategory.audios:
        return 'ÁUDIOS E LOUVORES';
      case StoreCategory.outros:
        return 'MÓDULOS DIVERSOS';
    }
  }
  
  IconData get categoryIcon {
    switch (category) {
      case StoreCategory.bibles:
        return Icons.menu_book_rounded;
      case StoreCategory.books:
        return Icons.book_rounded;
      case StoreCategory.commentaries:
        return Icons.auto_stories_rounded;
      case StoreCategory.expository:
        return Icons.library_books_rounded;
      case StoreCategory.homiletics:
        return Icons.record_voice_over_rounded;
      case StoreCategory.culture:
        return Icons.public_rounded;
      case StoreCategory.dictionaries:
        return Icons.translate_rounded;
      case StoreCategory.fonts:
        return Icons.font_download_rounded;
      case StoreCategory.journals:
        return Icons.article_rounded;
      case StoreCategory.audios:
        return Icons.audiotrack_rounded;
      case StoreCategory.outros:
        return Icons.extension_rounded;
    }
  }
  
  StoreItem copyWith({
    String? id,
    String? name,
    String? filename,
    StoreCategory? category,
    String? downloadUrl,
    int? sizeBytes,
  }) {
    return StoreItem(
      id: id ?? this.id,
      name: name ?? this.name,
      filename: filename ?? this.filename,
      category: category ?? this.category,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    StoreCategory category = StoreCategory.books;
    final String catStr = json['categoria'] ?? '';
    
    switch (catStr) {
      case 'Biblias': category = StoreCategory.bibles; break;
      case 'Comentarios': category = StoreCategory.commentaries; break;
      case 'Dicionarios': category = StoreCategory.dictionaries; break;
      case 'Livros': category = StoreCategory.books; break;
      case 'Esbocos': category = StoreCategory.homiletics; break;
      case 'Cultura': category = StoreCategory.culture; break;
      case 'Outros': category = StoreCategory.outros; break;
    }

    final double sizeMb = (json['tamanho_mb'] as num?)?.toDouble() ?? 0.0;

    return StoreItem(
      id: json['id'] ?? '',
      name: json['titulo'] ?? 'Desconhecido',
      filename: json['nome_arquivo'] ?? '',
      category: category,
      downloadUrl: json['download_url'] ?? json['url'],
      sizeBytes: (sizeMb * 1024 * 1024).toInt(),
    );
  }
}