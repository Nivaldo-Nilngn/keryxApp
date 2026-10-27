import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/avatar_frame_options.dart';

class CommunityUserAvatar extends ConsumerWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final String? userId;
  final bool isOfficial;
  final String? avatarFrame;
  final VoidCallback? onTap;

  const CommunityUserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 20,
    this.userId,
    this.isOfficial = false,
    this.avatarFrame,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAuthUser = FirebaseAuth.instance.currentUser;
    final userData = ref.watch(userDataProvider).valueOrNull;
    final currentUserName = (userData?['name'] as String?)?.trim() ??
        currentAuthUser?.displayName?.trim() ??
        '';

    final bool isCurrentUser = (currentAuthUser != null && userId != null && userId == currentAuthUser.uid) ||
        (currentUserName.isNotEmpty && name.trim().toLowerCase() == currentUserName.toLowerCase());

    String? resolvedUrl;
    String effectiveName = name;
    String? effectiveFrame = avatarFrame;

    if (isCurrentUser) {
      resolvedUrl = (userData?['photoUrl'] as String?)?.trim() ??
          currentAuthUser?.photoURL?.trim() ??
          (currentAuthUser?.providerData.isNotEmpty == true
              ? currentAuthUser!.providerData.first.photoURL?.trim()
              : null) ??
          photoUrl?.trim();
      effectiveName = currentUserName.isNotEmpty ? currentUserName : name;
      effectiveFrame = avatarFrame ?? (userData?['avatarFrame'] as String?) ?? 'gold';
    } else {
      resolvedUrl = photoUrl?.trim();
    }

    final double size = radius * 2;
    final initial = effectiveName.trim().isNotEmpty ? effectiveName.trim()[0].toUpperCase() : 'U';

    final bool hasFrame = effectiveFrame != null && effectiveFrame != 'none' && !isOfficial;
    final borderThickness = size > 50 ? 2.8 : 1.8;
    final gapThickness = size > 50 ? 1.8 : 1.0;
    final innerSize = hasFrame ? (size - (borderThickness + gapThickness) * 2) : size;
    final safeInnerSize = innerSize > 0 ? innerSize : size;

    final avatarContent = Semantics(
      label: 'Foto de perfil de $effectiveName',
      image: true,
      child: _buildFramedWrapper(
        context: context,
        inner: _buildContent(context, resolvedUrl, initial, safeInnerSize),
        frameId: effectiveFrame,
        size: size,
        borderThickness: borderThickness,
        gapThickness: gapThickness,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatarContent);
    }
    return avatarContent;
  }

  Widget _buildFramedWrapper({
    required BuildContext context,
    required Widget inner,
    required String? frameId,
    required double size,
    required double borderThickness,
    required double gapThickness,
  }) {
    if (frameId == null || frameId == 'none' || isOfficial) {
      return inner;
    }

    final frame = AvatarFrameOption.getById(frameId);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderThickness),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: frame.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: frame.shadowColor.withValues(alpha: 0.35),
            blurRadius: size > 50 ? 8 : 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(gapThickness),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF14141E) : Colors.white,
        ),
        child: ClipOval(child: inner),
      ),
    );
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
