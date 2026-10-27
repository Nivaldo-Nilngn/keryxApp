import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/legal/view/legal_terms_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isShorter = screenSize.height < 750;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background Glows
          _buildBackgroundGlows(screenSize),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 1),

                    // App Logo Small
                    _buildLogo(isShorter),
                    
                    SizedBox(height: isShorter ? 12 : 20),
                    
                    Text(
                      'Criar Conta',
                      style: GoogleFonts.outfit(
                        fontSize: isShorter ? 26 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Comece sua jornada espiritual hoje',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.white60,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    
                    const Spacer(flex: 2),

                    // Card
                    _buildSignUpCard(isShorter),

                    const Spacer(flex: 2),

                    _buildFooter(),
                    
                    const SizedBox(height: 16),
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
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.kPrimaryGold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: _GlowCircle(
            size: 300,
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
            blur: 100,
          ),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: _GlowCircle(
            size: 250,
            color: const Color(0xFF6366F1).withValues(alpha: 0.05),
            blur: 80,
          ),
        ),
      ],
    );
  }

  Widget _buildLogo(bool isShorter) {
    return Container(
      width: isShorter ? 60 : 80,
      height: isShorter ? 60 : 80,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: [AppTheme.kPrimaryGold, AppTheme.kPrimaryGold.withValues(alpha: 0.4)]),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.kBackgroundDark,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Image.asset(
          'assets/img/logoHome.png',
          semanticLabel: 'Logotipo Keryx',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.auto_stories_rounded, color: AppTheme.kPrimaryGold),
        ),
      ),
    );
  }

  Widget _buildSignUpCard(bool isShorter) {
    return GlassCard(
      borderRadius: 28,
      blur: 25,
      color: const Color(0xFF0F0F2D).withValues(alpha: 0.6),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isShorter ? 16 : 24),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'NOME COMPLETO',
            hint: 'Como podemos te chamar?',
            icon: Icons.person_outline_rounded,
            isShorter: isShorter,
            validator: (v) => v!.isEmpty ? 'Informe seu nome' : null,
          ),
          SizedBox(height: isShorter ? 12 : 16),
          _buildTextField(
            controller: _emailController,
            label: 'E-MAIL',
            hint: 'seu@email.com',
            icon: Icons.alternate_email_rounded,
            isShorter: isShorter,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => v!.contains('@') ? null : 'E-mail inválido',
          ),
          SizedBox(height: isShorter ? 12 : 16),
          _buildTextField(
            controller: _passwordController,
            label: 'SENHA',
            hint: 'Mínimo 6 caracteres',
            icon: Icons.lock_outline_rounded,
            isShorter: isShorter,
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: Colors.white38,
                size: 18,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            validator: (v) => v!.length >= 6 ? null : 'Mínimo 6 caracteres',
          ),
          SizedBox(height: isShorter ? 12 : 16),
          _buildTextField(
            controller: _confirmPasswordController,
            label: 'CONFIRMAR SENHA',
            hint: 'Repita sua senha',
            icon: Icons.lock_reset_rounded,
            isShorter: isShorter,
            obscureText: true,
            validator: (v) => v == _passwordController.text ? null : 'Senhas não conferem',
          ),
          SizedBox(height: isShorter ? 20 : 28),
          _buildSignUpButton(isShorter),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isShorter,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white30,
            letterSpacing: 1.5,
          ),
        ),
        SizedBox(height: isShorter ? 4 : 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(color: Colors.white12, fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.white24, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.kPrimaryGold.withValues(alpha: 0.3)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isShorter ? 12 : 16),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSignUpButton(bool isShorter) {
    return Container(
      width: double.infinity,
      height: isShorter ? 48 : 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.kPrimaryGold,
          foregroundColor: AppTheme.kBackgroundDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _handleSignUp,
        child: Text(
          'CADASTRAR',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Ao cadastrar, você concorda com os ',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
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
                  color: AppTheme.kPrimaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' e ',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
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
                  color: AppTheme.kPrimaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Já tem uma conta? ',
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text(
                'Entrar agora',
                style: GoogleFonts.outfit(
                  color: AppTheme.kPrimaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta criada com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double blur;
  const _GlowCircle({required this.size, required this.color, required this.blur});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: Container(color: Colors.transparent)),
    );
  }
}
