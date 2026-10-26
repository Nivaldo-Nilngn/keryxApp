import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

final scaffoldMessengerKeyProvider = Provider((ref) => GlobalKey<ScaffoldMessengerState>());

final notificationUiServiceProvider = Provider((ref) {
  final key = ref.watch(scaffoldMessengerKeyProvider);
  return NotificationService(key);
});

class NotificationService {
  NotificationService(this._messengerKey);
  final GlobalKey<ScaffoldMessengerState> _messengerKey;

  void showSuccess(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.green.shade800,
      icon: Icons.check_circle_outline,
    );
  }

  void showError(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.red.shade800,
      icon: Icons.error_outline,
    );
  }

  void showWarning(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.orange.shade900,
      icon: Icons.warning_amber_rounded,
    );
  }

  void showInfo(String message) {
    _showSnackBar(
      message,
      backgroundColor: const Color(0xFF6366F1),
      icon: Icons.info_outline,
    );
  }

  void _showSnackBar(
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    final state = _messengerKey.currentState;
    if (state == null) return;

    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
