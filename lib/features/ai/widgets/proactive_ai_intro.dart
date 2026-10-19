import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/services/ai_service.dart';
import 'package:keryx_app/features/bible/model/bible_model.dart';

class ProactiveAiChapterIntro extends ConsumerStatefulWidget {
  final BibleChapter chapter;
  const ProactiveAiChapterIntro({super.key, required this.chapter});

  @override
  ConsumerState<ProactiveAiChapterIntro> createState() => _ProactiveAiChapterIntroState();
}

class _ProactiveAiChapterIntroState extends ConsumerState<ProactiveAiChapterIntro> {
  bool _showIntro = false;

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      final aiService = AiService();
      final introQuery = 'Introdução histórico-teológica ao capítulo ${widget.chapter.book.name} ${widget.chapter.chapterNumber}. Deixe claro o contexto, autor, data e temas principais.';

      return FutureBuilder<String>(
        future: aiService.generateSermonDraftFromWorker(introQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
          }
          return SelectableText(snapshot.data ?? 'Erro ao gerar introdução.', style: const TextStyle(fontSize: 16, height: 1.6));
        },
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Icon(Icons.auto_awesome, color: Colors.orange.withValues(alpha: 0.3), size: 64),
        const SizedBox(height: 24),
        const Text(
          'Sem introdução oficial para este capítulo.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Deseja que a IA gere uma introdução agora?',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => setState(() => _showIntro = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          icon: const Icon(Icons.flash_on),
          label: const Text('GERAR INTRODUÇÃO IA'),
        ),
      ],
    );
  }
}
