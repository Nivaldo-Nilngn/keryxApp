import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/home/view/devocional_screen.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
import 'package:keryx_app/features/study/view/public_annotation_detail_screen.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsBottomSheet extends ConsumerWidget {
  const NotificationsBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeState = ref.watch(downloadedStorePackagesProvider);
    final harpaBook = storeState.availablePackages.where((p) => p.name.toLowerCase().contains('harpa') && storeState.isDownloaded(p.filename)).firstOrNull;

    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final hymnIndex = seed % 640;
    final devocionalAsync = ref.watch(devocionalDiarioProvider);
    final notificationsAsync = ref.watch(notificationsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NOTIFICAÇÕES',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1), // Indigo/Purple color
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Novidades',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Acompanhe avisos, melhorias e recursos novos do app.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),

          // Barra de ações
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.done_all, size: 16),
                  onPressed: () {
                    ref.read(notificationServiceProvider).markAllAsRead();
                  },
                  label: Text('Marcar lidas', style: GoogleFonts.outfit(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF6366F1)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('Limpar notificações?', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                        content: Text('Isso removerá todas as notificações salvas.', style: GoogleFonts.outfit(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Limpar', style: GoogleFonts.outfit(color: Colors.redAccent))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      ref.read(notificationServiceProvider).deleteAllNotifications();
                    }
                  },
                  label: Text('Limpar tudo', style: GoogleFonts.outfit(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
            ),
          ),

          // List of notifications
          Expanded(
            child: notificationsAsync.when(
              data: (notifs) {
                final systemNotifs = notifs.where((n) => n.isSystemNotification).toList();
                final socialNotifs = notifs.where((n) => !n.isSystemNotification).toList();

                final allItems = <Widget>[
                  if (devocionalAsync.valueOrNull != null)
                    _buildNotificationItem(
                      context,
                      icon: Icons.book_rounded,
                      iconColor: const Color(0xFFF59E0B),
                      title: 'Devocional do Dia',
                      time: 'Agora',
                      description: 'Acesse o seu devocional diário e medite na Palavra.',
                      isUnread: true,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DevocionalScreen(devocional: devocionalAsync.value!)));
                      },
                    ),
                  if (harpaBook != null)
                    _buildNotificationItem(
                      context,
                      icon: Icons.music_note_rounded,
                      iconColor: const Color(0xFFF07994),
                      title: 'Hino do Dia: Harpa ${hymnIndex + 1}',
                      time: 'Agora',
                      description: 'Comece o dia louvando! Ouça agora o Hino de hoje.',
                      isUnread: true,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => BookReaderScreen(book: harpaBook, initialHymnIndex: hymnIndex)));
                      },
                    ),

                  // Downloads/Sistema
                  ...systemNotifs.map((n) => Dismissible(
                    key: Key('notif_${n.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.red.withValues(alpha: 0.2),
                      child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                    ),
                    onDismissed: (_) {
                      ref.read(notificationServiceProvider).deleteNotification(n.id);
                    },
                    child: _buildNotificationItem(
                      context,
                      icon: n.type == 'download'
                          ? Icons.cloud_done_rounded
                          : n.type == 'delete'
                              ? Icons.delete_rounded
                              : Icons.info_rounded,
                      iconColor: n.type == 'download'
                          ? const Color(0xFF34D399)
                          : n.type == 'delete'
                              ? Colors.redAccent
                              : const Color(0xFF60A5FA),
                      title: n.title ?? 'Notificação do Sistema',
                      time: _fmtDate(n.createdAt),
                      description: n.message ?? n.body,
                      isUnread: !n.read,
                      onTap: () => ref.read(notificationServiceProvider).markAsRead(n.id),
                    ),
                  )),

                  // Sociais (comentários, respostas)
                  ...socialNotifs.map((n) {
                    final title = n.type == 'reply'
                        ? 'Nova resposta de ${n.fromUserName}'
                        : 'Novo comentário de ${n.fromUserName}';
                    return Dismissible(
                      key: Key('notif_${n.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Colors.red.withValues(alpha: 0.2),
                        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                      ),
                      onDismissed: (_) {
                        ref.read(notificationServiceProvider).deleteNotification(n.id);
                      },
                      child: _buildNotificationItem(
                        context,
                        icon: Icons.forum_rounded,
                        iconColor: const Color(0xFFEC4899),
                        title: title,
                        time: _fmtDate(n.createdAt),
                        description: n.body,
                        isUnread: !n.read,
                        onTap: () async {
                          ref.read(notificationServiceProvider).markAsRead(n.id);
                          try {
                            final doc = await FirebaseFirestore.instance
                                .collection('annotations')
                                .doc(n.annotationId)
                                .get();
                            if (doc.exists && context.mounted) {
                              final note = NoteCard.fromMap(doc.data()!);
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PublicAnnotationDetailScreen(
                                    note: note, focusCommentId: n.commentId),
                              ));
                            }
                          } catch (_) {}
                        },
                      ),
                    );
                  }),

                  if (systemNotifs.isEmpty && socialNotifs.isEmpty &&
                      devocionalAsync.valueOrNull == null && harpaBook == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 60),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12), size: 64),
                          const SizedBox(height: 16),
                          Text('Nenhuma notificação',
                              style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 16)),
                        ],
                      ),
                    ),
                ];

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  children: allItems,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String time,
    required String description,
    required bool isUnread,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isUnread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.day}/${d.month}';
  }
}
