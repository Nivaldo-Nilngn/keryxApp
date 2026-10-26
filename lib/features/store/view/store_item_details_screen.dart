import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/store/model/store_item.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/bible/navigation/view/commentary_selection_screen.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/store/view/html_book_reader_screen.dart';
import 'package:keryx_app/features/study/view/dictionary_screen.dart';
import 'package:keryx_app/core/services/bible_service.dart';
import 'package:keryx_app/features/bible/reading/view/commentary_reader_screen.dart';
import 'package:keryx_app/core/widgets/keryx_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'package:keryx_app/features/store/widgets/store_item_cover_art.dart';

final storeCommentsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, itemId) {
  return FirebaseFirestore.instance
      .collection('store_comments')
      .where('itemId', isEqualTo: itemId)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
});

class StoreItemDetailsScreen extends ConsumerWidget {
  final StoreItem item;

  const StoreItemDetailsScreen({super.key, required this.item});

  Color _getCategoryColor(StoreCategory cat) {
    switch (cat) {
      case StoreCategory.bibles: return const Color(0xFFE2B93B);
      case StoreCategory.books: return const Color(0xFFF39C12);
      case StoreCategory.commentaries: return const Color(0xFF9B59B6);
      case StoreCategory.dictionaries: return const Color(0xFF3498DB);
      case StoreCategory.culture: return const Color(0xFFE74C3C);
      case StoreCategory.outros: return const Color(0xFF95A5A6);
      default: return const Color(0xFF95A5A6);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storeProvider);
    final isDownloaded = state.isDownloaded(item.filename);
    final downloadProgress = state.downloadProgress[item.filename];
    final isDownloading = downloadProgress != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: KeryxTopBar(
        title: item.name,
        showBackButton: false,
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1000;
              
              final mainContentHeader = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Header Row: Title on Left, Icon on Right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'KeryxApp • ${item.categoryDisplayName}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              if (state.isInCloudLibrary(item.filename))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.cloud_done_rounded, size: 12, color: Theme.of(context).colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Na sua conta',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                'Conteúdo premium',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Capa de Livro Bíblico 3D com Sigla e Encadernação Nobre
                    StoreItemCoverArt(
                      item: item,
                      width: 95,
                      height: 125,
                      borderRadius: 14,
                      showRibbon: true,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Stats Row
                Row(
                  children: [
                    _buildStatColumn(context, '4,8 ★', '15 mil avaliações'),
                    _buildDivider(context),
                    _buildStatColumn(context, item.sizeBytes != null ? '${(item.sizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB' : 'N/A', 'Tamanho'),
                    _buildDivider(context),
                    _buildStatColumn(context, 'Livre', 'Classificação'),
                    _buildDivider(context),
                    _buildStatColumn(context, '10 mil+', 'Downloads'),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDownloading
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : isDownloaded 
                              ? Theme.of(context).colorScheme.surfaceContainer 
                              : const Color(0xFF01875F), // Google Play Green
                      foregroundColor: isDownloading
                          ? Colors.redAccent
                          : isDownloaded 
                              ? Theme.of(context).colorScheme.primary 
                              : Colors.white,
                      side: isDownloading 
                          ? BorderSide(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.5)
                          : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: (isDownloaded || isDownloading) ? 0 : 2,
                    ),
                    onPressed: () {
                      if (isDownloading) {
                        ref.read(storeProvider.notifier).cancelDownload(item);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Download de ${item.name} cancelado.'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }
                      
                      if (isDownloaded) {
                        if (item.category == StoreCategory.books) {
                          if (item.filename.contains('Harpa')) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BookReaderScreen(book: item)),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => HtmlBookReaderScreen(book: item)),
                            );
                          }
                        } else if (item.category == StoreCategory.commentaries) {
                          ref.read(selectedCommentaryVersionProvider.notifier).state = CommentaryMetadata(
                            id: item.id,
                            name: item.name,
                            filename: item.filename,
                            category: CommentaryCategory.estudo 
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CommentarySelectionScreen()),
                          );
                        } else if (item.category == StoreCategory.dictionaries) {
                          ref.read(selectedDictionaryProvider.notifier).state = item.filename;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                          );
                        } else if (item.category == StoreCategory.bibles) {
                          String versionKey = item.filename.split('/').last;
                          if (versionKey.toLowerCase().endsWith('.sqlite')) {
                            versionKey = versionKey.substring(0, versionKey.length - 7);
                          } else if (versionKey.toLowerCase().endsWith('.bbl.mybible')) {
                            versionKey = versionKey.substring(0, versionKey.length - 12);
                          } else if (versionKey.toLowerCase().endsWith('.mybible')) {
                            versionKey = versionKey.substring(0, versionKey.length - 8);
                          } else if (versionKey.toLowerCase().endsWith('.db')) {
                            versionKey = versionKey.substring(0, versionKey.length - 3);
                          }
                          versionKey = versionKey.toUpperCase();
                          
                          ref.read(selectedVersionProvider.notifier).setVersion(versionKey);
                          ref.read(navigationProvider.notifier).setIndex(1); // Muda para aba da Bíblia
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Conteúdo já está na sua biblioteca!')),
                          );
                        }
                      } else {
                        ref.read(storeProvider.notifier).downloadPackage(item);
                      }
                    },
                    child: isDownloading 
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  value: downloadProgress, 
                                  strokeWidth: 2.2, 
                                  color: Colors.redAccent,
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(downloadProgress * 100).toInt()}% • Cancelar Download',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.redAccent),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                            ],
                          )
                        : Text(
                            isDownloaded 
                                ? (item.category == StoreCategory.books || item.category == StoreCategory.commentaries || item.category == StoreCategory.bibles ? 'Abrir' : 'Já Instalado') 
                                : (state.isInCloudLibrary(item.filename) ? 'Baixar da Conta' : 'Instalar'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                ],
              );
              
              final mainContentScrollable = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // About Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sobre este conteúdo',
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
                  'Acesse ${item.name} e transforme seu momento de estudo e devocional. Este módulo inclui os arquivos completos perfeitamente formatados para leitura offline, garantindo que você tenha o material sempre à disposição.',
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
                              style: GoogleFonts.outfit(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // User Feedback Section
                Text(
                  'Avaliações e comentários',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                _CommentSection(itemId: item.id),
                ],
              );
    
              final similarContent = Column(
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
                          'Conteúdo adequado para todas as idades.\nUsuários Interagem, Compras no Aplicativo',
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
                  _buildSimilarItemsList(context, state),
                ],
              );
    
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24),
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
                        padding: const EdgeInsets.only(right: 24, top: 24, bottom: 120),
                        child: similarContent,
                      ),
                    ),
                  ],
                );
              }
    
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 24),
                    child: mainContentHeader,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mainContentScrollable,
                          const SizedBox(height: 32),
                          similarContent,
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CustomBottomNav(
              currentIndex: 5,
              onTap: (index) {
                ref.read(navigationProvider.notifier).setIndex(index);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarItemsList(BuildContext context, StoreState state) {
    var similar = state.availablePackages.where((i) => i.id != item.id && i.category == item.category).toList();
    if (similar.isEmpty) {
      similar = state.availablePackages.where((i) => i.id != item.id).toList();
    }
    
    // Shuffle the list
    similar.shuffle();
    
    // Just display top 6
    final displayItems = similar.take(6).toList();
    
    if (displayItems.isEmpty) return const SizedBox.shrink();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final simItem = displayItems[index];
        final simColor = _getCategoryColor(simItem.category);
        
        return InkWell(
          onTap: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StoreItemDetailsScreen(item: simItem)));
          },
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
                    child: Icon(simItem.categoryIcon, color: simColor, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                // Textos à direita
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        simItem.name,
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
                        'KeryxApp • ${simItem.categoryDisplayName}',
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
                          if (simItem.sizeBytes != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '•  ${(simItem.sizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ]
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

  Widget _buildStatColumn(BuildContext context, String topText, String bottomText) {
    return Expanded(
      child: Column(
        children: [
          Text(
            topText,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            bottomText,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
    );
  }
}

class _CommentSection extends ConsumerStatefulWidget {
  final String itemId;
  const _CommentSection({required this.itemId});

  @override
  ConsumerState<_CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<_CommentSection> {
  final TextEditingController _controller = TextEditingController();

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
      return;
    }

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
    } catch (e) {
      // Falha silenciosa ou log
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
            
            // Ordenar localmente para evitar erro de índice composto no Firestore
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ...comments.map((comment) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            child: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment['authorName'] ?? 'Usuário', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                                const SizedBox(height: 4),
                                Text(comment['text'] ?? '', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
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
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) {
            print('Firestore Error: $err');
            return Text('Erro: $err', style: const TextStyle(color: Colors.red));
          },
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
                    'Enviar comentário',
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
