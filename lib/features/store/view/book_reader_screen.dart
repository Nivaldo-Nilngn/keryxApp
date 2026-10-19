import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:audioplayers/audioplayers.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:http/http.dart' as http;
import 'package:keryx_app/features/store/repository/b2_service.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/theme/app_theme.dart';

// ── Paleta ──────────────────────────────────────────────────────────────────
// Utiliza-se Theme.of(context) em vez de cores hardcoded para suportar temas claro e escuro.

// ============================================================================
// TELA DE LISTA
// ============================================================================
class BookReaderScreen extends ConsumerStatefulWidget {
  final StoreItem book;
  final int? initialHymnIndex;
  const BookReaderScreen({super.key, required this.book, this.initialHymnIndex});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  bool get isHarpa => widget.book.filename.contains('Harpa');
  bool _loading = true;
  String? _error;
  List<_Hymn> _hymns = [];
  String _search = '';
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _load();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = widget.book.filename.split('/').last;
      final path = p.join(dir.path, 'store', 'books', filename);
      if (!await File(path).exists()) {
        setState(() { _error = 'Arquivo não encontrado.'; _loading = false; }); return;
      }
      final db = kIsWeb
          ? await databaseFactoryFfiWeb.openDatabase(path, options: OpenDatabaseOptions(readOnly: true))
          : await openDatabase(path, readOnly: true);
      // journal tem HTML; journal2 tem texto plano (FTS). Usamos journal.
      final rows = await db.rawQuery(
        'SELECT j.id, j.title, j.content, j2.content AS plain '
        'FROM journal j LEFT JOIN journal2 j2 ON j.id = j2.id '
        'ORDER BY j.rowid',
      ).catchError((_) => db.rawQuery('SELECT id, title, content FROM journal ORDER BY rowid'));
      await db.close();
      final hymns = rows.map((r) {
        final id    = (r['id']    as String? ?? '').trim();
        final title = (r['title'] as String? ?? '').trim();
        final html  = (r['content'] as String? ?? '');
        // número do hino: o id começa com "1. CHUVAS..." → pegar a parte antes do primeiro '.'
        final dotIdx = id.indexOf('.');
        final num  = dotIdx > 0 ? id.substring(0, dotIdx).trim() : id;
        final name = dotIdx > 0 ? id.substring(dotIdx + 1).trim() : id;
        return _Hymn(number: num, name: name.isEmpty ? title : name, html: html);
      }).toList();
      setState(() { _hymns = hymns; _loading = false; });

    } catch (e) {
      setState(() { _error = '$e'; _loading = false; });
    }
  }

  List<_Hymn> get _filtered {
    if (_search.isEmpty) return _hymns;
    final q = _search.toLowerCase();
    return _hymns.where((h) =>
      h.name.toLowerCase().contains(q) ||
      h.number.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showBackButton: true,
        showLogo: true,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Stack(
            children: [
              _loading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                  : _error != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24),
                          child: Text(_error!, style: const TextStyle(color: Colors.redAccent))))
                      : _buildBody(),
              Align(
                alignment: Alignment.bottomCenter,
                child: CustomBottomNav(
                  currentIndex: ref.watch(navigationProvider),
                  onTap: (i) {
                    ref.read(navigationProvider.notifier).setIndex(i);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [

        // ── Hino do Dia ───────────────────────────────────────────────────
        if (widget.initialHymnIndex != null && widget.initialHymnIndex! >= 0 && widget.initialHymnIndex! < _hymns.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _HymnDetailScreen(hymns: _hymns, initialIndex: widget.initialHymnIndex!, isHarpa: isHarpa, book: widget.book),
              )),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFAA7C11)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'HINO DO DIA',
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hymns[widget.initialHymnIndex!].name,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36),
                  ],
                ),
              ),
            ),
          ),
        // ── Busca ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: isHarpa ? 'Buscar hino por nome ou número' : 'Buscar capítulo',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        // ── Lista ─────────────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final h = _filtered[i];
              final numStr = h.number.padLeft(3, '0');
              
              // Verifica se é o hino do dia
              final isHymnOfDay = widget.initialHymnIndex != null && _hymns.indexOf(h) == widget.initialHymnIndex;
              final bgColor = isHymnOfDay ? const Color(0xFFD4AF37).withValues(alpha: 0.15) : Theme.of(context).colorScheme.surfaceContainer;
              final borderColor = isHymnOfDay ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : Colors.transparent;

              return GestureDetector(
                onTap: () => Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => _HymnDetailScreen(hymns: _hymns, initialIndex: i, isHarpa: isHarpa, book: widget.book),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(children: [
                    // número badge
                    if (isHarpa) ...[
                      Container(
                        width: 48, height: 40,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: Text(numStr, style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(isHarpa ? 'CPAD' : widget.book.name, style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (isHymnOfDay) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(4)),
                                  child: Text('Hino do Dia', style: GoogleFonts.outfit(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 22),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MODELO
// ============================================================================
class _Hymn {
  final String number;
  final String name;
  final String html;
  const _Hymn({required this.number, required this.name, required this.html});
}

// ============================================================================
// TELA DE DETALHE
// ============================================================================
class _HymnDetailScreen extends ConsumerStatefulWidget {
  final StoreItem book;
  final bool isHarpa;
  final List<_Hymn> hymns;
  final int initialIndex;
  const _HymnDetailScreen({required this.hymns, required this.initialIndex, this.isHarpa = true, required this.book});

  @override
  ConsumerState<_HymnDetailScreen> createState() => _HymnDetailScreenState();
}

class _HymnDetailScreenState extends ConsumerState<_HymnDetailScreen> {
  late int _currentIndex;
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _fileExists = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  double _playbackRate = 1.0;

  _Hymn get hymn => widget.hymns[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= widget.hymns.length) return;
    _audioPlayer.stop();
    setState(() {
      _currentIndex = index;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      _fileExists = false;
      _isDownloading = false;
    });
    _initAudio();
  }

  Future<void> _initAudio() async {
    final numStr = hymn.number.padLeft(3, '0');
    // Verifica se o arquivo existe na pasta da loja ou na área de trabalho (desenvolvimento)
    final dir = await getApplicationDocumentsDirectory();
    final storePath = p.join(dir.path, 'store', 'audios', 'Harpa_Crista', '$numStr.mp3');
    final desktopPath = '/home/nilngn/Área de trabalho/HarpaHinos/$numStr.mp3';
    
    String? finalPath;
    if (await File(storePath).exists()) {
      finalPath = storePath;
    } else if (await File(desktopPath).exists()) {
      finalPath = desktopPath;
    }

    if (finalPath != null) {
      setState(() => _fileExists = true);
      await _audioPlayer.setSource(DeviceFileSource(finalPath));
      await _audioPlayer.setPlaybackRate(_playbackRate);
      
      _audioPlayer.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      });
      _audioPlayer.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _audioPlayer.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
      });
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
    }
  }

  Future<void> _downloadAudio() async {
    setState(() { _isDownloading = true; _downloadProgress = 0.0; });
    try {
      final b2 = B2Service();
      final numStr = hymn.number.padLeft(3, '0');
      final fileName = 'audios/Harpa_Crista/$numStr.mp3';
      final url = await b2.getDownloadUrl(fileName);
      final headers = await b2.getDownloadHeaders();
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);
      
      final response = await client.send(request);
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory(p.join(dir.path, 'store', 'audios', 'Harpa_Crista'));
        if (!await saveDir.exists()) await saveDir.create(recursive: true);
        
        final savePath = p.join(saveDir.path, '$numStr.mp3');
        final file = File(savePath);
        final sink = file.openWrite();
        
        final totalBytes = response.contentLength ?? 4000000;
        int downloaded = 0;
        
        await for (final chunk in response.stream) {
          downloaded += chunk.length;
          sink.add(chunk);
          if (mounted) setState(() => _downloadProgress = downloaded / totalBytes);
        }
        await sink.close();
        
        await _initAudio();
      } else {
        throw Exception('Erro ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Falha ao baixar áudio: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseBlocks(String html) {
    final List<Map<String, dynamic>> blocks = [];
    final paras = html.split(RegExp(r'</?p>|</p>\s*<p>')).where((s) => s.trim().isNotEmpty).toList();
    for (final para in paras) {
      final isChorus = para.contains('<strong>') || para.contains('<em>');
      final clean = para
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('\n', ' ')
          .trim();
      if (clean.isEmpty) continue;
      final rawLines = para.replaceAll(RegExp(r'<[^>]+>'), '\n').split('\n')
          .map((l) => l.replaceAll(RegExp(r'&[a-z]+;'), ' ').trim())
          .where((l) => l.isNotEmpty)
          .toList();
      blocks.add({'isChorus': isChorus, 'lines': rawLines.isEmpty ? [clean] : rawLines});
    }
    return blocks;
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  void _changePlaybackRate() {
    final rates = [1.0, 1.25, 1.5, 2.0];
    int currentIdx = rates.indexOf(_playbackRate);
    if (currentIdx == -1) currentIdx = 0;
    final nextIdx = (currentIdx + 1) % rates.length;
    setState(() {
      _playbackRate = rates[nextIdx];
    });
    _audioPlayer.setPlaybackRate(_playbackRate);
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(hymn.html);
    final numStr = hymn.number.padLeft(3, '0');
    final hasPrev = _currentIndex > 0;
    final hasNext = _currentIndex < widget.hymns.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
              // ── App Bar ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
              // ── Título ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.isHarpa ? '$numStr · ${hymn.name}' : hymn.name,
                      style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2)),
                    const SizedBox(height: 4),
                    if (widget.isHarpa)

                    const SizedBox(height: 12),
                    Row(children: [
                      if (widget.isHarpa)
                        _Chip('Hino $numStr de ${widget.hymns.length}', icon: Icons.music_note_rounded)
                      else
                        _Chip('Capítulo ${(_currentIndex + 1)} de ${widget.hymns.length}', icon: Icons.book_rounded),
                      const Spacer(),
                      _ShareBtn(hymn: hymn),
                    ]),
                  ],
                ),
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
              // ── Corpo Rolável ─────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    // Player de Áudio
                    if (widget.isHarpa) ...[
                      if (_fileExists)
                        _buildAudioPlayer(numStr)
                      else
                        _buildDownloadBox(),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Conteúdo do Livro ou Letra do Hino
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Html(
                        data: hymn.html,
                        style: {
                          "body": Style(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                            fontSize: FontSize(18.0),
                            fontFamily: GoogleFonts.lora().fontFamily,
                            lineHeight: LineHeight(1.6),
                            textAlign: widget.isHarpa ? TextAlign.center : TextAlign.left,
                          ),
                          "h1": Style(color: Theme.of(context).colorScheme.primary, fontSize: FontSize(24.0)),
                          "h2": Style(color: Theme.of(context).colorScheme.onSurface, fontSize: FontSize(22.0)),
                          "h3": Style(color: Theme.of(context).colorScheme.onSurface, fontSize: FontSize(20.0)),
                          "strong": widget.isHarpa 
                            ? Style(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontStyle: FontStyle.italic) 
                            : Style(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                          "a": Style(color: Theme.of(context).colorScheme.primary, textDecoration: TextDecoration.none),
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Botões Anterior / Próximo
                    Row(
                      children: [
                        if (hasPrev)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _goToIndex(_currentIndex - 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
                                    const Spacer(),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Anterior', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                                          Text(widget.isHarpa ? widget.hymns[_currentIndex - 1].number.padLeft(3, '0') : widget.hymns[_currentIndex - 1].name, 
                                            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                          
                        const SizedBox(width: 12),
                        
                        if (hasNext)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _goToIndex(_currentIndex + 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Próximo', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                                          Text(widget.isHarpa ? widget.hymns[_currentIndex + 1].number.padLeft(3, '0') : widget.hymns[_currentIndex + 1].name, 
                                            style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
                child: CustomBottomNav(
                  currentIndex: ref.watch(navigationProvider),
                  onTap: (i) {
                    ref.read(navigationProvider.notifier).setIndex(i);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String numStr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_isPlaying) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.resume();
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.surface,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ouvir Hino', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.replay_10_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 24),
                    onPressed: () {
                      final newPos = _position - const Duration(seconds: 15);
                      _audioPlayer.seek(newPos < Duration.zero ? Duration.zero : newPos);
                    },
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _changePlaybackRate,
                    child: SizedBox(
                      width: 28,
                      child: Center(
                        child: Text('${_playbackRate.toStringAsFixed(1).replaceAll('.0', '')}x', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.forward_10_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 24),
                    onPressed: () {
                      final newPos = _position + const Duration(seconds: 15);
                      _audioPlayer.seek(newPos > _duration ? _duration : newPos);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              thumbColor: Theme.of(context).colorScheme.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              min: 0,
              max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1,
              value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
              onChanged: (val) {
                _audioPlayer.seek(Duration(seconds: val.toInt()));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: _isDownloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Baixando áudio (aprox. 4MB)... ${( _downloadProgress * 100 ).toInt()}%', 
                  style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _downloadProgress, 
                  color: Theme.of(context).colorScheme.primary, 
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            )
          : ElevatedButton.icon(
              onPressed: _downloadAudio,
              icon: Icon(Icons.cloud_download_rounded, color: Theme.of(context).colorScheme.surface),
              label: Text('Baixar Áudio Deste Hino', 
                style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
    );
  }
}

// ── Chip badge ───────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, {required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary, size: 14),
      const SizedBox(width: 6),
      Text(label, style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Botão compartilhar ───────────────────────────────────────────────────────
class _ShareBtn extends StatelessWidget {
  final _Hymn hymn;
  const _ShareBtn({required this.hymn});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      final text = '${hymn.number}. ${hymn.name}\n\n${hymn.html.replaceAll(RegExp(r'<[^>]+>'), '\n').trim()}';
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hino copiado para a área de transferência!')),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.share_rounded, color: Theme.of(context).colorScheme.onSurface, size: 16),
        const SizedBox(width: 6),
        Text('Compartilhar', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}
