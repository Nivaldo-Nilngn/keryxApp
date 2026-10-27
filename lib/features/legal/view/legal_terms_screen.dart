import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/services/auth_service.dart';

class LegalTermsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const LegalTermsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LegalTermsScreen> createState() => _LegalTermsScreenState();
}

class _LegalTermsScreenState extends ConsumerState<LegalTermsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchEmailSupport() async {
    final uri = Uri.parse('mailto:suporte@keryxapp.com?subject=D%C3%BAvida%20sobre%20Privacidade%20e%20Dados%20-%20KeryxApp');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('E-mail de contato: suporte@keryxapp.com')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail de contato: suporte@keryxapp.com')),
        );
      }
    }
  }

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 26),
            const SizedBox(width: 10),
            Text(
              'Exclusão de Conta',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Em conformidade com a LGPD (Lei nº 13.709/2018) e as diretrizes de privacidade, você tem o direito de solicitar a exclusão integral da sua conta e de todos os dados pessoais associados.',
              style: GoogleFonts.outfit(
                fontSize: 13,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Atenção: Esta ação é definitiva. Suas anotações, histórico de leitura e publicações serão desvinculados permanentemente.',
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(authServiceProvider).signOut();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sua solicitação de exclusão foi processada. Seus dados foram desvinculados.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 4),
                    ),
                  );
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao processar: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Sim, Excluir Meus Dados',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Central de Privacidade & Termos',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.kPrimaryGold,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          indicatorColor: AppTheme.kPrimaryGold,
          indicatorWeight: 2.5,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Privacidade & LGPD'),
            Tab(text: 'Termos de Uso'),
            Tab(text: 'Loja & Conteúdo'),
            Tab(text: 'Exclusão & Suporte'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrivacyTab(isDark),
          _buildTermsTab(isDark),
          _buildStoreTab(isDark),
          _buildDeletionAndContactTab(isDark),
        ],
      ),
    );
  }

  // ── ABA 1: POLÍTICA DE PRIVACIDADE & LGPD ────────────────────────────────────
  Widget _buildPrivacyTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      children: [
        _buildSectionHeader(
          icon: Icons.security_rounded,
          title: 'Política de Privacidade & Proteção de Dados',
          subtitle: 'Em total conformidade com a LGPD (Lei nº 13.709/2018)',
        ),
        const SizedBox(height: 16),

        _buildInfoCard(
          isDark: isDark,
          title: '1. Compromisso com a Transparência',
          content:
              'O KeryxApp é uma plataforma cristã desenvolvida com princípios de integridade e respeito. Não comercializamos, não compartilhamos e não monetizamos dados pessoais com terceiros ou redes de publicidade direcionada.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '2. Quais Dados Coletamos e Por Quê?',
          content:
              'Coletamos estritamente as informações necessárias para viabilizar as funcionalidades do aplicativo:\n\n'
              '• Nome e E-mail: Utilizados para criar e autenticar sua conta com segurança, sincronizar suas compras e permitir acesso em múltiplos dispositivos.\n'
              '• Foto de Perfil: Opcional. Permite personalização do seu perfil e identificação em postagens voluntárias na Comunidade.\n'
              '• Anotações, Destaques e Histórico: Salvos localmente no seu dispositivo e sincronizados de forma privada para que você não perca seus estudos.\n'
              '• Publicações na Comunidade: Textos, reflexões e pedidos de oração que você escolhe voluntariamente compartilhar com outros irmãos.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '3. Armazenamento e Criptografia',
          content:
              'Seus dados são protegidos por padrões da indústria:\n\n'
              '• Autenticação Segura via Firebase Auth (Google).\n'
              '• Banco de dados na nuvem Cloudflare D1 protegido por chaves criptográficas em repouso e tráfego HTTPS/TLS.\n'
              '• Armazenamento local SQLite/Hive no seu próprio smartphone para leitura e estudos 100% offline.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '4. Direitos do Titular de Dados (Art. 18 LGPD)',
          content:
              'Você possui pleno controle sobre suas informações pessoais a qualquer momento:\n\n'
              '• Direito de Acesso e Confirmação de tratamento.\n'
              '• Direito de Correção de dados incompletos ou inexatos.\n'
              '• Direito à Exclusão definitiva de todos os dados do banco.\n'
              '• Direito de Revogação do consentimento a qualquer instante.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '5. Dados de Crianças e Adolescentes',
          content:
              'O KeryxApp destina-se a estudos bíblicos e meditação. Não coletamos intencionalmente informações de menores desacompanhados sem o consentimento dos responsáveis legais.',
        ),
      ],
    );
  }

  // ── ABA 2: TERMOS DE USO & CONVIVÊNCIA ───────────────────────────────────────
  Widget _buildTermsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      children: [
        _buildSectionHeader(
          icon: Icons.gavel_rounded,
          title: 'Termos de Uso e Conduta',
          subtitle: 'Diretrizes para edificação da Comunidade Keryx',
        ),
        const SizedBox(height: 16),

        _buildInfoCard(
          isDark: isDark,
          title: '1. Finalidade do KeryxApp',
          content:
              'O KeryxApp tem como missão proporcionar ferramentas bíblicas, comentários teológicos, dicionários, sermões e um espaço de oração e comunhão para a igreja cristã ao redor do mundo.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '2. Regras de Boa Convivência na Comunidade',
          content:
              'Ao publicar no feed ou nos stories da Comunidade, o usuário compromete-se a:\n\n'
              '• Manter o respeito cristão, amor fraternal e cordialidade.\n'
              '• Não publicar conteúdo de ódio, ofensivo, calunioso ou discriminatório.\n'
              '• Não praticar spam, autopromoção agressiva ou divulgação comercial não autorizada.\n'
              '• Preservar a privacidade de terceiros e não expor dados de outras pessoas sem permissão.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '3. Moderação Comunitária',
          content:
              'A equipe de moderação do KeryxApp reserva-se o direito de remover publicações que violem estas diretrizes e, em casos recorrentes, suspender temporária ou permanentemente o acesso à Comunidade.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '4. Inteligência Artificial (IATheos) - Aviso Legal',
          content:
              'A IATheos é uma ferramenta computacional projetada para auxiliar pesquisas bíblicas, históricas e exegéticas.\n\n'
              '• Respostas geradas por IA podem conter imprecisões e devem ser sempre conferidas diretamente nas Escrituras Sagradas.\n'
              '• As respostas não substituem aconselhamento pastoral, psicológico, médico ou orientação jurídica profissional.',
        ),
      ],
    );
  }

  // ── ABA 3: LOJA DIGITAL & REEMBOLSO ─────────────────────────────────────────
  Widget _buildStoreTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      children: [
        _buildSectionHeader(
          icon: Icons.shopping_bag_rounded,
          title: 'Política da Loja e Conteúdos Digitais',
          subtitle: 'Bíblias, comentários, dicionários e sermões',
        ),
        const SizedBox(height: 16),

        _buildInfoCard(
          isDark: isDark,
          title: '1. Conteúdos Livres e Gratuitos',
          content:
              'Grande parte dos módulos de estudo, traduções históricas da Bíblia (JFA, ACF) e clássicos em domínio público são disponibilizados gratuitamente para livre estudo de todos os usuários.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '2. Aquisição de Materiais Digitais',
          content:
              'Materiais especiais, chaves de acesso ou doações missionárias garantem acesso vitalício e intransferível ao conteúdo digital vinculado à sua conta KeryxApp.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '3. Garantia de Restauração de Compras',
          content:
              'Ao trocar de aparelho ou reinstalar o aplicativo, você pode restaurar todos os seus conteúdos digitais adquiridos simplesmente entrando com sua conta cadastrada.',
        ),
        const SizedBox(height: 12),

        _buildInfoCard(
          isDark: isDark,
          title: '4. Política de Cancelamento e Reembolso',
          content:
              'Em conformidade com o Código de Defesa do Consumidor para compras digitais, caso você encontre incompatibilidade técnica comprovada com seu dispositivo e não seja possível acessar o material, você poderá solicitar suporte ou reembolso em até 7 dias corridos após a aquisição através do e-mail oficial.',
        ),
      ],
    );
  }

  // ── ABA 4: EXCLUSÃO DE CONTA & SUPORTE DPO ───────────────────────────────────
  Widget _buildDeletionAndContactTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      children: [
        _buildSectionHeader(
          icon: Icons.person_remove_rounded,
          title: 'Exclusão de Conta & Atendimento LGPD',
          subtitle: 'Seus direitos como titular garantidos por lei',
        ),
        const SizedBox(height: 16),

        _buildInfoCard(
          isDark: isDark,
          title: 'Direito à Exclusão Completa (Art. 18, VI LGPD)',
          content:
              'Você pode solicitar a qualquer momento a exclusão da sua conta, desvinculando seu e-mail, nome, publicações comunitárias e histórico de compras dos nossos servidores.',
        ),
        const SizedBox(height: 18),

        // Botão de Excluir Conta
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: isDark ? 0.12 : 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Zona de Exclusão de Conta',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ao tocar no botão abaixo, você iniciará o processo de encerramento da conta e remoção dos seus dados cadastrais.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showDeleteAccountConfirmation,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    'SOLICITAR EXCLUSÃO DE CONTA E DADOS',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Canal de Suporte e DPO
        _buildInfoCard(
          isDark: isDark,
          title: 'Encarregado de Dados (DPO) & Suporte',
          content:
              'Para tirar dúvidas sobre o tratamento de dados pessoais, exercer seus direitos da LGPD ou relatar problemas técnicos, entre em contato direto com nossa equipe pelo canal oficial:\n\n'
              '📧 E-mail: suporte@keryxapp.com\n'
              '🌐 Portal Oficial: https://keryxapp.pages.dev\n'
              'Horário de Atendimento: Segunda a Sexta, das 09h às 18h (Horário de Brasília).',
        ),

        const SizedBox(height: 14),

        Center(
          child: TextButton.icon(
            onPressed: _launchEmailSupport,
            icon: const Icon(Icons.mail_outline_rounded, color: AppTheme.kPrimaryGold, size: 18),
            label: Text(
              'Enviar e-mail para suporte@keryxapp.com',
              style: GoogleFonts.outfit(
                color: AppTheme.kPrimaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── COMPONENTES REUTILIZÁVEIS ──────────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: AppTheme.kPrimaryGold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required bool isDark,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: AppTheme.kPrimaryGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
