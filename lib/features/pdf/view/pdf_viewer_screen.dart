import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdfviewer/src/annotation/annotation.dart';
import 'package:syncfusion_flutter_pdfviewer/src/annotation/text_markup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/services/graph_service.dart';
import 'package:keryx_app/core/services/telegram/telegram_http_download_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo: Marcador de página
// ─────────────────────────────────────────────────────────────────────────────
class _Bookmark {
  final int page;
  final String label;
  final DateTime createdAt;

  _Bookmark({
    required this.page,
    required this.label,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'page': page,
        'label': label,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _Bookmark.fromMap(Map<String, dynamic> m) => _Bookmark(
        page: m['page'] as int,
        label: m['label'] as String? ?? 'Marcador',
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PdfViewerScreen
// ─────────────────────────────────────────────────────────────────────────────
class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;
  final String? pdfId; // 👈

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.pdfId, // 👈
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final GlobalKey<SfPdfViewerState> _pdfKey = GlobalKey();
  final PdfViewerController _pdfCtrl = PdfViewerController();
  final FlutterTts _tts = FlutterTts();

  // ── Loading ────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';

  // ── Leitura ────────────────────────────────────────────────────────────────
  int _currentPage = 1;
  int _totalPages = 0;
  double _zoom = 1.0;

  // ── TTS ──────────────────────────────────────────────────────────────────
  bool _isSpeaking = false;
  bool _ttsAvailable = false;
  double _ttsSpeed = 0.5;
  double _ttsPitch = 1.0;

  // ── Marcadores ───────────────────────────────────────────────────────────
  final _graphService = GraphService(); // 👈
  List<_Bookmark> _bookmarks = [];
  bool _showBookmarkPanel = false;

  // ── Firebase ─────────────────────────────────────────────────────────────
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// ID único do documento para salvar progresso
  String get _docId => widget.title
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
      .toLowerCase()
      .substring(0, widget.title.length.clamp(0, 60));

  static const String _prefPrefix = 'pdf_progress_';
  String? _pdfNetworkUrl;
  Uint8List? _pdfMemoryBytes;
  Map<String, String>? _pdfHeaders;
  bool _isDisposed = false;
  bool _isLayoutFinished = false; 
  bool _isHiding = false; // 👈 Novo: indica que a tela está sendo fechada
  PdfDocument? _pdfDocument; // 👈 Referência ao documento para TTS
  PdfAnnotationMode _annotationMode = PdfAnnotationMode.none; // 👈 Modo de anotação
  bool _isFullScreen = false; // 👈 Ocultar a interface (modo imersivo)
  Color _currentHighlightColor = Colors.yellow; // 👈 Cor padrão da marcação
  Annotation? _selectedAnnotation; // 👈 Referência à anotação selecionada
  bool _isSyncing = false; // 👈 Status de sincronização com Firebase
  List<dynamic> _pendingHighlights = []; // 👈 Cache de marcações para carregar após o doc abrir
  bool _isRestoring = false; // 👈 Silencia saves durante carga inicial
  bool _skipSaving = false; // 👈 Evita loops de salvamento ao remover sobreposições
  bool _needsSyncAgain = false; // 👈 Indica se houve alterações durante um salvamento ativo
  int? _resumeHintPage; // 👈 Armazena de qual página o usuário retomou
  Timer? _resumeHintTimer; // 👈 Timer para ocultar o aviso automaticamente

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPdf();
    _loadProgressAndBookmarks();

    // 👈 Garante que o PDF só renderize após o layout inicial do sistema estar pronto
    _isLayoutFinished = true;

    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tts.stop();
    WakelockPlus.disable();
    _pdfCtrl.dispose();
    _pdfMemoryBytes = null;
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TTS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(_ttsSpeed);
      await _tts.setPitch(_ttsPitch);
      await _tts.setVolume(1.0);
      _tts.setStartHandler(() => setState(() => _isSpeaking = true));
      _tts.setCompletionHandler(() => setState(() => _isSpeaking = false));
      _tts.setCancelHandler(() => setState(() => _isSpeaking = false));
      if (mounted) setState(() => _ttsAvailable = true);
    } catch (_) {}
  }

  Future<void> _toggleTts() async {
    if (_isSpeaking) {
      await _tts.stop();
      setState(() => _isSpeaking = false);
    } else {
      if (_pdfDocument == null) {
        await _tts.speak('O documento ainda não carregou totalmente.');
        return;
      }
      try {
        final extractor = PdfTextExtractor(_pdfDocument!);
        String text = extractor.extractText(
            startPageIndex: _currentPage - 1, endPageIndex: _currentPage - 1);
            
        if (text.trim().isEmpty) {
          text =
              'Página $_currentPage de $_totalPages. Nenhum texto detectado. Pode ser um livro escaneado.';
        }
        await _tts.speak(text);
      } catch (e) {
        debugPrint('Erro no TTS: $e');
        await _tts.speak(
            'Erro ao extrair o texto para leitura da página $_currentPage.');
      }
    }
  }

  void _showTtsSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1B2E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚙️ Configurações de Voz',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Velocidade
              Row(
                children: [
                  const Icon(Icons.speed, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  const Text('Velocidade',
                      style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Text('${(_ttsSpeed * 2).toStringAsFixed(1)}x',
                      style: const TextStyle(
                          color: Color(0xFF7B2FBE),
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _ttsSpeed,
                min: 0.1,
                max: 1.0,
                divisions: 9,
                activeColor: const Color(0xFF7B2FBE),
                onChanged: (v) {
                  setStateModal(() => _ttsSpeed = v);
                  setState(() => _ttsSpeed = v);
                  _tts.setSpeechRate(v);
                },
              ),
              // Tom
              Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  const Text('Tom', style: TextStyle(color: Colors.white70)),
                  const Spacer(),
                  Text(_ttsPitch.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Color(0xFF7B2FBE),
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: _ttsPitch,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                activeColor: const Color(0xFF7B2FBE),
                onChanged: (v) {
                  setStateModal(() => _ttsPitch = v);
                  setState(() => _ttsPitch = v);
                  _tts.setPitch(v);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Progresso & Marcadores (Firebase + SharedPrefs fallback)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadProgressAndBookmarks() async {
    if (_uid == null) {
      _loadProgressFromPrefs();
      return;
    }

    try {
      final doc = await _db
          .collection('users')
          .doc(_uid)
          .collection('highlights')
          .doc(_docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final savedPage = (data['currentPage'] as int?) ?? 1;
        final bookmarksRaw = (data['bookmarks'] as List<dynamic>?) ?? [];
        final bookmarks = bookmarksRaw
            .map((b) => _Bookmark.fromMap(b as Map<String, dynamic>))
            .toList();

        if (mounted) {
          setState(() {
            _bookmarks = bookmarks;
            final highlightsRaw = (data['highlights'] as List<dynamic>?) ?? [];
            _pendingHighlights = highlightsRaw;
          });
          
          // Se o documento já carregou mas os dados chegaram depois, aplica agora
          if (_pdfDocument != null && _pendingHighlights.isNotEmpty) {
            _applyPendingHighlights();
          }

          // Delay curto para garantir que o controlador esteja pronto para o jumpToPage
          await Future.delayed(const Duration(milliseconds: 500));
          if (savedPage > 1 && mounted) {
            _goToPage(savedPage, save: false);
            _showResumeSnackbar(savedPage);
          }
        }
      } else {
        // Se o documento Firebase não existe, tenta carregar local (caso tenha migrado perfil)
        _loadProgressFromPrefs();
      }
    } catch (e) {
      debugPrint('❌ Erro ao carregar progresso (Firebase): $e');
      _loadProgressFromPrefs();
    }
  }

  /// Aplica as marcações guardadas no [_pendingHighlights] ao documento atual
  void _applyPendingHighlights() {
    if (_isDisposed || !mounted || _pendingHighlights.isEmpty) return;

    _isRestoring = true; // Silencia saves automáticos durante a restauração
    try {
      final List<dynamic> currentBatch = List.from(_pendingHighlights);
      _pendingHighlights = [];

      for (var h in currentBatch) {
        try {
          final map = h as Map<String, dynamic>;
          final pageNumber = (map['pageNumber'] as num).toInt();
          final colorValue = (map['color'] as num).toInt();
          
          // Compatibilidade com diferentes versões do esquema
          final List<dynamic> boundsList = map['bounds'] ?? map['textMarkupRects'] ?? [];
          
          final List<PdfTextLine> textBounds = boundsList.map((b) {
            // Suporta [l, t, w, h] ou {l, t, w, h}
            if (b is List) {
              return PdfTextLine(
                Rect.fromLTWH(
                  (b[0] as num).toDouble(),
                  (b[1] as num).toDouble(),
                  (b[2] as num).toDouble(),
                  (b[3] as num).toDouble(),
                ),
                '',
                pageNumber,
              );
            } else {
              return PdfTextLine(
                Rect.fromLTWH(
                  (b['l'] as num).toDouble(),
                  (b['t'] as num).toDouble(),
                  (b['w'] as num).toDouble(),
                  (b['h'] as num).toDouble(),
                ),
                '',
                pageNumber,
              );
            }
          }).toList();

          if (textBounds.isNotEmpty) {
            final highlight = HighlightAnnotation(
              textBoundsCollection: textBounds,
            );
            highlight.color = Color(colorValue);
            _pdfCtrl.addAnnotation(highlight);
          }
        } catch (e) {
          debugPrint('⚠️ Erro ao aplicar marcação individual: $e');
        }
      }
    } finally {
      _isRestoring = false;
    }
  }

  void _handleOverlap(HighlightAnnotation newAnn) {
    if (_isRestoring || _isHiding || _isDisposed) return;

    final annotations = _pdfCtrl.getAnnotations();
    final toRemove = <Annotation>[];
    
    // Obtém os retângulos da nova marcação
    final newRects = newAnn.textMarkupRects;

    for (final ann in annotations) {
      if (ann == newAnn) continue;
      if (ann is HighlightAnnotation && ann.pageNumber == newAnn.pageNumber) {
        final existingRects = ann.textMarkupRects;
        bool overlapsSignificantly = false;

        // Verifica interseção por bounding box primeiro (rápido)
        if (newAnn.boundingBox.overlaps(ann.boundingBox)) {
          // Verifica interseção entre os retângulos de cada linha (preciso)
          for (final nr in newRects) {
            for (final er in existingRects) {
              if ((nr.top - er.top).abs() < 5 && nr.overlaps(er)) {
                final intersection = nr.intersect(er);
                if (intersection.width > 3) {
                  overlapsSignificantly = true;
                  break;
                }
              }
            }
            if (overlapsSignificantly) break;
          }
        }

        if (overlapsSignificantly) toRemove.add(ann);
      }
    }

    if (toRemove.isNotEmpty) {
      _skipSaving = true;
      for (final ann in toRemove) {
        _pdfCtrl.removeAnnotation(ann);
      }
      _skipSaving = false;
    }
  }

  Future<void> _saveHighlights() async {
    if (_uid == null || _isRestoring || _skipSaving) return;
    
    if (_isSyncing) {
      _needsSyncAgain = true;
      debugPrint('⏳ Salvamento em andamento, agendando novo sync...');
      return;
    }
    
    setState(() => _isSyncing = true);
    _needsSyncAgain = false;

    try {
      final List<Map<String, dynamic>> highlightsData = [];
      
      final annotations = _pdfCtrl.getAnnotations();
      for (final ann in annotations) {
        if (ann is HighlightAnnotation) {
          highlightsData.add({
            'pageNumber': ann.pageNumber,
            'color': ann.color.toARGB32(),
            'bounds': ann.textMarkupRects.map((r) => {
              'l': r.left,
              't': r.top,
              'w': r.width,
              'h': r.height,
            }).toList(),
          });
        }
      }

      await _db
          .collection('users')
          .doc(_uid)
          .collection('highlights')
          .doc(_docId)
          .set({
        'highlights': highlightsData,
        'lastSync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Marcações salvas com sucesso no Firebase');
    } catch (e) {
      debugPrint('❌ Erro ao salvar marcações: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
      
      // Se houve alterações enquanto salvávamos, sincroniza de novo
      if (_needsSyncAgain && mounted) {
        _saveHighlights();
      }
    }
  }

  Future<void> _loadProgressFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPage = prefs.getInt('$_prefPrefix${_docId}_page') ?? 1;
      
      // Carrega marcadores dos prefs
      final bookmarksRaw = prefs.getStringList('$_prefPrefix${_docId}_bookmarks') ?? [];
      final bookmarks = bookmarksRaw.map((s) => _Bookmark.fromMap(json.decode(s))).toList();

      if (savedPage > 1 && mounted) {
        setState(() => _bookmarks = bookmarks);
        await Future.delayed(const Duration(milliseconds: 1000));
        _goToPage(savedPage, save: false);
        _showResumeSnackbar(savedPage);
      }
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    if (!mounted || _currentPage <= 0) return;

    if (_uid != null) {
      try {
        await _db
            .collection('users')
            .doc(_uid)
            .collection('highlights')
            .doc(_docId)
            .set({
          'title': widget.title,
          'currentPage': _currentPage,
          'totalPages': _totalPages,
          'lastRead': FieldValue.serverTimestamp(),
          'bookmarks': _bookmarks.map((b) => b.toMap()).toList(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('❌ Erro ao salvar progresso: $e');
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('$_prefPrefix${_docId}_page', _currentPage);
        final bookmarksJson = _bookmarks.map((b) => json.encode(b.toMap())).toList();
        await prefs.setStringList('$_prefPrefix${_docId}_bookmarks', bookmarksJson);
      } catch (_) {}
    }
  }

  void _showResumeSnackbar(int page) {
    if (!mounted) return;
    
    // Cancela timer anterior se houver
    _resumeHintTimer?.cancel();
    
    setState(() {
      _resumeHintPage = page;
    });

    // Oculta após 4 segundos
    _resumeHintTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _resumeHintPage = null);
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Marcadores
  // ─────────────────────────────────────────────────────────────────────────
  void _addBookmark() {
    final already = _bookmarks.any((b) => b.page == _currentPage);
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta página já tem um marcador!'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String label = 'Página $_currentPage';
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1B2E),
          title: const Text('Adicionar Marcador',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Página $_currentPage de $_totalPages',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nome do marcador (opcional)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) =>
                    label = v.isEmpty ? 'Página $_currentPage' : v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2FBE)),
              onPressed: () {
                final bm = _Bookmark(
                  page: _currentPage,
                  label: label,
                  createdAt: DateTime.now(),
                );
                setState(() {
                  _bookmarks.add(bm);
                  _bookmarks.sort((a, b) => a.page.compareTo(b.page));
                });
                _saveProgress();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📌 Marcador salvo: $label'),
                    backgroundColor: const Color(0xFF7B2FBE),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _removeBookmark(_Bookmark bm) {
    setState(() => _bookmarks.remove(bm));
    _saveProgress();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Navegação de páginas
  // ─────────────────────────────────────────────────────────────────────────
  void _goToPage(int page, {bool save = true}) {
    if (!mounted) return; // 👈
    if (page < 1 || (_totalPages > 0 && page > _totalPages)) return;
    try {
      _pdfCtrl.jumpToPage(page);
      // O estado visual da página é atualizado pelo callback onPageChanged do SfPdfViewer
      // mas podemos forçar aqui para atualizar o BottomBar imediatamente
      setState(() => _currentPage = page);
      if (save) _saveProgress();
    } catch (_) {}
  }

  void _goToPageDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: '$_currentPage');
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1B2E),
          title: const Text('Ir para página',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '1 — $_totalPages',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.07),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2FBE)),
              onPressed: () {
                final page = int.tryParse(ctrl.text) ?? _currentPage;
                Navigator.pop(ctx);
                _goToPage(page);
              },
              child: const Text('Ir'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Carregamento do PDF
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (kIsWeb) {
        // Tenta pegar bytes diretos do cache em memória do TelegramHttpDownloadService
        Uint8List? bytes = TelegramHttpDownloadService.getWebBytes(widget.pdfUrl);
        if (bytes == null && widget.pdfId != null) {
          bytes = TelegramHttpDownloadService.getWebBytes(widget.pdfId!);
        }
        if (bytes == null) {
          bytes = TelegramHttpDownloadService.getWebBytes(widget.title);
        }

        // Se veio como data:application/pdf;base64, decodifica UMA ÚNICA VEZ fora do build
        if (bytes == null && widget.pdfUrl.startsWith('data:application/pdf;base64,')) {
          final base64Str = widget.pdfUrl.substring('data:application/pdf;base64,'.length);
          bytes = base64Decode(base64Str);
        }

        if (bytes != null) {
          _pdfMemoryBytes = bytes;
          _pdfNetworkUrl = 'memory://loaded';
          _pdfHeaders = const <String, String>{};
          if (mounted) setState(() => _isLoading = false);
          return;
        }

        // Data URLs genéricas
        if (widget.pdfUrl.startsWith('data:')) {
          _pdfNetworkUrl = widget.pdfUrl;
          _pdfHeaders = const <String, String>{};
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      final isLocal = widget.pdfUrl.startsWith('/') ||
          widget.pdfUrl.contains(':\\') ||
          widget.pdfUrl.startsWith('file://');

      final data = (!isLocal && widget.pdfId != null)
          ? await _graphService.getDirectAccessData(widget.pdfId!)
          : {'url': widget.pdfUrl};

      final url = data['url'];
      if (url != null && url.isNotEmpty) {
        _pdfNetworkUrl = url;
        _pdfHeaders = data.containsKey('Authorization')
            ? {'Authorization': data['Authorization']!}
            : const <String, String>{};

        if (_pdfNetworkUrl!.startsWith('/') || _pdfNetworkUrl!.contains(':\\')) {
          File file = File(_pdfNetworkUrl!);
          
          // Fallback para caso o arquivo tenha sido renomeado com .pdf no background
          if (!await file.exists() && !_pdfNetworkUrl!.toLowerCase().endsWith('.pdf') && !_pdfNetworkUrl!.toLowerCase().endsWith('.mybible')) {
            final fallbackFile = File('${_pdfNetworkUrl}.pdf');
            if (await fallbackFile.exists()) {
              file = fallbackFile;
              _pdfNetworkUrl = fallbackFile.path; // <-- PRECISA ATUALIZAR A URL AQUI!
            }
          }

          if (await file.exists()) {
            final size = await file.length();
            if (size < 10) {
              _hasError = true;
              _errorMsg = "Arquivo PDF vazio.\nPor favor, volte, exclua-o da Biblioteca usando a Lixeira e baixe novamente.";
            } else {
              try {
                final raf = await file.open(mode: FileMode.read);
                try {
                  final bytes = await raf.read(5);
                  final header = String.fromCharCodes(bytes);
                  if (!header.startsWith('%PDF-')) {
                    _hasError = true;
                    _errorMsg = "Arquivo inválido (não é um PDF real).\nPode ter sido um erro de rede passado.\nPor favor, volte, exclua-o da Biblioteca usando a Lixeira e baixe novamente.";
                  } else {
                    // Proteção contra PDFs incompletos/corrompidos que causam ANR (travamento) no leitor
                    final tailLength = size > 4096 ? 4096 : size;
                    await raf.setPosition(size - tailLength);
                    final tailBytes = await raf.read(tailLength);
                    final tailStr = String.fromCharCodes(tailBytes);
                    if (!tailStr.contains('%%EOF')) {
                      _hasError = true;
                      _errorMsg = "Este arquivo está incompleto ou corrompido no OneDrive (o upload original na nuvem terminou antes de completar o arquivo).\n\nSubstitua o arquivo no seu OneDrive pelo PDF íntegro.";
                    }
                  }
                } finally {
                  await raf.close();
                }
              } catch (e) {
                _hasError = true;
                _errorMsg = "Erro ao ler o arquivo PDF.\nPor favor, exclua-o da Biblioteca e baixe novamente.";
              }
            }
            
            if (_hasError && _errorMsg.isNotEmpty) {
               _errorMsg = "$_errorMsg\n\nDiagnóstico: ${file.path} ($size bytes)";
            }
          } else {
            _hasError = true;
            _errorMsg = "Arquivo PDF não encontrado no celular.";
          }
        }
      } else {
        _hasError = true;
        _errorMsg = "URL inválida ou nula retornada pela API.";
      }
    } catch (e) {
      _hasError = true;
      _errorMsg = e.toString();
    }

    // Android: Delay para animações do MIUI/Sistema
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // _loadPdfBytes removido (Era apenas para Web/CORS)


  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isHiding || _isDisposed) {
      return const Scaffold(backgroundColor: Color(0xFF08091A), body: SizedBox.shrink());
    }

    return PopScope(
      canPop: false, // 👈 Bloqueia o pop automático para limparmos o PDF primeiro
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // 1. Salva o progresso final antes de sair
        await _saveProgress();

        // 2. Notifica o estado que estamos saindo
        if (mounted) {
          setState(() {
            _isHiding = true;
          });
        }
        
        // 3. Para sons e libera travas de tela e oculta mensagens
        _tts.stop();
        WakelockPlus.disable();
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }

        // 3. Aguarda um tempo seguro para o Flutter remover o SfPdfViewer da árvore
        await Future.delayed(const Duration(milliseconds: 100));

        // 4. Fecha a tela de fato
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // ── AppBar ────────────────────────────────────────────────────────────
      appBar: _isFullScreen ? null : AppBar(
        backgroundColor: const Color(0xFF0E0F22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_totalPages > 0)
              Text(
                'Página $_currentPage de $_totalPages'
                '  •  ${((_currentPage / _totalPages) * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
          ],
        ),
        actions: [
          // Zoom -
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            tooltip: 'Reduzir zoom',
            onPressed: () {
              setState(() => _zoom = (_zoom - 0.25).clamp(0.5, 4.0));
              _pdfCtrl.zoomLevel = _zoom;
            },
          ),
          // Zoom +
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            tooltip: 'Aumentar zoom',
            onPressed: () {
              setState(() => _zoom = (_zoom + 0.25).clamp(0.5, 4.0));
              _pdfCtrl.zoomLevel = _zoom;
            },
          ),
          // Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1A1B2E),
            onSelected: (v) {
              switch (v) {
                case 'goto':
                  _goToPageDialog();
                case 'bookmark_add':
                  _addBookmark();
                case 'bookmarks':
                  setState(() => _showBookmarkPanel = !_showBookmarkPanel);
                case 'tts_settings':
                  _showTtsSettings();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'goto',
                child: Row(children: [
                  Icon(Icons.my_location, color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Ir para página',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'bookmark_add',
                child: Row(children: [
                  Icon(Icons.bookmark_add, color: Color(0xFF7B2FBE), size: 18),
                  SizedBox(width: 10),
                  Text('Adicionar marcador',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
              const PopupMenuItem(
                value: 'bookmarks',
                child: Row(children: [
                  Icon(Icons.bookmarks_outlined,
                      color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Ver marcadores',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'tts_settings',
                child: Row(children: [
                  Icon(Icons.record_voice_over,
                      color: Colors.white54, size: 18),
                  SizedBox(width: 10),
                  Text('Config. de voz',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────────────────────
      body: Column(
        children: [
          // Barra de progresso fina
          if (_totalPages > 0 && !_isFullScreen)
            LinearProgressIndicator(
              value: _currentPage / _totalPages,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7B2FBE)),
              minHeight: 2,
            ),

          // Painel de marcadores (drawer superior)
          if (_showBookmarkPanel && !_isFullScreen) _buildBookmarkPanel(),

          // PDF
          Expanded(
            child: SafeArea(
              top: _isFullScreen,
              bottom: _isFullScreen,
              child: _buildPdfArea(),
            ),
          ),
        ],
      ),

      // ── Bottom bar ────────────────────────────────────────────────────────
      bottomNavigationBar: _isFullScreen ? null : _buildBottomBar(),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Componentes
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPdfArea() {
    if (_isHiding || _isDisposed) {
      return Container(color: const Color(0xFF08091A));
    }

    if (widget.pdfUrl.isEmpty && widget.pdfId == null && !kIsWeb) {
      return const Center(child: Text('URL do PDF inválida', style: TextStyle(color: Colors.white)));
    }

    // ── PDF Viewer ─────────────────────────────────────────────────────────
    if (!_isLayoutFinished || _isLoading || _isHiding) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7B2FBE)));
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              Text('Não foi possível carregar o PDF',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_errorMsg,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), size: 18),
                    label: Text('Voltar', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _loadPdf,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tentar novamente'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B2FBE), foregroundColor: Colors.white),
                  ),
                ],
              ),
              if (_pdfNetworkUrl != null && (_pdfNetworkUrl!.startsWith('/') || _pdfNetworkUrl!.contains('app_flutter'))) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final f = File(_pdfNetworkUrl!);
                      if (await f.exists()) {
                        await f.delete();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Arquivo corrompido excluído do aparelho com sucesso.')),
                        );
                        Navigator.pop(context, true);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro ao excluir: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Excluir arquivo corrompido do aparelho',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_pdfNetworkUrl == null && _pdfMemoryBytes == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF7B2FBE)));
    }

    // Fallback de segurança: se houver data-url e bytes ainda não guardados no estado, converte UMA vez
    if (_pdfMemoryBytes == null &&
        _pdfNetworkUrl != null &&
        _pdfNetworkUrl!.startsWith('data:application/pdf;base64,')) {
      final base64Str = _pdfNetworkUrl!.substring('data:application/pdf;base64,'.length);
      _pdfMemoryBytes = base64Decode(base64Str);
    }

    final pdfWidget = LayoutBuilder(builder: (ctx, constraints) {
      // Se o layout estiver instável ou sem tamanho (comum no descarte), não tenta renderizar
      if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0 || _isHiding) {
        return const SizedBox.expand();
      }

      // Memória / Web (bytes mantidos em referência estocada - sem re-decodificar no build)
      if (_pdfMemoryBytes != null) {
        return TickerMode(
          enabled: !_isHiding,
          child: SfPdfViewer.memory(
            _pdfMemoryBytes!,
            key: _pdfKey,
            controller: _pdfCtrl,
            enableDoubleTapZooming: !_isHiding,
            enableTextSelection: true,
            interactionMode: _annotationMode == PdfAnnotationMode.highlight
                ? PdfInteractionMode.selection
                : PdfInteractionMode.pan,
            pageLayoutMode: PdfPageLayoutMode.continuous,
            onTap: (details) {
              if (_annotationMode == PdfAnnotationMode.none && mounted) {
                setState(() => _isFullScreen = !_isFullScreen);
              }
            },
            canShowPaginationDialog: false,
            canShowScrollHead: false,
            canShowScrollStatus: false,
            onPageChanged: (PdfPageChangedDetails d) {
              if (_isDisposed || !mounted || _isHiding) return;
              setState(() => _currentPage = d.newPageNumber);
              _saveProgress();
            },
            onDocumentLoaded: (PdfDocumentLoadedDetails d) {
              if (_isDisposed || !mounted || _isHiding) return;
              setState(() {
                _totalPages = d.document.pages.count;
                _isLoading = false;
                _pdfDocument = d.document;
              });
              if (_currentPage > 1) _pdfCtrl.jumpToPage(_currentPage);
              _applyPendingHighlights();
            },
            onDocumentLoadFailed: (PdfDocumentLoadFailedDetails d) {
              if (_isDisposed || !mounted || _isHiding) return;
              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMsg = d.description;
              });
            },
          ),
        );
      }

      return TickerMode(
        enabled: !_isHiding,
        child: _pdfNetworkUrl!.startsWith('assets/')
          ? SfPdfViewer.asset(
              _pdfNetworkUrl!,
              key: _pdfKey,
              controller: _pdfCtrl,
              enableDoubleTapZooming: !_isHiding,
              enableTextSelection: true,
              interactionMode: _annotationMode == PdfAnnotationMode.highlight
                  ? PdfInteractionMode.selection
                  : PdfInteractionMode.pan,
              pageLayoutMode: PdfPageLayoutMode.single,
              onTap: (details) {
                if (_annotationMode == PdfAnnotationMode.none && mounted) {
                   setState(() => _isFullScreen = !_isFullScreen);
                }
              },
              canShowPaginationDialog: false,
              canShowScrollHead: false,
              canShowScrollStatus: false,
              onPageChanged: (PdfPageChangedDetails d) {
                if (_isDisposed || !mounted || _isHiding) return;
                setState(() => _currentPage = d.newPageNumber);
                _saveProgress();
              },
              onDocumentLoaded: (PdfDocumentLoadedDetails d) {
                if (_isDisposed || !mounted || _isHiding) return;
                setState(() {
                  _totalPages = d.document.pages.count;
                  _isLoading = false;
                  _pdfDocument = d.document;
                });
                if (_currentPage > 1) {
                  _pdfCtrl.jumpToPage(_currentPage);
                }
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails d) {
                if (_isDisposed || !mounted || _isHiding) return;
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                  _errorMsg = d.description;
                });
              },
            )
          : _pdfNetworkUrl!.startsWith('/') || _pdfNetworkUrl!.contains(':\\')
            ? SfPdfViewer.file(
                File(_pdfNetworkUrl!),
                key: _pdfKey,
                controller: _pdfCtrl,
                enableDoubleTapZooming: !_isHiding,
                enableTextSelection: true,
                interactionMode: _annotationMode == PdfAnnotationMode.highlight
                    ? PdfInteractionMode.selection
                    : PdfInteractionMode.pan,
                pageLayoutMode: PdfPageLayoutMode.continuous,
                onTap: (details) {
                  if (_annotationMode == PdfAnnotationMode.none && mounted) {
                     setState(() => _isFullScreen = !_isFullScreen);
                  }
                },
                canShowPaginationDialog: false,
                canShowScrollHead: false,
                canShowScrollStatus: false,
                onPageChanged: (PdfPageChangedDetails d) {
                  if (_isDisposed || !mounted || _isHiding) return;
                  setState(() => _currentPage = d.newPageNumber);
                  _saveProgress();
                },
                onDocumentLoaded: (PdfDocumentLoadedDetails d) {
                  if (_isDisposed || !mounted || _isHiding) return;
                  setState(() {
                    _totalPages = d.document.pages.count;
                    _isLoading = false;
                    _pdfDocument = d.document;
                  });
                  if (_currentPage > 1) {
                    _pdfCtrl.jumpToPage(_currentPage);
                  }
                },
                onDocumentLoadFailed: (PdfDocumentLoadFailedDetails d) {
                  if (_isDisposed || !mounted || _isHiding) return;
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMsg = d.description == 'There was an error opening this document.'
                        ? 'O arquivo está danificado ou incompleto no servidor.'
                        : d.description;
                  });
                },
              )
            : SfPdfViewer.network(
              _pdfNetworkUrl!,
              key: _pdfKey,
              headers: _pdfHeaders,
              controller: _pdfCtrl,
              enableDoubleTapZooming: !_isHiding,
              enableTextSelection: true,
              interactionMode: _annotationMode == PdfAnnotationMode.highlight
                  ? PdfInteractionMode.selection
                  : PdfInteractionMode.pan,
              pageLayoutMode: PdfPageLayoutMode.continuous,
          onTap: (details) {
            if (_annotationMode == PdfAnnotationMode.none && mounted) {
               setState(() => _isFullScreen = !_isFullScreen);
            }
          },
          canShowPaginationDialog: false,
          canShowScrollHead: false,
          canShowScrollStatus: false,
          onPageChanged: (PdfPageChangedDetails d) {
            if (_isDisposed || !mounted || _isHiding) return;
            setState(() => _currentPage = d.newPageNumber);
            _saveProgress();
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails d) {
            if (_isDisposed || !mounted || _isHiding) return;
            setState(() {
              _totalPages = d.document.pages.count;
              _pdfDocument = d.document;
            });

            // Aplica marcações que já foram carregadas do Firebase
            _applyPendingHighlights();
          },
          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails d) {
            if (_isDisposed || !mounted || _isHiding) return;
            debugPrint('Erro PDF: ${d.description}');
          },
          onAnnotationSelected: (Annotation annotation) {
            setState(() {
              _selectedAnnotation = annotation;
              if (annotation is HighlightAnnotation) {
                _currentHighlightColor = annotation.color;
              }
            });
          },
          onAnnotationDeselected: (Annotation annotation) {
            setState(() => _selectedAnnotation = null);
          },
          onAnnotationAdded: (Annotation annotation) {
            if (_isRestoring) return;
            if (annotation is HighlightAnnotation) {
              _handleOverlap(annotation);
            }
            if (!_skipSaving) _saveHighlights();
          },
          onAnnotationEdited: (Annotation annotation) {
            if (!_isRestoring && !_skipSaving) _saveHighlights();
          },
          onAnnotationRemoved: (Annotation annotation) {
            if (!_isRestoring && !_skipSaving) _saveHighlights();
          },
        ),
      );
    });

    // Overlay com indicador de marcador na página atual
    final hasBookmarkHere =
        _bookmarks.any((b) => b.page == _currentPage);

    return Stack(
      children: [
        pdfWidget,
        if (hasBookmarkHere)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF7B2FBE).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Marcador',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (_annotationMode == PdfAnnotationMode.highlight && !_isFullScreen)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: _buildColorPicker(),
          ),
        
        // 👈 Aviso Customizado de Retomada de Leitura
        if (_resumeHintPage != null && !_isFullScreen)
          Positioned(
            bottom: 80, // Acima do controle inferior
            left: 20,
            right: 20,
            child: AnimatedOpacity(
              opacity: _resumeHintPage != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B2E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Color(0xFF7B2FBE), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Continuando da página $_resumeHintPage',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _resumeHintPage = null);
                        _goToPage(1);
                      },
                      child: const Text('Início', style: TextStyle(color: Color(0xFF7B2FBE), fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                      onPressed: () => setState(() => _resumeHintPage = null),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Colors.yellow,
      Colors.greenAccent,
      Colors.cyan,
      Colors.purpleAccent,
      Colors.pinkAccent,
    ];

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1B2E),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 2)
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: colors.map((color) {
            final isSelected = _currentHighlightColor == color;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentHighlightColor = color;
                  _pdfCtrl.annotationSettings.highlight.color = color;
                  // Se houver uma anotação selecionada, altera a cor dela imediatamente
                  if (_selectedAnnotation is HighlightAnnotation) {
                    (_selectedAnnotation as HighlightAnnotation).color = color;
                    _saveHighlights();
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F22),
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Página anterior
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: Colors.white70, size: 28),
              tooltip: 'Página anterior',
              onPressed: _currentPage > 1
                  ? () => _goToPage(_currentPage - 1)
                  : null,
            ),

            // Página atual (clicável para ir para)
            GestureDetector(
              onTap: _goToPageDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _totalPages > 0
                      ? '$_currentPage / $_totalPages'
                      : 'Carregando...',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // Próxima página
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: Colors.white70, size: 28),
              tooltip: 'Próxima página',
              onPressed: _totalPages > 0 && _currentPage < _totalPages
                  ? () => _goToPage(_currentPage + 1)
                  : null,
            ),

            const SizedBox(width: 4),

            // Marcador rápido
            IconButton(
              icon: Icon(
                _bookmarks.any((b) => b.page == _currentPage)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: _bookmarks.any((b) => b.page == _currentPage)
                    ? const Color(0xFF7B2FBE)
                    : Colors.white54,
                size: 24,
              ),
              tooltip: 'Marcar página',
              onPressed: _addBookmark,
            ),

            // TTS
            if (_ttsAvailable)
              IconButton(
                icon: Icon(
                  _isSpeaking ? Icons.stop_circle : Icons.record_voice_over,
                  color: _isSpeaking
                      ? Colors.redAccent
                      : Colors.white54,
                  size: 24,
                ),
                tooltip: _isSpeaking ? 'Parar leitura' : 'Ler em voz alta',
                onPressed: _toggleTts,
              ),

            // Botão de Marcação (Highlight)
            IconButton(
              icon: Icon(
                _annotationMode == PdfAnnotationMode.highlight
                    ? Icons.edit
                    : Icons.edit_outlined,
                color: _annotationMode == PdfAnnotationMode.highlight
                    ? const Color(0xFF7B2FBE)
                    : Colors.white54,
                size: 24,
              ),
              tooltip: 'Marcar texto',
              onPressed: () {
                setState(() {
                  if (_annotationMode == PdfAnnotationMode.none) {
                    _annotationMode = PdfAnnotationMode.highlight;
                    _pdfCtrl.annotationMode = PdfAnnotationMode.highlight;
                    _pdfCtrl.annotationSettings.highlight.color = _currentHighlightColor;
                  } else {
                    _annotationMode = PdfAnnotationMode.none;
                    _pdfCtrl.annotationMode = PdfAnnotationMode.none;
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F22),
        border: Border(
            bottom:
                BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.bookmarks,
                    color: Color(0xFF7B2FBE), size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Seus Marcadores',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      setState(() => _showBookmarkPanel = false),
                  child: const Text('Fechar',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ),
              ],
            ),
          ),
          if (_bookmarks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Nenhum marcador ainda.\nToque em 🔖 para marcar uma página.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: _bookmarks.length,
                itemBuilder: (ctx, i) {
                  final bm = _bookmarks[i];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B2FBE).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${bm.page}',
                          style: const TextStyle(
                              color: Color(0xFF7B2FBE),
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    title: Text(bm.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    subtitle: Text(
                      'Página ${bm.page}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white24, size: 18),
                      onPressed: () => _removeBookmark(bm),
                    ),
                    onTap: () {
                      setState(
                          () => _showBookmarkPanel = false);
                      _goToPage(bm.page);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
