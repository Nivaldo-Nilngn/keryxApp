import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Exibe o guia interativo de instalação do PWA no iPhone (iOS) e Android/PC.
void showPwaInstallGuide(BuildContext context) {
  final isTablet = MediaQuery.of(context).size.width >= 600;

  if (isTablet) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: const _PwaInstallContent(isDialog: true),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _PwaInstallContent(isDialog: false),
    );
  }
}

class _PwaInstallContent extends StatefulWidget {
  final bool isDialog;
  const _PwaInstallContent({required this.isDialog});

  @override
  State<_PwaInstallContent> createState() => _PwaInstallContentState();
}

class _PwaInstallContentState extends State<_PwaInstallContent> {
  // 0 = iOS (iPhone/iPad), 1 = Android / Computador
  int _selectedPlatform = 0;

  @override
  void initState() {
    super.initState();
    // Tenta detectar a plataforma padrão
    if (kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _selectedPlatform = 1;
      } else {
        _selectedPlatform = 0; // Padrão iOS para atender o foco do usuário
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141529) : Colors.white,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        widget.isDialog ? 24 : 12,
        22,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isDialog)
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.kPrimaryGold, Color(0xFFD4AF37)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.install_mobile_rounded,
                  color: Color(0xFF111223),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instalar Aplicativo (PWA)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use como um app nativo em tela cheia',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Seletor de Plataforma (iOS vs Android/PC)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F2F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPlatformTab(
                    index: 0,
                    label: 'iPhone / iPad (iOS)',
                    icon: Icons.apple_rounded,
                  ),
                ),
                Expanded(
                  child: _buildPlatformTab(
                    index: 1,
                    label: 'Android / PC',
                    icon: Icons.android_rounded,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Conteúdo do Guia dependendo da plataforma
          if (_selectedPlatform == 0)
            _buildIosGuide(context)
          else
            _buildAndroidGuide(context),

          const SizedBox(height: 22),

          // Vantagens do PWA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: AppTheme.kPrimaryGold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Não ocupa espaço de download na App Store e atualiza automaticamente!',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.kPrimaryGold,
              foregroundColor: const Color(0xFF111223),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Entendido',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );

    return content;
  }

  Widget _buildPlatformTab({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedPlatform == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlatform = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.kPrimaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF111223) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color: isSelected ? const Color(0xFF111223) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosGuide(BuildContext context) {
    return Column(
      children: [
        _buildStepItem(
          stepNumber: '1',
          icon: Icons.public_rounded,
          title: 'Abra no Safari',
          description: 'Certifique-se de estar acessando o aplicativo pelo navegador Safari do seu iPhone.',
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          stepNumber: '2',
          icon: Icons.ios_share_rounded,
          title: 'Toque em Compartilhar',
          description: 'Toque no ícone de Compartilhar (o quadrado com a seta para cima, na barra inferior do Safari).',
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          stepNumber: '3',
          icon: Icons.add_box_outlined,
          title: 'Adicionar à Tela de Início',
          description: 'Role as opções para baixo e selecione "Adicionar à Tela de Início" (Add to Home Screen).',
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          stepNumber: '4',
          icon: Icons.check_circle_outline_rounded,
          title: 'Toque em "Adicionar"',
          description: 'Confirme no canto superior direito. O ícone do Keryx aparecerá na sua tela como um app nativo!',
        ),
      ],
    );
  }

  Widget _buildAndroidGuide(BuildContext context) {
    return Column(
      children: [
        _buildStepItem(
          stepNumber: '1',
          icon: Icons.public_rounded,
          title: 'Abra no Google Chrome',
          description: 'Acesse o aplicativo pelo navegador Google Chrome no Android ou Computador.',
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          stepNumber: '2',
          icon: Icons.more_vert_rounded,
          title: 'Abra o Menu (⋮)',
          description: 'Toque nos três pontinhos no canto superior direito do navegador.',
        ),
        const SizedBox(height: 12),
        _buildStepItem(
          stepNumber: '3',
          icon: Icons.download_rounded,
          title: 'Instalar Aplicativo',
          description: 'Selecione "Instalar aplicativo" ou "Adicionar à tela inicial" e confirme.',
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B30) : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.kPrimaryGold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.kPrimaryGold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppTheme.kPrimaryGold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
