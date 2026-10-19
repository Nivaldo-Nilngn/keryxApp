import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:keryx_app/features/outlines/model/outline_model.dart';


class OutlineViewerScreen extends ConsumerWidget {
  final BibleOutline outline;
  const OutlineViewerScreen({super.key, required this.outline});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.blueAccent), onPressed: () => Navigator.pop(context)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(outline.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(outline.reference, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)), onPressed: () {}),
          IconButton(icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)), onPressed: () {}),
        ],
      ),
      body: outline.isGenerating
          ? _buildGeneratingState(context)
          : outline.content == null
              ? _buildEmptyState(context)
              : _buildContent(context),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildGeneratingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFF59E0B)),
          const SizedBox(height: 24),
          Text('A IA está trabalhando...', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('Isso pode levar de 30 a 60 segundos.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text('Nenhum conteúdo gerado ainda.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Markdown(
      data: outline.content!,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 16),
        h1: GoogleFonts.outfit(color: Colors.orange, fontWeight: FontWeight.bold),
        h2: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        h3: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        listBullet: const TextStyle(color: Colors.orange),
        blockquote: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: const Border(left: BorderSide(color: Colors.orange, width: 4)),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)))),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.edit),
              label: const Text('Editar Parâmetros'),
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), foregroundColor: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Exportar PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4B45D8), foregroundColor: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
