import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/glass_card.dart';

/// Wrapper que protege telas que exigem login.
/// Usuários não autenticados veem uma tela de "Acesso Exclusivo" com CTA de login.
class AuthGuard extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final IconData featureIcon;

  const AuthGuard({
    super.key,
    required this.child,
    this.featureName = 'este recurso',
    this.featureIcon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Erro ao verificar autenticação', style: TextStyle(color: Colors.white54))),
      ),
      data: (user) {
        if (user != null) return child;

        // Tela de bloqueio elegante
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.2,
                colors: [
                  Color(0xFF1A1A3A),
                  AppTheme.kBackgroundDark,
                ],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.5)),
                          ),
                          child: Icon(featureIcon, color: AppTheme.kPrimaryGold, size: 36),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Acesso Exclusivo',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppTheme.kPrimaryGold,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Para acessar $featureName e sincronizar seus dados na nuvem, faça login na sua conta.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              ref.read(guestModeProvider.notifier).state = false;
                              // O AuthWrapper no main.dart cuidará de mostrar a LoginScreen
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.kPrimaryGold,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Entrar com sua conta', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Mais tarde', style: TextStyle(color: AppTheme.kPrimaryGold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
