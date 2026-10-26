import 'package:flutter/material.dart';

enum ReleaseNoteCategory {
  feature, // Novos Recursos / O que foi implementado
  improvement, // O que foi modificado / melhorias
  fix, // Correções de bugs
}

extension ReleaseNoteCategoryX on ReleaseNoteCategory {
  String get label {
    switch (this) {
      case ReleaseNoteCategory.feature:
        return 'Novo Recurso';
      case ReleaseNoteCategory.improvement:
        return 'Modificação';
      case ReleaseNoteCategory.fix:
        return 'Correção';
    }
  }

  Color get color {
    switch (this) {
      case ReleaseNoteCategory.feature:
        return const Color(0xFF10B981); // Esmeralda vibrante
      case ReleaseNoteCategory.improvement:
        return const Color(0xFF6366F1); // Índigo Celestial
      case ReleaseNoteCategory.fix:
        return const Color(0xFFF59E0B); // Âmbar Ouro
    }
  }

  IconData get icon {
    switch (this) {
      case ReleaseNoteCategory.feature:
        return Icons.auto_awesome_rounded;
      case ReleaseNoteCategory.improvement:
        return Icons.trending_up_rounded;
      case ReleaseNoteCategory.fix:
        return Icons.healing_rounded;
    }
  }
}

class ReleaseNoteItem {
  final String title;
  final String description;
  final ReleaseNoteCategory category;
  final IconData? customIcon;

  const ReleaseNoteItem({
    required this.title,
    required this.description,
    required this.category,
    this.customIcon,
  });
}

class ReleaseNoteVersion {
  final String versionName;
  final int buildNumber;
  final String title;
  final String releaseDate;
  final String highlight;
  final List<ReleaseNoteItem> items;

  const ReleaseNoteVersion({
    required this.versionName,
    required this.buildNumber,
    required this.title,
    required this.releaseDate,
    required this.highlight,
    required this.items,
  });
}
