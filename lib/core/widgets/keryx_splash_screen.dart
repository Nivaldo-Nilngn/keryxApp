import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Splash screen do Keryx.
///
/// - Se [initFuture] for fornecido, exibe uma barra de progresso com
///   [statusMessages] e chama [onReady] ao concluir.
/// - Sem [initFuture], exibe apenas o spinner (comportamento legado).
///
/// Momento memorável: um anel dourado que se desenha em volta do logo.
/// O resto fica quieto, para o anel ser a única coisa que chama atenção.
class KeryxSplashScreen extends StatefulWidget {
  final String? message;

  /// Future que representa a inicialização (ex.: cópia do DB).
  final Future<void> Function()? initFuture;

  /// Chamado quando [initFuture] termina — navega para a próxima rota.
  final VoidCallback? onReady;

  /// Mensagens exibidas progressivamente durante [initFuture].
  final List<String> statusMessages;

  const KeryxSplashScreen({
    super.key,
    this.message,
    this.initFuture,
    this.onReady,
    this.statusMessages = const [
      'Preparando as Escrituras...',
      'Carregando concordância Strong...',
      'Quase lá...',
    ],
  });

  @override
  State<KeryxSplashScreen> createState() => _KeryxSplashScreenState();
}

class _KeryxSplashScreenState extends State<KeryxSplashScreen>
    with TickerProviderStateMixin {
  static const _ringSize = 172.0;
  static const _logoSize = 108.0;

  late final AnimationController _intro; // sequência de entrada, roda uma vez
  late final AnimationController _breath; // brilho lento atrás do logo

  late final Animation<double> _ring;
  late final Animation<double> _logo;
  late final Animation<double> _text;
  late final Animation<double> _lower;

  double _progress = 0.05;
  int _messageIndex = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();

    // Respeita "remover animações" do sistema
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Ordem: anel se desenha → logo surge dentro → nome → barra de progresso
    _ring = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeInOutCubic),
    );
    _logo = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
    );
    _text = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
    );
    _lower = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
    );

    if (reduceMotion) {
      _intro.value = 1.0;
    } else {
      _intro.forward();
      _breath.repeat(reverse: true);
    }

    if (widget.initFuture != null) {
      _runInit();
    }
  }

  Future<void> _runInit() async {
    final steps = widget.statusMessages.length + 1;
    _tickProgress(steps);

    try {
      await widget.initFuture!();
    } catch (e) {
      debugPrint('❌ Erro na inicialização da splash: $e');
    }

    // Se a inicialização foi rápida, deixa a entrada terminar
    // para o anel não ser cortado no meio.
    if (mounted) await _intro.forward();

    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _done = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) widget.onReady?.call();
  }

  void _tickProgress(int steps) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted || _done) return false;
      setState(() {
        _messageIndex =
            (_messageIndex + 1).clamp(0, widget.statusMessages.length - 1);
        _progress = (_messageIndex + 1) / steps;
      });
      return !_done;
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.05,
            colors: [
              Theme.of(context).colorScheme.surfaceContainer,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildEmblem(),
                    const SizedBox(height: 32),
                    FadeTransition(opacity: _text, child: _buildTitle()),
                    const SizedBox(height: 56),
                    FadeTransition(opacity: _lower, child: _buildLower()),
                  ],
                ),
              ),
            ),

            // Rodapé
            Positioned(
              bottom: 28 + bottomInset,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _lower,
                child: Center(
                  child: Text(
                    'ιχθύς • Keryx',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.25),
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Logo + brilho + anel dourado que se desenha.
  Widget _buildEmblem() {
    final gold = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: _ringSize,
      height: _ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Brilho que "respira" atrás do logo
          FadeTransition(
            opacity: _logo,
            child: AnimatedBuilder(
              animation: _breath,
              builder: (_, __) => Container(
                width: _logoSize,
                height: _logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.10 + 0.12 * _breath.value),
                      blurRadius: 36 + 18 * _breath.value,
                      spreadRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Logo
          FadeTransition(
            opacity: _logo,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(_logo),
              child: Container(
                width: _logoSize,
                height: _logoSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF14142B),
                  border: Border.all(color: gold.withValues(alpha: 0.30), width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/img/logoHome.png',
                    semanticLabel: 'Logotipo Keryx',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.auto_stories_rounded,
                      color: gold,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Anel que se desenha
          CustomPaint(
            size: const Size(_ringSize, _ringSize),
            painter: _RingPainter(_ring, gold),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'KeryxApp',
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.message ?? 'Transformando sua jornada espiritual',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _buildLower() {
    if (widget.initFuture == null) {
      // Spinner legado (sem initFuture)
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      );
    }

    final messages = widget.statusMessages;
    final text = _done
        ? 'Tudo pronto'
        : (messages.isNotEmpty ? messages[_messageIndex] : 'Carregando...');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Text(
            text,
            key: ValueKey(_done ? -1 : _messageIndex),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildProgressBar(),
      ],
    );
  }

  Widget _buildProgressBar() {
    final gold = Theme.of(context).colorScheme.primary;
    final lightGold = Color.lerp(gold, Colors.white, 0.35)!;

    return SizedBox(
      width: 220,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.08)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: _progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, value, __) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [gold, lightGold]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desenha o anel dourado, do topo, no sentido horário.
class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;

    // Trilho discreto, aparece junto com o traço
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.12 * progress.value),
    );

    // Traço dourado
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