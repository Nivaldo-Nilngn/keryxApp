import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

void showEditProfileModal(BuildContext context, WidgetRef ref) {
  final isTablet = MediaQuery.of(context).size.width >= 600;

  if (isTablet) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: const _EditProfileContent(isDialog: true),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _EditProfileContent(isDialog: false),
    );
  }
}

class _EditProfileContent extends ConsumerStatefulWidget {
  final bool isDialog;
  const _EditProfileContent({required this.isDialog});

  @override
  ConsumerState<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends ConsumerState<_EditProfileContent> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  String? _previewPhoto;
  bool _isLoading = false;
  bool _showUrlField = false;

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authServiceProvider).currentUser;
    final userData = ref.read(userDataProvider).valueOrNull;

    final initialName = userData?['name'] ?? authUser?.displayName ?? '';
    _previewPhoto = userData?['photoUrl'] ?? authUser?.photoURL;

    _nameController = TextEditingController(text: initialName);
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final rawBytes = file.bytes;
        if (rawBytes != null && rawBytes.isNotEmpty) {
          String? processed;
          try {
            final decoded = img.decodeImage(rawBytes);
            if (decoded != null) {
              final resized = img.copyResize(decoded, width: 256, height: 256);
              final compressedJpg = img.encodeJpg(resized, quality: 85);
              processed = 'data:image/jpeg;base64,${base64Encode(compressedJpg)}';
            }
          } catch (_) {
            if (rawBytes.length <= 400 * 1024) {
              processed = 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
            }
          }

          if (processed != null) {
            setState(() {
              _previewPhoto = processed;
            });
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Imagem muito grande. Tente outra foto menor.')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao escolher imagem: $e')),
        );
      }
    }
  }

  void _applyUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _previewPhoto = url;
        _showUrlField = false;
      });
      _urlController.clear();
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, informe um nome válido.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authServiceProvider).updateProfile(
        displayName: newName,
        photoUrl: _previewPhoto,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Perfil atualizado com sucesso!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Erro ao salvar alterações: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'U';

    Widget avatarImage;
    if (_previewPhoto != null && _previewPhoto!.isNotEmpty) {
      if (_previewPhoto!.startsWith('data:image') || !_previewPhoto!.startsWith('http')) {
        try {
          final clean = _previewPhoto!.contains(',') ? _previewPhoto!.split(',').last : _previewPhoto!;
          avatarImage = Image.memory(
            base64Decode(clean),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitial(initial),
          );
        } catch (_) {
          avatarImage = _buildFallbackInitial(initial);
        }
      } else {
        String finalUrl = _previewPhoto!;
        if (finalUrl.contains('googleusercontent.com')) {
          finalUrl = finalUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
        }
        if (kIsWeb && finalUrl.startsWith('http') && !finalUrl.contains('wsrv.nl')) {
          finalUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(finalUrl)}';
        }
        avatarImage = Image.network(
          finalUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackInitial(initial),
        );
      }
    } else {
      avatarImage = _buildFallbackInitial(initial);
    }

    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Barra de arraste para mobile
          if (!widget.isDialog)
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          // Título
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.manage_accounts_rounded, color: AppTheme.kPrimaryGold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Editar Perfil',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Avatar Grande Centralizado com Badge de Câmera
          GestureDetector(
            onTap: _pickImageFromDevice,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.kPrimaryGold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(child: avatarImage),
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF111223) : Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Botões de Ação para Foto
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickImageFromDevice,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: const Text('Escolher Foto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showUrlField = !_showUrlField),
                icon: const Icon(Icons.link_rounded, size: 16),
                label: const Text('Colar Link'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              if (_previewPhoto != null && _previewPhoto!.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() => _previewPhoto = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: const Text('Remover', style: TextStyle(color: Color(0xFFEF4444))),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
            ],
          ),

          // Campo de URL se aberto
          if (_showUrlField) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://exemplo.com/foto.jpg',
                      hintStyle: GoogleFonts.manrope(fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyUrl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kPrimaryGold,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Campo de Nome
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'NOME DE EXIBIÇÃO',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.person_rounded, color: AppTheme.kPrimaryGold.withValues(alpha: 0.8)),
              hintText: 'Digite seu nome completo',
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E30) : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.kPrimaryGold, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Botões de Ação Finais
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Cancelar',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.kPrimaryGold,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                        )
                      : Text(
                          'SALVAR ALTERAÇÕES',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: content,
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Container(
      color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          fontSize: 38,
          fontWeight: FontWeight.bold,
          color: AppTheme.kPrimaryGold,
        ),
      ),
    );
  }
}
