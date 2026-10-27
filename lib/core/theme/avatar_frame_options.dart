import 'package:flutter/material.dart';

class AvatarFrameOption {
  final String id;
  final String name;
  final List<Color> colors;
  final Color shadowColor;
  final String emoji;

  const AvatarFrameOption({
    required this.id,
    required this.name,
    required this.colors,
    required this.shadowColor,
    required this.emoji,
  });

  static const List<AvatarFrameOption> options = [
    AvatarFrameOption(
      id: 'gold',
      name: 'Ouro Real',
      colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFFDE68A)],
      shadowColor: Color(0xFFD97706),
      emoji: '🟡',
    ),
    AvatarFrameOption(
      id: 'aurora',
      name: 'Aurora',
      colors: [Color(0xFFEC4899), Color(0xFF8B5CF6), Color(0xFF3B82F6)],
      shadowColor: Color(0xFF8B5CF6),
      emoji: '🟣',
    ),
    AvatarFrameOption(
      id: 'fire',
      name: 'Pentecostes',
      colors: [Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFFBBF24)],
      shadowColor: Color(0xFFEF4444),
      emoji: '🔥',
    ),
    AvatarFrameOption(
      id: 'sapphire',
      name: 'Safira',
      colors: [Color(0xFF06B6D4), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
      shadowColor: Color(0xFF06B6D4),
      emoji: '💎',
    ),
    AvatarFrameOption(
      id: 'emerald',
      name: 'Esmeralda',
      colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
      shadowColor: Color(0xFF10B981),
      emoji: '🌿',
    ),
    AvatarFrameOption(
      id: 'royal',
      name: 'Púrpura',
      colors: [Color(0xFF7C3AED), Color(0xFFA855F7), Color(0xFFC026D3)],
      shadowColor: Color(0xFF7C3AED),
      emoji: '👑',
    ),
    AvatarFrameOption(
      id: 'midnight',
      name: 'Estelar',
      colors: [Color(0xFF38BDF8), Color(0xFF6366F1), Color(0xFF0284C7)],
      shadowColor: Color(0xFF38BDF8),
      emoji: '🌌',
    ),
    AvatarFrameOption(
      id: 'silver',
      name: 'Prata',
      colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8), Color(0xFFE2E8F0)],
      shadowColor: Colors.white24,
      emoji: '⚪',
    ),
    AvatarFrameOption(
      id: 'none',
      name: 'Nenhum',
      colors: [Colors.transparent, Colors.transparent],
      shadowColor: Colors.transparent,
      emoji: '🚫',
    ),
  ];

  static AvatarFrameOption getById(String? id) {
    if (id == null || id.isEmpty) return options.first;
    return options.firstWhere(
      (f) => f.id.toLowerCase() == id.toLowerCase(),
      orElse: () => options.first,
    );
  }
}
