import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import '../services/auth_service.dart';
import '../services/release_notes_service.dart';
import '../theme/app_theme.dart';
import '../theme/avatar_frame_options.dart';
import 'package:keryx_app/features/legal/view/legal_terms_screen.dart';

class _PresetAvatar {
  final String id;
  final String name;
  final String category;
  final String url;

  const _PresetAvatar({
    required this.id,
    required this.name,
    required this.category,
    required this.url,
  });
}

void showEditProfileModal(BuildContext context, WidgetRef ref) {
  final isTablet = MediaQuery.of(context).size.width >= 600;

  if (isTablet) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
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
  String _selectedFrame = 'gold';
  bool _isLoading = false;
  bool _showUrlField = false;
  String _selectedCategory = 'all';

  static List<AvatarFrameOption> get _frameOptions => AvatarFrameOption.options;

  static const List<_PresetAvatar> _presetAvatares = [
    // ── PERSONAGENS BÍBLICOS (40 Heróis e Mulheres da Fé) ──
    _PresetAvatar(
      id: 'david',
      name: 'Davi',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=David&backgroundColor=fef3c7',
    ),
    _PresetAvatar(
      id: 'esther',
      name: 'Ester',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Esther&backgroundColor=fce7f3',
    ),
    _PresetAvatar(
      id: 'paul',
      name: 'Paulo',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Paul&backgroundColor=e0e7ff',
    ),
    _PresetAvatar(
      id: 'ruth',
      name: 'Rute',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Ruth&backgroundColor=ffedd5',
    ),
    _PresetAvatar(
      id: 'samuel',
      name: 'Samuel',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Samuel&backgroundColor=ede9fe',
    ),
    _PresetAvatar(
      id: 'miriam',
      name: 'Miriã',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Miriam&backgroundColor=fae8ff',
    ),
    _PresetAvatar(
      id: 'john',
      name: 'João',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=John&backgroundColor=dbeafe',
    ),
    _PresetAvatar(
      id: 'sarah',
      name: 'Sara',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Sarah&backgroundColor=dcfce7',
    ),
    _PresetAvatar(
      id: 'timothy',
      name: 'Timóteo',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Timothy&backgroundColor=ffe4e6',
    ),
    _PresetAvatar(
      id: 'daniel',
      name: 'Daniel',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Daniel&backgroundColor=e2e8f0',
    ),
    _PresetAvatar(
      id: 'moses',
      name: 'Moisés',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Moses&backgroundColor=e0f2fe',
    ),
    _PresetAvatar(
      id: 'abraham',
      name: 'Abraão',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Abraham&backgroundColor=fef9c3',
    ),
    _PresetAvatar(
      id: 'noah',
      name: 'Noé',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Noah&backgroundColor=d1fae5',
    ),
    _PresetAvatar(
      id: 'peter',
      name: 'Pedro',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Peter&backgroundColor=fae8ff',
    ),
    _PresetAvatar(
      id: 'elijah',
      name: 'Elias',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Elijah&backgroundColor=ffedd5',
    ),
    _PresetAvatar(
      id: 'elisha',
      name: 'Eliseu',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Elisha&backgroundColor=f1f5f9',
    ),
    _PresetAvatar(
      id: 'joshua',
      name: 'Josué',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Joshua&backgroundColor=fef08a',
    ),
    _PresetAvatar(
      id: 'joseph',
      name: 'José',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Joseph&backgroundColor=f3e8ff',
    ),
    _PresetAvatar(
      id: 'solomon',
      name: 'Salomão',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Solomon&backgroundColor=fef3c7',
    ),
    _PresetAvatar(
      id: 'mary',
      name: 'Maria',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Mary&backgroundColor=fce7f3',
    ),
    _PresetAvatar(
      id: 'deborah',
      name: 'Débora',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Deborah&backgroundColor=fef3c7',
    ),
    _PresetAvatar(
      id: 'hannah',
      name: 'Ana',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Hannah&backgroundColor=ede9fe',
    ),
    _PresetAvatar(
      id: 'rebekah',
      name: 'Rebeca',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Rebekah&backgroundColor=ffedd5',
    ),
    _PresetAvatar(
      id: 'priscilla',
      name: 'Priscila',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Priscilla&backgroundColor=dcfce7',
    ),
    _PresetAvatar(
      id: 'abigail',
      name: 'Abigail',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Abigail&backgroundColor=fae8ff',
    ),
    _PresetAvatar(
      id: 'lydia',
      name: 'Lídia',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Lydia&backgroundColor=fae8ff',
    ),
    _PresetAvatar(
      id: 'naomi',
      name: 'Noemi',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Naomi&backgroundColor=e0f2fe',
    ),
    _PresetAvatar(
      id: 'elizabeth',
      name: 'Isabel',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Elizabeth&backgroundColor=fee2e2',
    ),
    _PresetAvatar(
      id: 'dorcas',
      name: 'Dorcas',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Dorcas&backgroundColor=fef9c3',
    ),
    _PresetAvatar(
      id: 'isaiah',
      name: 'Isaías',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Isaiah&backgroundColor=e0f2fe',
    ),
    _PresetAvatar(
      id: 'jeremiah',
      name: 'Jeremias',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Jeremiah&backgroundColor=ffedd5',
    ),
    _PresetAvatar(
      id: 'ezekiel',
      name: 'Ezequiel',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Ezekiel&backgroundColor=ede9fe',
    ),
    _PresetAvatar(
      id: 'nehemiah',
      name: 'Neemias',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Nehemiah&backgroundColor=dbeafe',
    ),
    _PresetAvatar(
      id: 'stephen',
      name: 'Estêvão',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Stephen&backgroundColor=fef9c3',
    ),
    _PresetAvatar(
      id: 'luke',
      name: 'Lucas',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Luke&backgroundColor=dbeafe',
    ),
    _PresetAvatar(
      id: 'james',
      name: 'Tiago',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=James&backgroundColor=dcfce7',
    ),
    _PresetAvatar(
      id: 'barnabas',
      name: 'Barnabé',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Barnabas&backgroundColor=f1f5f9',
    ),
    _PresetAvatar(
      id: 'silas',
      name: 'Silas',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Silas&backgroundColor=e0e7ff',
    ),
    _PresetAvatar(
      id: 'isaac',
      name: 'Isaque',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Isaac&backgroundColor=e0e7ff',
    ),
    _PresetAvatar(
      id: 'jacob',
      name: 'Jacó',
      category: 'characters',
      url: 'https://api.dicebear.com/7.x/notionists/png?seed=Jacob&backgroundColor=fee2e2',
    ),

    // ── FÉ & DEVOÇÃO ──
    _PresetAvatar(
      id: 'bible_light',
      name: 'Palavra Viva',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1499209974431-9dddcece7f88?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'cross_sunset',
      name: 'Redenção',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1518495973542-4542c06a5843?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'prayer_hands',
      name: 'Em Oração',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'peace_candle',
      name: 'Luz do Mundo',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1507692049790-de58290a4334?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'covenant_cross',
      name: 'Aliança da Cruz',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1509021436665-8f07dbf5bf1d?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'bread_life',
      name: 'Pão da Vida',
      category: 'faith',
      url: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=256&h=256&q=80',
    ),

    // ── SÍMBOLOS SAGRADOS ──
    _PresetAvatar(
      id: 'lion_judah',
      name: 'Leão de Judá',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1543946207-39bd91e70ca7?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'peace_dove',
      name: 'Espírito de Paz',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'lamb_god',
      name: 'Cordeiro da Paz',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1484557052118-f32bd25b45b5?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'olive_branch',
      name: 'Oliveira Florida',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1501004318641-b39e6451bec6?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'holy_fire',
      name: 'Fogo Santo',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1496337589254-7e19d01cec44?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'anchor_hope',
      name: 'Âncora Segura',
      category: 'symbols',
      url: 'https://images.unsplash.com/photo-1524338198850-8a2ff63aaceb?auto=format&fit=crop&w=256&h=256&q=80',
    ),

    // ── LOUVOR & ADORAÇÃO ──
    _PresetAvatar(
      id: 'harp_worship',
      name: 'Harpa e Louvor',
      category: 'worship',
      url: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'acoustic_praise',
      name: 'Cordas de Gratidão',
      category: 'worship',
      url: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'worship_choir',
      name: 'Vozes ao Altíssimo',
      category: 'worship',
      url: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'worship_heart',
      name: 'Adoração Viva',
      category: 'worship',
      url: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'music_ministry',
      name: 'Instrumento Sagrado',
      category: 'worship',
      url: 'https://images.unsplash.com/photo-1514320291840-2e0a9bf2a9ae?auto=format&fit=crop&w=256&h=256&q=80',
    ),

    // ── CRIAÇÃO DIVINA ──
    _PresetAvatar(
      id: 'mount_sinai',
      name: 'Monte da Fé',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'stars_glory',
      name: 'Céu Celestial',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'sunrise_grace',
      name: 'Amanhecer da Graça',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'prayer_summit',
      name: 'Lugar Secreto',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'restful_waters',
      name: 'Águas de Descanso',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?auto=format&fit=crop&w=256&h=256&q=80',
    ),
    _PresetAvatar(
      id: 'peaceful_garden',
      name: 'Jardim da Paz',
      category: 'nature',
      url: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=256&h=256&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final authUser = ref.read(authServiceProvider).currentUser;
    final userData = ref.read(userDataProvider).valueOrNull;

    final initialName = userData?['name'] ?? authUser?.displayName ?? '';
    _previewPhoto = userData?['photoUrl'] ?? authUser?.photoURL;
    _selectedFrame = userData?['avatarFrame'] ?? 'gold';

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

  void _selectPresetAvatar(_PresetAvatar avatar) {
    setState(() {
      _previewPhoto = avatar.url;
      _showUrlField = false;
    });
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
        avatarFrame: _selectedFrame,
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
    final containerBg = theme.scaffoldBackgroundColor;

    final initial = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()[0].toUpperCase()
        : 'U';

    final filteredPresets = _presetAvatares.where((p) {
      if (_selectedCategory == 'all') return true;
      return p.category == _selectedCategory;
    }).toList();

    final avatarImage = _buildAvatarWidget(_previewPhoto, initial);

    final content = SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!widget.isDialog)
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

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
              const SizedBox(width: 12),
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

          const SizedBox(height: 18),

          GestureDetector(
            onTap: _pickImageFromDevice,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                _buildFramedAvatar(
                  child: avatarImage,
                  frameId: _selectedFrame,
                  size: 104,
                  backgroundColor: containerBg,
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.kPrimaryGold,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF111223) : Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
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

          if (_showUrlField) ...[
            const SizedBox(height: 12),
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

          const SizedBox(height: 18),

          // SEÇÃO 1: CÍRCULOS DECORATIVOS DA FOTO
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191928) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.donut_large_rounded, color: AppTheme.kPrimaryGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CÍRCULO DECORATIVO DA FOTO',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 68,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _frameOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final frame = _frameOptions[index];
                      final isSelected = _selectedFrame == frame.id;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedFrame = frame.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF262638) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.kPrimaryGold
                                  : (isDark ? Colors.white12 : Colors.black12),
                              width: isSelected ? 1.8 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: frame.id != 'none'
                                      ? LinearGradient(
                                          colors: frame.colors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  border: frame.id == 'none'
                                      ? Border.all(color: Colors.grey, width: 1.5)
                                      : null,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: containerBg,
                                  ),
                                  child: Center(
                                    child: frame.id == 'none'
                                        ? const Icon(Icons.block, size: 12, color: Colors.grey)
                                        : (isSelected
                                            ? const Icon(Icons.check, size: 12, color: AppTheme.kPrimaryGold)
                                            : null),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                frame.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // SEÇÃO 2: AVATARES PRONTOS & PRÉ-DEFINIDOS
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF191928) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.palette_rounded, color: AppTheme.kPrimaryGold, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'OU ESCOLHA UM AVATAR PRONTO',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('✨ Todos', 'all', isDark),
                      const SizedBox(width: 6),
                      _buildCategoryChip('👤 Personagens', 'characters', isDark),
                      const SizedBox(width: 6),
                      _buildCategoryChip('📖 Fé & Devoção', 'faith', isDark),
                      const SizedBox(width: 6),
                      _buildCategoryChip('🕊️ Símbolos', 'symbols', isDark),
                      const SizedBox(width: 6),
                      _buildCategoryChip('🎶 Louvor', 'worship', isDark),
                      const SizedBox(width: 6),
                      _buildCategoryChip('🌄 Criação', 'nature', isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  height: 94,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredPresets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = filteredPresets[index];
                      final isSelected = _previewPhoto == item.url;

                      return GestureDetector(
                        onTap: () => _selectPresetAvatar(item),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.kPrimaryGold
                                          : (isDark ? Colors.white24 : Colors.black12),
                                      width: isSelected ? 3 : 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppTheme.kPrimaryGold.withValues(alpha: 0.4),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: ClipOval(
                                    child: Image.network(
                                      item.url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                                        child: const Icon(Icons.person, color: AppTheme.kPrimaryGold, size: 24),
                                      ),
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                        color: AppTheme.kPrimaryGold,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        color: Colors.black,
                                        size: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            SizedBox(
                              width: 64,
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.kPrimaryGold
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

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
              fontSize: 15.5,
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
          const SizedBox(height: 14),

          // Opção de Criar/Definir Senha para quem logou com Google
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E30) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.password_rounded, color: AppTheme.kPrimaryGold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Senha para Login sem Google',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Cadastre uma senha para logar em outros aparelhos',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showSetPasswordDialog,
                  child: Text(
                    'Definir Senha',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.kPrimaryGold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── NOTAS DE ATUALIZAÇÃO / O QUE HÁ DE NOVO ───────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF818CF8), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notas de Atualização',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Veja os novos recursos e modificações do KeryxApp',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(releaseNotesServiceProvider).showReleaseNotes(context);
                  },
                  child: Text(
                    'Ver Novidades',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF818CF8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── PRIVACIDADE, TERMOS DE USO & LGPD ─────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacidade & Termos (LGPD)',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        'Seus direitos, segurança de dados e regras',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalTermsScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'Consultar',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
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
                    padding: const EdgeInsets.symmetric(vertical: 15),
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

  Widget _buildFramedAvatar({
    required Widget child,
    required String frameId,
    required double size,
    required Color backgroundColor,
  }) {
    final frame = _frameOptions.firstWhere(
      (f) => f.id == frameId,
      orElse: () => _frameOptions.first,
    );

    if (frame.id == 'none') {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
        ),
        child: ClipOval(child: child),
      );
    }

    final borderThickness = size > 60 ? 3.5 : 2.0;
    final gapThickness = size > 60 ? 2.5 : 1.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
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
            color: frame.shadowColor.withValues(alpha: 0.45),
            blurRadius: size > 60 ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(gapThickness),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        child: ClipOval(child: child),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, bool isDark) {
    final isSelected = _selectedCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.kPrimaryGold.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF222234) : const Color(0xFFEEF2F6)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.kPrimaryGold : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? AppTheme.kPrimaryGold
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String? photo, String initial) {
    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('data:image') || !photo.startsWith('http')) {
        try {
          final clean = photo.contains(',') ? photo.split(',').last : photo;
          return Image.memory(
            base64Decode(clean),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackInitial(initial),
          );
        } catch (_) {
          return _buildFallbackInitial(initial);
        }
      } else {
        String finalUrl = photo;
        if (finalUrl.contains('googleusercontent.com')) {
          finalUrl = finalUrl.replaceAll(RegExp(r'=s\d+(-c)?'), '=s256-c');
        }
        if (kIsWeb && finalUrl.startsWith('http') && !finalUrl.contains('wsrv.nl')) {
          finalUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(finalUrl)}';
        }
        return Image.network(
          finalUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackInitial(initial),
        );
      }
    }
    return _buildFallbackInitial(initial);
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

  void _showSetPasswordDialog() {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.lock_rounded, color: AppTheme.kPrimaryGold, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Criar Senha de Acesso',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Com esta senha, você poderá entrar na Bíblia digitando seu e-mail e senha em qualquer celular, tablet ou computador, mesmo se o aparelho não tiver sua conta Google conectada!',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Nova Senha',
                    hintText: 'Mínimo 6 caracteres',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Nova Senha',
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final p1 = passController.text.trim();
                        final p2 = confirmController.text.trim();
                        if (p1.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A senha deve ter no mínimo 6 caracteres.')),
                          );
                          return;
                        }
                        if (p1 != p2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('As senhas não conferem.')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          await ref.read(authServiceProvider).setPasswordForCurrentUser(p1);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Senha cadastrada com sucesso! Agora você pode entrar com seu e-mail e senha em qualquer aparelho.'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 5),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao salvar senha: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.kPrimaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text('Salvar Senha', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
