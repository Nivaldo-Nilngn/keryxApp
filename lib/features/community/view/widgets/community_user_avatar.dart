import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';

class CommunityUserAvatar extends ConsumerWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final String? userId;
  final bool isOfficial;
  final VoidCallback? onTap;

  const CommunityUserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 20,
    this.userId,
    this.isOfficial = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Tenta obter photoUrl passada ou resolve a partir do usuário atual logado se aplicável
    String? resolvedUrl = photoUrl?.trim();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      final currentAuthUser = FirebaseAuth.instance.currentUser;
      if (userId != null && currentAuthUser != null && userId == currentAuthUser.uid) {
        final userData = ref.watch(userDataProvider).valueOrNull;
        resolvedUrl = (userData?['photoUrl'] as String?)?.trim() ??
            currentAuthUser.photoURL?.trim() ??
            (currentAuthUser.providerData.isNotEmpty
                ? currentAuthUser.providerData.first.photoURL?.trim()
                : null);
      }
    }

    final double size = radius * 2;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    Widget avatarContent = Semantics(
      label: 'Foto de perfil de $name',
      image: true,
      child: _buildContent(context, resolvedUrl, initial, size),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarContent);
    }
    return avatarContent;
  }

  Widget _buildContent(BuildContext context, String? url, String initial, double size) {
    if (isOfficial) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(Icons.auto_awesome, size: size * 0.52, color: Colors.black87),
      );
    }

    if (url == null || url.isEmpty) {
      return _buildInitials(context, initial, size);
    }

    // Se for Base64 (data:image/...)
    if (url.startsWith('data:image') || !url.startsWith('http')) {
      try {
        final cleanBase64 = url.contains(',') ? url.split(',').last : url;
        final bytes = base64Decode(cleanBase64.trim());
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildInitials(context, initial, size),
          ),
        );
      } catch (_) {
        return _buildInitials(context, initial, size);
      }
    }

    // Se for URL HTTP / HTTPS (Resolve Google e CORS para Web)
    String effectiveUrl = url;
    if (effectiveUrl.contains('googleusercontent.com')) {
      effectiveUrl = effectiveUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
    }
    if (kIsWeb && effectiveUrl.startsWith('http') && !effectiveUrl.contains('wsrv.nl')) {
      effectiveUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(effectiveUrl)}';
    }

    return ClipOval(
      child: Image.network(
        effectiveUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildInitials(context, initial, size),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildInitials(context, initial, size);
        },
      ),
    );
  }

  Widget _buildInitials(BuildContext context, String initial, double size) {
    // Paleta de gradientes nobres baseada no hash do nome para variar elegantemente entre autores
    final gradients = [
      [const Color(0xFFD97706), const Color(0xFFB45309)], // Gold
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // Blue
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)], // Purple
      [const Color(0xFF10B981), const Color(0xFF047857)], // Emerald
      [const Color(0xFFEC4899), const Color(0xFFBE185D)], // Rose
      [const Color(0xFFF97316), const Color(0xFFC2410C)], // Amber
    ];

    final colorIndex = name.codeUnits.fold<int>(0, (prev, curr) => prev + curr) % gradients.length;
    final gradient = gradients[colorIndex];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
