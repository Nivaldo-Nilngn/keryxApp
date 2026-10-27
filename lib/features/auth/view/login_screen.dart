import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/auth/view/signup_screen.dart';
import 'package:keryx_app/features/legal/view/legal_terms_screen.dart';



class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Entrada em sequência, no mesmo espírito da splash: anel → logo → texto → resto.
  late final AnimationController _intro;
  late final AnimationController _breath;
  late final Animation<double> _ring;
  late final Animation<double> _logo;
  late final Animation<double> _title;
  late final Animation<double> _card;
  late final Animation<double> _footer;

  @override
  void initState() {
    super.initState();

    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _ring = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.45, curve: Curves.easeInOutCubic),
    );
    _logo = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.1, 0.4, curve: Curves.easeOut),
    );
    _title = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 0.6, curve: Curves.easeOut),
    );
    _card = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.5, 0.85, curve: Curves.easeOut),
    );
    _footer = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
    );

    if (reduceMotion) {
      _intro.value = 1.0;
    } else {
      _intro.forward();
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isShorter = screenSize.height < 700;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [Theme.of(context).colorScheme.surfaceContainer, Theme.of(context).scaffoldBackgroundColor],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Spacer(flex: 2),

                      _buildEmblem(isShorter),
                      SizedBox(height: isShorter ? 16 : 24),

                      FadeTransition(
                        opacity: _title,
                        child: _buildTitle(isShorter),
                      ),

                      const Spacer(flex: 3),

                      FadeTransition(
                        opacity: _card,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.03),
                            end: Offset.zero,
                          ).animate(_card),
                          child: _buildLoginCard(isShorter),
                        ),
                      ),

                      const Spacer(flex: 2),

                      FadeTransition(
                        opacity: _footer,
                        child: _buildSecondaryActions(context, isShorter),
                      ),

                      const Spacer(flex: 1),

                      FadeTransition(opacity: _footer, child: _buildFooter()),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            if (_isLoading)
              Container(
                color: Colors.black45,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Center(
                    child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Mesmo emblema da splash: logo circular, brilho "respirando" e anel dourado
  /// que se desenha na entrada. Aqui o anel fica completo (tela estática).
  Widget _buildEmblem(bool isShorter) {
    final gold = Theme.of(context).colorScheme.primary;
    final ringSize = isShorter ? 108.0 : 128.0;
    final logoSize = isShorter ? 68.0 : 80.0;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: _logo,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (_, __) => Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.10 + 0.12 * _breath.value),
                      blurRadius: 30 + 14 * _breath.value,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: _logo,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(_logo),
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14142B),
                  border: Border.all(color: gold.withValues(alpha: 0.30), width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/img/logoHome.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_stories_rounded,
                      color: gold,
                      size: logoSize * 0.42,
                    ),
                  ),
                ),
              ),
            ),
          ),
          CustomPaint(
            size: Size(ringSize, ringSize),
            painter: _RingPainter(_ring, gold),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(bool isShorter) {
    return Column(
      children: [
        Text(
          'Keryx App',
          style: GoogleFonts.outfit(
            fontSize: isShorter ? 24 : 28,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ilumine seu caminho com a Escritura',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: isShorter ? 12 : 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(bool isShorter) {
    return GlassCard(
      borderRadius: 28,
      blur: 25,
      color: Theme.of(context).cardColor.withValues(alpha: 0.8),
      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isShorter ? 16 : 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildGoogleButton(isShorter),
          SizedBox(height: isShorter ? 12 : 20),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OU',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
            ],
          ),
          SizedBox(height: isShorter ? 12 : 20),
          _buildTextField(
            label: 'E-MAIL',
            hint: 'seu@email.com',
            icon: Icons.alternate_email_rounded,
            controller: _emailController,
            isShorter: isShorter,
            validator: (v) => v!.contains('@') ? null : 'E-mail inválido',
          ),
          SizedBox(height: isShorter ? 10 : 16),
          _buildTextField(
            label: 'SENHA',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            controller: _passwordController,
            isShorter: isShorter,
            validator: (v) => v!.length >= 6 ? null : 'Mínimo 6 caracteres',
            trailing: IconButton(
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          SizedBox(height: isShorter ? 16 : 24),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface,
                foregroundColor: Theme.of(context).colorScheme.surface,
                minimumSize: Size(double.infinity, isShorter ? 48 : 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                'ENTRAR',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.lock_reset_rounded, color: AppTheme.kPrimaryGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Criar ou Redefinir Senha',
                    style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se você criou sua conta usando o Google ou esqueceu sua senha, informe seu e-mail abaixo.\n\nEnviaremos um link oficial para você cadastrar uma senha de acesso e poder entrar em qualquer aparelho!',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.outfit(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Seu E-mail',
                    hintText: 'exemplo@gmail.com',
                    prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
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
                onPressed: isSending
                    ? null
                    : () async {
                        final email = resetEmailController.text.trim();
                        if (email.isEmpty || !email.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe um e-mail válido.')),
                          );
                          return;
                        }
                        setDialogState(() => isSending = true);
                        try {
                          await ref.read(authServiceProvider).sendPasswordResetEmail(email);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Link enviado para $email! Verifique sua caixa de entrada e spam para definir sua senha.'),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSending = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Erro ao enviar link: $e'),
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
                child: isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text('Enviar Link', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        String message = 'Erro ao entrar. Verifique seus dados.';
        if (e.toString().contains('invalid-credential') || e.toString().contains('wrong-password')) {
          message = 'E-mail ou senha incorretos.\nSe você cadastrou sua conta pelo Google, toque em "ESQUECI A SENHA" para criar uma senha para ela.';
        } else if (e.toString().contains('user-not-found')) {
          message = 'E-mail não cadastrado. Crie uma conta ou entre com Google.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF1E1E2C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Criar Senha',
              textColor: AppTheme.kPrimaryGold,
              onPressed: _showForgotPasswordDialog,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      // Sucesso: deixa o _isLoading ligado — a navegação para a home
      // acontece por fora (AuthWrapper), então a tela de login some
      // com o loading ainda visível, sem "piscar" o formulário de novo.
    } catch (e) {
      if (mounted) {
        // Se o usuário cancelou a seleção de conta, não é bem um "erro".
        final cancelled = e.toString().toLowerCase().contains('cancel');
        if (!cancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao entrar com Google: $e'),
              backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGoogleButton(bool isShorter) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _handleGoogleLogin,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: isShorter ? 48 : 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    ' G ',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Entrar com Google',
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required TextEditingController controller,
    required bool isShorter,
    String? Function(String?)? validator,
    Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 1.5,
              ),
            ),
            if (isPassword)
              GestureDetector(
                onTap: _showForgotPasswordDialog,
                child: Text(
                  'ESQUECI A SENHA',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.kPrimaryGold,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isShorter ? 4 : 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: isPassword && !_isPasswordVisible,
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), fontSize: 14),
            prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 18),
            suffixIcon: trailing,
            filled: true,
            fillColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isShorter ? 12 : 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryActions(BuildContext context, bool isShorter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Novo por aqui? ',
          style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 14),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            );
          },
          child: Text(
            'Criar conta agora',
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Rodapé com links de conformidade LGPD e Termos de Uso
  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Ao continuar, você aceita os ',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalTermsScreen(initialTabIndex: 1),
                  ),
                );
              },
              child: Text(
                'Termos',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.95),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' e a ',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LegalTermsScreen(initialTabIndex: 0),
                  ),
                );
              },
              child: Text(
                'Privacidade (LGPD)',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.kPrimaryGold.withValues(alpha: 0.95),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'ιχθύς • Keryx',
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

/// Mesmo anel dourado da splash screen, desenhado do topo, sentido horário.
class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.12 * progress.value),
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.color != color || old.progress != progress;
}