import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:keryx_app/features/store/view_model/store_view_model.dart';
import 'package:keryx_app/features/store/view/book_reader_screen.dart';
import 'package:keryx_app/features/home/view/devocional_screen.dart';
import 'package:keryx_app/features/home/service/devocional_service.dart';
import 'package:keryx_app/features/home/view_model/notifications_provider.dart';
import 'package:keryx_app/features/study/view/public_annotation_detail_screen.dart';
import 'package:keryx_app/features/study/model/note_card.dart';
import 'package:keryx_app/core/services/notification_service.dart';
import 'package:keryx_app/core/services/push_notification_service.dart';
import 'package:keryx_app/core/services/app_update_service.dart';
import 'package:keryx_app/core/services/internal_download_service.dart';
import 'package:keryx_app/core/services/release_notes_service.dart';

class _NotifEntry {
  final String? id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;
  final String description;
  final bool isUnread;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _NotifEntry({
    this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
    required this.description,
    required this.isUnread,
    required this.onTap,
    this.onDelete,
  });
}

class NotificationsBottomSheet extends ConsumerStatefulWidget {
  const NotificationsBottomSheet({super.key});

  @override
  ConsumerState<NotificationsBottomSheet> createState() => _NotificationsBottomSheetState();
}

class _NotificationsBottomSheetState extends ConsumerState<NotificationsBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(latestUpdateInfoProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final storeState = ref.watch(downloadedStorePackagesProvider);
    final harpaBook = storeState.availablePackages
        .where((p) => p.name.toLowerCase().contains('harpa') && storeState.isDownloaded(p.filename))
        .firstOrNull;

    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final hymnIndex = seed % 640;
    final devocionalAsync = ref.watch(devocionalDiarioProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final dismissedDaily = ref.watch(dismissedDailyProvider);
    final dismissedIds = ref.watch(dismissedNotificationIdsProvider);
    final updateInfo = ref.watch(latestUpdateInfoProvider).valueOrNull;
    final isUpdateAvailable = ref.watch(isUpdateAvailableProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isExpanded = screenWidth >= 1024;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 14, bottom: 8),
                  width: isTablet ? 54 : 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 36 : 20,
                  isTablet ? 12 : 8,
                  isTablet ? 36 : 20,
                  isTablet ? 16 : 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: const Color(0xFF6366F1),
                        size: isTablet ? 26 : 22,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'NOTIFICAÇÕES',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF6366F1),
                                  letterSpacing: 1.3,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$unreadCount nova${unreadCount > 1 ? 's' : ''}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Novidades & Alertas',
                            style: GoogleFonts.outfit(
                              fontSize: isTablet ? 24 : 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Acompanhe avisos, melhorias, downloads e recursos novos do app.',
                            style: GoogleFonts.outfit(
                              fontSize: isTablet ? 14 : 12,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: isTablet ? 22 : 20,
                        ),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Barra de ações (Marcar lidas / Limpar tudo)
              Container(
                margin: EdgeInsets.symmetric(horizontal: isTablet ? 36 : 20),
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      onPressed: () async {
                        await ref.read(notificationServiceProvider).markAllAsRead();
                        ref.read(notificationUiServiceProvider).showInfo(
                              'Todas as notificações foram marcadas como lidas.',
                            );
                      },
                      label: Text(
                        'Marcar todas como lidas',
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 8, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: Theme.of(context).cardColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text(
                              'Limpar notificações?',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              'Isso removerá todas as notificações salvas do banco de dados, incluindo avisos de downloads e o devocional de hoje.',
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                child: Text(
                                  'Limpar tudo',
                                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          // 1. Dispensa instantaneamente itens diários (devocional e hino de hoje)
                          await ref.read(dismissedDailyProvider.notifier).dismissAllDaily([
                            'devocional_$todayStr',
                            'hymn_$todayStr',
                          ]);

                          // 2. Dispensa instantaneamente todos os IDs atuais para reflexo imediato na UI
                          final notifsList = notificationsAsync.valueOrNull ?? [];
                          ref.read(dismissedNotificationIdsProvider.notifier).dismissAll(notifsList.map((n) => n.id));

                          // 3. Remove tudo do banco de dados Firestore
                          await ref.read(notificationServiceProvider).deleteAllNotifications();

                          // 4. Limpa o tracker de deduplicação push/local
                          await ref.read(pushNotificationServiceProvider).clearNotifiedTracker();

                          // 5. Exibe feedback padronizado do NotificationService
                          ref.read(notificationUiServiceProvider).showSuccess(
                                'Todas as notificações e devocional foram limpos.',
                              );
                        }
                      },
                      label: Text(
                        'Limpar tudo',
                        style: GoogleFonts.outfit(
                          fontSize: isTablet ? 13 : 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 8, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de notificações
              Expanded(
                child: notificationsAsync.when(
                  data: (notifs) {
                    final systemNotifs = notifs.where((n) => n.isSystemNotification).toList();
                    final socialNotifs = notifs.where((n) => !n.isSystemNotification).toList();

                    final isDevocionalDismissed = dismissedDaily.contains('devocional_$todayStr');
                    final isHymnDismissed = dismissedDaily.contains('hymn_$todayStr');

                    final entries = <_NotifEntry>[
                      // Notas de Atualização e Novidades da Versão
                      _NotifEntry(
                        id: 'whats_new_current',
                        icon: Icons.auto_awesome_rounded,
                        iconColor: const Color(0xFFFFD56B),
                        title: 'Novidades da Versão: O que mudou?',
                        time: 'Novidades',
                        description:
                            'Toque para conferir todos os novos recursos, melhorias e modificações implementados nesta versão.',
                        isUnread: false,
                        onTap: () {
                          Navigator.pop(context);
                          ref.read(releaseNotesServiceProvider).showReleaseNotes(context);
                        },
                      ),
                      if (isUpdateAvailable && updateInfo != null)
                        _NotifEntry(
                          id: 'update_v${updateInfo.versionName}',
                          icon: Icons.system_update_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Nova Atualização: v${updateInfo.versionName}',
                          time: 'Disponível',
                          description: (updateInfo.releaseNotes.isNotEmpty)
                              ? updateInfo.releaseNotes
                              : 'Nova versão disponível para o seu aparelho. Toque para baixar e atualizar agora.',
                          isUnread: true,
                          onTap: () {
                            final url = (updateInfo.downloadUrl.isNotEmpty)
                                ? updateInfo.downloadUrl.trim()
                                : 'https://keryx-version.nivaldo-nilngn.workers.dev/download';
                            ref.read(downloadServiceProvider).downloadAndInstall(context, url);
                          },
                        ),
                      if (devocionalAsync.valueOrNull != null && !isDevocionalDismissed)
                        _NotifEntry(
                          id: 'devocional_$todayStr',
                          icon: Icons.auto_stories_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Devocional do Dia',
                          time: 'Hoje',
                          description: 'Acesse o seu devocional diário e medite na Palavra.',
                          isUnread: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DevocionalScreen(devocional: devocionalAsync.value!),
                              ),
                            );
                          },
                          onDelete: () {
                            ref.read(dismissedDailyProvider.notifier).dismiss('devocional_$todayStr');
                          },
                        ),
                      if (harpaBook != null && !isHymnDismissed)
                        _NotifEntry(
                          id: 'hymn_$todayStr',
                          icon: Icons.music_note_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: 'Hino do Dia: Harpa ${hymnIndex + 1}',
                          time: 'Hoje',
                          description: 'Comece o dia louvando! Ouça agora o Hino de hoje.',
                          isUnread: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookReaderScreen(book: harpaBook, initialHymnIndex: hymnIndex),
                              ),
                            );
                          },
                          onDelete: () {
                            ref.read(dismissedDailyProvider.notifier).dismiss('hymn_$todayStr');
                          },
                        ),

                      // Downloads e Sistema (filtrando excluídos localmente)
                      ...systemNotifs.where((n) => !dismissedIds.contains(n.id)).map((n) => _NotifEntry(
                        id: n.id,
                        icon: n.type == 'download'
                            ? Icons.cloud_done_rounded
                            : n.type == 'delete'
                                ? Icons.delete_outline_rounded
                                : Icons.info_outline_rounded,
                        iconColor: n.type == 'download'
                            ? const Color(0xFF10B981)
                            : n.type == 'delete'
                                ? Colors.redAccent
                                : const Color(0xFF3B82F6),
                        title: n.title ?? 'Notificação do Sistema',
                        time: _fmtDate(n.createdAt),
                        description: n.message ?? n.body,
                        isUnread: !n.read,
                        onTap: () => ref.read(notificationServiceProvider).markAsRead(n.id),
                        onDelete: () {
                          ref.read(dismissedNotificationIdsProvider.notifier).dismiss(n.id);
                          ref.read(notificationServiceProvider).deleteNotification(n.id);
                        },
                      )),

                      // Sociais / Comunidade (comentários, respostas, curtidas)
                      ...socialNotifs.where((n) => !dismissedIds.contains(n.id)).map((n) {
                        final isReply = n.type == 'reply';
                        final isLike = n.type == 'like';

                        final icon = isLike
                            ? Icons.favorite_rounded
                            : isReply
                                ? Icons.reply_rounded
                                : Icons.forum_rounded;

                        final iconColor = isLike
                            ? const Color(0xFFEF4444)
                            : isReply
                                ? const Color(0xFF06B6D4)
                                : const Color(0xFF8B5CF6);

                        final baseTitle = n.title ??
                            (isReply
                                ? 'Resposta de ${n.fromUserName}'
                                : isLike
                                    ? 'Curtida de ${n.fromUserName}'
                                    : 'Comentário de ${n.fromUserName}');

                        final displayTitle = (n.postTitle != null && n.postTitle!.isNotEmpty)
                            ? '$baseTitle • ${n.postTitle}'
                            : baseTitle;

                        final displayBody = isLike
                            ? '${n.fromUserName} curtiu sua publicação na Comunidade.'
                            : n.body;

                        return _NotifEntry(
                          id: n.id,
                          icon: icon,
                          iconColor: iconColor,
                          title: displayTitle,
                          time: _fmtDate(n.createdAt),
                          description: displayBody,
                          isUnread: !n.read,
                          onDelete: () {
                            ref.read(dismissedNotificationIdsProvider.notifier).dismiss(n.id);
                            ref.read(notificationServiceProvider).deleteNotification(n.id);
                          },
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PublicAnnotationDetailScreen(
                                      note: note,
                                      focusCommentId: n.commentId.isNotEmpty ? n.commentId : null,
                                    ),
                                  ),
                                );
                              }
                            } catch (_) {}
                          },
                        );
                      }),
                    ];

                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_none_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.15),
                                size: isTablet ? 72 : 56,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhuma notificação por aqui',
                                style: GoogleFonts.outfit(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                                  fontSize: isTablet ? 17 : 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (isTablet) {
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          36,
                          16,
                          36,
                          MediaQuery.of(context).viewInsets.bottom + 24,
                        ),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isExpanded ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 118,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return _buildTabletCard(context, entries[index]);
                        },
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        8,
                        12,
                        MediaQuery.of(context).viewInsets.bottom + 24,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        if (entry.onDelete != null && entry.id != null) {
                          return Dismissible(
                            key: Key('notif_${entry.id}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                            ),
                            onDismissed: (_) => entry.onDelete?.call(),
                            child: _buildMobileItem(context, entry),
                          );
                        }
                        return _buildMobileItem(context, entry);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletCard(BuildContext context, _NotifEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: entry.isUnread
            ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.12 : 0.06)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isUnread
              ? const Color(0xFF6366F1).withValues(alpha: 0.4)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
          width: entry.isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: entry.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: entry.iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: entry.iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            entry.time,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.onDelete != null) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    tooltip: 'Remover',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: entry.onDelete,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileItem(BuildContext context, _NotifEntry entry) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: entry.isUnread
            ? const Color(0xFF6366F1).withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: entry.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: entry.iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(entry.icon, color: entry.iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (entry.isUnread) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            entry.time,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.35,
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
