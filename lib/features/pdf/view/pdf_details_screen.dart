import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/pdf/view/pdf_viewer_screen.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/services/book_cover_service.dart';
import 'package:keryx_app/core/services/pdf_service.dart';
import 'package:keryx_app/core/services/graph_service.dart';
import 'package:keryx_app/core/services/telegram/cloudflare_pdf_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/core/services/telegram/telegram_download_service.dart' as tg;
import 'package:keryx_app/core/services/telegram/telegram_http_download_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keryx_app/features/store/view/store_item_details_screen.dart';
class PdfDetailsScreen extends StatefulWidget {
  final String name;
  final String cleanName;
  final bool isLocal;
  final bool alreadyDownloaded;
  final String? localPath;
  final BookMetadata? metadata;
  final String? bookId;
  final int? bookSize;
  final VoidCallback? onDownload;
  final VoidCallback? onDownloadCompleted;
  final VoidCallback? onDeletedFromDrive;

  const PdfDetailsScreen({
    super.key,
    required this.name,
    required this.cleanName,
    required this.isLocal,
    required this.alreadyDownloaded,
    this.localPath,
    this.metadata,
    this.bookId,
    this.bookSize,
    this.onDownload,
    this.onDownloadCompleted,
    this.onDeletedFromDrive,
  });

  @override
  State<PdfDetailsScreen> createState() => _PdfDetailsScreenState();
}

class _PdfDetailsScreenState extends State<PdfDetailsScreen> {
  final _pdfService = PdfService();
  final _graphService = GraphService();
  final _downloadManager = PdfDownloadManager();
  final _bookCoverService = BookCoverService();

  late bool _isDownloaded;
  String? _currentLocalPath;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  BookMetadata? _currentMetadata;
  StreamSubscription<tg.DownloadProgress>? _telegramSub;

  bool get _isAdmin => FirebaseAuth.instance.currentUser?.uid == 'Y3DrmL850xW23Jj12b694Zq6Jj02';
  bool get _isBundledAsset => widget.localPath != null && widget.localPath!.startsWith('assets/');
  bool get _isTelegramBook => widget.bookId?.startsWith('tg:') ?? false;

  @override
  void initState() {
    super.initState();
    _isDownloaded = widget.isLocal || widget.alreadyDownloaded;
    _currentLocalPath = widget.localPath;
    _currentMetadata = widget.metadata;

    if (_currentLocalPath != null) {
      if (!kIsWeb && !_currentLocalPath!.startsWith('data:')) {
        _loadRealPdfMetadata(_currentLocalPath!);
      }
    }

    // Verifica o disco real ou cache web para refletir downloads anteriores 
    // que a loja pode não ter registrado ainda
    if (!_isDownloaded && !_isBundledAsset) {
      _checkIfAlreadyDownloaded();
    }

    if (_downloadManager.isDownloading(widget.name)) {
      _isDownloading = true;
      _downloadProgress = _downloadManager.getProgress(widget.name) ?? 0.0;
    }

    _downloadManager.activeDownloadsNotifier.addListener(_onDownloadUpdates);
  }

  Future<void> _checkIfAlreadyDownloaded() async {
    if (kIsWeb) {
      final isDownloaded = await _pdfService.isBookDownloaded(widget.name);
      if (isDownloaded && mounted) {
        final path = await _pdfService.getBookPath(widget.name);
        setState(() {
          _isDownloaded = true;
          _currentLocalPath = path;
        });
      }
      return;
    }

    // Tenta o caminho padrão (Nativo)
    try {
      String path = await _pdfService.getBookPath(widget.name);
      File file = File(path);
      
      // Se não existir, tenta com extensão .pdf
      if (!await file.exists()) {
        final fallback = File('$path.pdf');
        if (await fallback.exists()) {
          file = fallback;
          path = fallback.path;
        }
      }

      if (await file.exists() && mounted) {
        setState(() {
          _isDownloaded = true;
          _currentLocalPath = path;
        });
        // Carrega metadados reais da capa
        _loadRealPdfMetadata(path);
      }
    } catch (_) {}
  }

  Future<void> _loadRealPdfMetadata(String path) async {
    if (kIsWeb || path.startsWith('data:')) return;
    try {
      final realMeta = await _bookCoverService.extractAndSaveCoverFromPdf(widget.name, path);
      if (realMeta != null && mounted) {
        setState(() {
          _currentMetadata = realMeta;
        });
        widget.onDownloadCompleted?.call();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _telegramSub?.cancel();
    _downloadManager.activeDownloadsNotifier.removeListener(_onDownloadUpdates);
    super.dispose();
  }

  void _onDownloadUpdates() async {
    if (!mounted) return;
    final active = _downloadManager.activeDownloadsNotifier.value;
    if (active.containsKey(widget.name)) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = active[widget.name]!;
      });
    } else if (_isDownloading) {
      if (kIsWeb) {
        final isDownloaded = await _pdfService.isBookDownloaded(widget.name);
        if (mounted) {
          setState(() {
            _isDownloading = false;
            if (isDownloaded) _isDownloaded = true;
          });
        }
        return;
      }
      try {
        final path = await _pdfService.getBookPath(widget.name);
        final exists = await File(path).exists();
        if (mounted) {
          setState(() {
            _isDownloading = false;
            if (exists) {
              _isDownloaded = true;
              _currentLocalPath = path;
            }
          });
          if (exists) {
            _loadRealPdfMetadata(path);
          }
        }
      } catch (_) {
        if (mounted) {
          setState(() => _isDownloading = false);
        }
      }
    }
  }

  Future<void> _startDownload() async {
    if (_isDownloading) return;

    if (widget.onDownload != null) {
      widget.onDownload!();
      return;
    }

    if (widget.bookId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID do arquivo não encontrado.')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      if (_isTelegramBook) {
        final tgService = TelegramHttpDownloadService.instance;
        // Since downloadFile returns a Future<String?>, we await it and pass a progress callback.
        final downloadedResult = await tgService.downloadFile(
          widget.bookId!.replaceAll('tg:', ''),
          widget.name,
          (progress) {
            if (mounted) {
              setState(() => _downloadProgress = progress);
            }
          },
        );
        if (mounted) {
          final path = kIsWeb
              ? (downloadedResult ?? widget.name)
              : await _pdfService.getBookPath(widget.name);

          if (kIsWeb) {
            await _pdfService.saveWebDownloadedBook(
              widget.name,
              downloadedResult,
              fileId: widget.bookId!.replaceAll('tg:', ''),
            );
          }

          setState(() {
            _isDownloading = false;
            _isDownloaded = true;
            _currentLocalPath = path;
          });
          if (!kIsWeb) {
            _loadRealPdfMetadata(path);
          }
          widget.onDownloadCompleted?.call();
        }
      } else {
        // If no onDownload provided for OneDrive, we can't download without a URL.
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download automático pelo OneDrive requer função onDownload.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no download: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteFromDrive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Excluir da Nuvem',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Tem certeza que deseja excluir "${widget.cleanName}" permanentemente do ${_isTelegramBook ? 'Catálogo da Nuvem' : 'OneDrive'}? Esta ação não pode ser desfeita.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sim, excluir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.redAccent),
                SizedBox(height: 16),
                Text('Excluindo...', style: GoogleFonts.outfit(color: Colors.white, decoration: TextDecoration.none, fontSize: 16)),
              ],
            ),
          ),
        ),
      );
    }

    try {
      if (_isTelegramBook) {
        await CloudflarePdfService.instance.deletePdf(widget.name);
      } else {
        String? driveId = widget.bookId;
        if (driveId == null) {
          final search = await _graphService.searchPdfsRemote(query: widget.name);
          final items = search['items'] as List<dynamic>?;
          if (items != null && items.isNotEmpty) {
            final exact = items.firstWhere(
              (i) => i['name'] == widget.name,
              orElse: () => items.first,
            );
            driveId = exact['id'] as String?;
          }
        }

        if (driveId == null) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Não foi possível localizar o ID deste arquivo no OneDrive.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        await _graphService.deleteDriveItem(driveId);
      }

      await _pdfService.deleteBook(widget.name);

      if (mounted) {
        Navigator.pop(context);
        widget.onDeletedFromDrive?.call();
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
            content: Text('Livro excluído com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildStatColumn(BuildContext context, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: 2,
        onBack: () => Navigator.pop(context),
        onTap: (index) {
          if (index != 2) {
            Navigator.pop(context);
          }
        },
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1000;

          final hasCover = _currentMetadata?.coverUrl != null && _currentMetadata!.coverUrl!.isNotEmpty;
          
          Widget coverContent;
          if (hasCover) {
            String url = _currentMetadata!.coverUrl!;
            if (!kIsWeb && url.startsWith('file://')) {
              coverContent = Image.file(File(url.replaceFirst('file://', '')), fit: BoxFit.cover);
            } else if (url.startsWith('data:image')) {
              try {
                final bytes = base64Decode(url.split(',').last);
                coverContent = Image.memory(bytes, fit: BoxFit.cover);
              } catch (_) {
                coverContent = Icon(Icons.menu_book, size: 54, color: Theme.of(context).colorScheme.primary);
              }
            } else {
              coverContent = Image.network(
                url, 
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.menu_book, size: 54, color: Theme.of(context).colorScheme.primary),
              );
            }
          } else {
            coverContent = Icon(Icons.menu_book, size: 54, color: Theme.of(context).colorScheme.primary);
          }

          final coverWidget = Hero(
            tag: 'cover_${widget.isLocal ? "local" : "online"}_${widget.name}',
            child: Container(
              width: 100,
              height: 140,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: hasCover 
                  ? SizedBox(width: double.infinity, height: double.infinity, child: coverContent) 
                  : coverContent,
              ),
            ),
          );

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.cleanName,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentMetadata?.authors != null && _currentMetadata!.authors.isNotEmpty
                    ? _currentMetadata!.authors.join(', ')
                    : 'KeryxApp • Livro PDF',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Conteúdo premium',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          );

          final statsRow = Row(
            children: [
              _buildStatColumn(context, '4,8 ★', '15 mil avaliações'),
              _buildDivider(context),
              _buildStatColumn(context, widget.bookSize != null ? '${(widget.bookSize! / 1024 / 1024).toStringAsFixed(1)} MB' : 'N/A', 'Tamanho'),
              _buildDivider(context),
              _buildStatColumn(context, 'Livre', 'Classificação'),
              _buildDivider(context),
              _buildStatColumn(context, '10 mil+', 'Downloads'),
            ],
          );

          Widget actionButtons;
          if (_isDownloaded) {
            actionButtons = ElevatedButton(
              onPressed: () async {
                String? pathToOpen = _currentLocalPath;
                if ((pathToOpen == null || (!pathToOpen.startsWith('data:') && !pathToOpen.startsWith('memory:'))) && kIsWeb) {
                  pathToOpen = await _pdfService.getBookPath(widget.name);
                  if (!pathToOpen.startsWith('data:') && !pathToOpen.startsWith('memory:') && _isTelegramBook) {
                    _startDownload();
                    return;
                  }
                }
                if (pathToOpen != null && mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfViewerScreen(
                        pdfUrl: pathToOpen!,
                        title: widget.name,
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: Text(
                'Abrir E-book',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          } else if (_isDownloading) {
            actionButtons = Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Baixando E-book...',
                            style: GoogleFonts.outfit(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: GoogleFonts.outfit(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            );
          } else {
            actionButtons = ElevatedButton(
              onPressed: _startDownload,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF01875F), // Google Play Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 2,
              ),
              child: Text(
                'Instalar E-book',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          final mainContentHeader = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: titleBlock,
                  ),
                  const SizedBox(width: 16),
                  coverWidget,
                ],
              ),
              const SizedBox(height: 24),
              statsRow,
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                child: actionButtons,
              ),
            ],
          );

          final mainContentScrollable = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Sobre este e-book
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sobre este e-book',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onSurface),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _currentMetadata?.description ??
                    'Este material faz parte do Acervo Online. Acesse o documento completo em PDF e adicione à sua biblioteca particular do KeryxApp.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              // Data Safety Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Segurança dos dados',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onSurface),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sua segurança começa quando você entende como o KeryxApp protege os seus dados. Nossas práticas de privacidade são transparentes.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.cloud_off, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '100% Offline após baixado',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Comments Section
              Text(
                'Avaliações e comentários',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _PdfCommentSection(itemId: widget.bookId ?? widget.name),
            ],
          );

          Widget bodyContent;
          if (isWide) {
            bodyContent = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
                        child: mainContentHeader,
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                          child: mainContentScrollable,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Classification Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'L',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).colorScheme.surface,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Classificação Livre',
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Conteúdo adequado para todas as idades.\nLeitura offline disponível.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Saiba mais',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // App Support
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Suporte do app',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurface),
                          ],
                        ),
                        const SizedBox(height: 32),
          
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Mais para explorar',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward, color: Theme.of(context).colorScheme.onSurface),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSimilarItemsList(context),
                      ],
                    ),
                  ),
                ),
              ],
            );
          } else {
            bodyContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
                  child: mainContentHeader,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                    child: mainContentScrollable,
                  ),
                ),
              ],
            );
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sub-header (Back button)
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Detalhes do Livro',
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isAdmin && !_isBundledAsset) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _confirmDeleteFromDrive,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.15),
                          foregroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.redAccent),
                        label: Text(
                          'Excluir Nuvem',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: bodyContent),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSimilarItemsList(BuildContext context) {
    // Lista estática simulada para igualar à loja visualmente
    final mockItems = [
      {'name': 'História de Israel', 'size': '5.2 MB', 'icon': Icons.menu_book},
      {'name': 'Teologia Sistemática', 'size': '12.4 MB', 'icon': Icons.menu_book},
      {'name': 'Comentário Bíblico', 'size': '8.1 MB', 'icon': Icons.menu_book},
    ];
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockItems.length,
      itemBuilder: (context, index) {
        final item = mockItems[index];
        final simColor = Theme.of(context).colorScheme.primary;
        
        return InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Ícone na esquerda
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: simColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: simColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Icon(item['icon'] as IconData, color: simColor, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                // Textos à direita
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'KeryxApp • Livro PDF',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '4,8 ★',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${item['size']}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PdfCommentSection extends ConsumerStatefulWidget {
  final String itemId;
  const _PdfCommentSection({required this.itemId});

  @override
  ConsumerState<_PdfCommentSection> createState() => _PdfCommentSectionState();
}

class _PdfCommentSectionState extends ConsumerState<_PdfCommentSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isSent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // User must be logged in to comment
      return;
    }
    
    setState(() {
      _isSent = true;
    });

    try {
      await FirebaseFirestore.instance.collection('store_comments').add({
        'itemId': widget.itemId,
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Usuário',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      _controller.clear();
      FocusScope.of(context).unfocus();
      
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isSent = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isSent = false;
      });
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance.collection('store_comments').doc(commentId).delete();
  }

  void _editComment(Map<String, dynamic> comment) {
    final editController = TextEditingController(text: comment['text']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Comentário', style: GoogleFonts.outfit()),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainer,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: GoogleFonts.outfit()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () async {
              if (editController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('store_comments').doc(comment['id']).update({
                  'text': editController.text.trim(),
                  'editedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('Salvar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCommentOptions(BuildContext context, Map<String, dynamic> comment) {
    showModalBottomSheet(
      context: context,
      constraints: const BoxConstraints(maxWidth: 500),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
                title: Text('Editar Comentário', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _editComment(comment);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text('Excluir Comentário', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteComment(comment['id']);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _canEditComment(Map<String, dynamic> comment) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (user.uid == comment['authorId']) return true;
    if (user.uid == 'Y3DrmL850xW23Jj12b694Zq6Jj02') return true; // Admin
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(storeCommentsProvider(widget.itemId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentsAsync.when(
            data: (commentsData) {
              if (commentsData.isEmpty) return const SizedBox.shrink();
              
              final comments = List<Map<String, dynamic>>.from(commentsData);
              comments.sort((a, b) {
                final aTime = a['createdAt'] as Timestamp?;
                final bTime = b['createdAt'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comentários da Comunidade',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...comments.map((comment) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                              child: Icon(Icons.person, size: 16, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['authorName'] ?? 'Usuário', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                                  const SizedBox(height: 2),
                                  Text(comment['text'] ?? '', style: GoogleFonts.outfit(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                                ],
                              ),
                            ),
                            if (_canEditComment(comment))
                              IconButton(
                                icon: Icon(Icons.more_vert_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showCommentOptions(context, comment),
                              ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Encontrou algum erro no módulo ou tem alguma sugestão? Deixe seu comentário relatando sua experiência.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
            controller: _controller,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Descreva sua experiência ou relate um problema...',
              hintStyle: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainer,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: _submitComment,
              child: Text(
                _isSent ? 'Enviado!' : 'Enviar comentário',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    ),
      ],
    );
  }
}

