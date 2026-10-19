import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:keryx_app/core/theme/app_theme.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/services/auth_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import '../model/study_plan_model.dart';
import '../repository/study_plan_repository.dart';

import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

class StudyLessonScreen extends ConsumerStatefulWidget {
  final String planId;
  final StudyLesson lesson;
  final int totalLessons;

  const StudyLessonScreen({
    super.key,
    required this.planId,
    required this.lesson,
    required this.totalLessons,
  });

  @override
  ConsumerState<StudyLessonScreen> createState() => _StudyLessonScreenState();
}

class _StudyLessonScreenState extends ConsumerState<StudyLessonScreen> {
  final bool _isNavVisible = true;

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    final progressAsync = ref.watch(activePlanProgressProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: MBibliaTopBar(
        title: "Aula ${widget.lesson.lessonIndex}",
        isScrolled: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 200), // Espaço para botão + navbar
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TÍTULO DA AULA ---
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.kPrimaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "DIA ${widget.lesson.lessonIndex}",
                          style: GoogleFonts.outfit(
                            color: AppTheme.kPrimaryGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.lesson.title,
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- SEÇÃO 1: INTRODUÇÃO (DEVOCIONAL) ---
                _buildSectionHeader(Icons.lightbulb_outline_rounded, "INTRODUÇÃO"),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: MarkdownBody(
                    data: widget.lesson.devotional,
                    builders: {
                      'blockquote': _BlockquoteBuilder(context),
                    },
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.outfit(
                        fontSize: 16,
                        height: 1.7,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                      h3: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.kPrimaryGold,
                        height: 2.2,
                      ),
                      blockquote: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                      blockquoteDecoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.15)),
                      ),
                      blockquotePadding: const EdgeInsets.all(24),
                      listBullet: GoogleFonts.outfit(color: AppTheme.kPrimaryGold),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                
                // --- SEÇÃO 2: LEITURA BÍBLICA (VERSÍCULOS) ---
                if (widget.lesson.verses.isNotEmpty) ...[
                  _buildSectionHeader(Icons.auto_stories_rounded, "LEITURA BÍBLICA", color: const Color(0xFF4A90E2)),
                  ...widget.lesson.verses.map((v) => _VerseStudyCard(reference: v)),
                  const SizedBox(height: 48),
                ],
    
                // --- SEÇÃO 3: APROFUNDAMENTO (TÓPICOS) ---
                if (widget.lesson.topics.isNotEmpty) ...[
                  _buildSectionHeader(Icons.psychology_outlined, "APROFUNDAMENTO", color: const Color(0xFF7B61FF)),
                  ...widget.lesson.topics.map((topic) => _TopicItem(topic: topic)),
                  const SizedBox(height: 48),
                ],
    
                // --- SEÇÃO 4: VERIFICAÇÃO (QUIZ) ---
                if (widget.lesson.quiz.isNotEmpty) ...[
                  _buildSectionHeader(Icons.checklist_rounded, "VERIFICAÇÃO", color: const Color(0xFFFF6B6B)),
                  ...widget.lesson.quiz.map((q) => _QuizItem(question: q)),
                  const SizedBox(height: 24),
                ],
    
                // --- SEÇÃO 5: REFLEXÃO PESSOAL (PERGUNTAS) ---
                if (widget.lesson.questions.isNotEmpty) ...[
                  _buildSectionHeader(Icons.chat_bubble_outline_rounded, "REFLEXÃO PESSOAL", color: const Color(0xFF00E676)),
                  ...widget.lesson.questions.map((q) => _QuestionItem(question: q)),
                  const SizedBox(height: 120),
                ],
              ],
            ),
          ),
          
          // Botão de Conclusão Fixo (Sobreposto à Navbar)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 88), // Espaço para a navbar abaixo
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
                    Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: progressAsync.when(
                data: (progress) {
                  final isCompleted = progress?.completedLessons.contains(widget.lesson.lessonIndex) ?? false;
                  return ElevatedButton(
                    onPressed: isCompleted ? null : () async {
                      if (authUser == null) return;
                      await ref.read(studyPlanRepositoryProvider).completeLesson(
                        uid: authUser.uid,
                        planId: widget.planId,
                        lessonIndex: widget.lesson.lessonIndex,
                        totalLessons: widget.totalLessons,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Parabéns! Aula concluída. 🔥')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCompleted ? Colors.green.withValues(alpha: 0.2) : AppTheme.kPrimaryGold,
                      foregroundColor: isCompleted ? Colors.green : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppTheme.kPrimaryGold.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isCompleted ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded),
                        const SizedBox(width: 10),
                        Text(
                          isCompleted ? "AULA CONCLUÍDA" : "CONCLUIR AULA",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 50, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Navbar Fixa
          Align(
            alignment: Alignment.bottomCenter,
            child: StudyBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pop(context);
                } else if (index == 1) {
                  ref.read(navigationProvider.notifier).setIndex(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 2) {
                  ref.read(navigationProvider.notifier).setIndex(1);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, {Color color = AppTheme.kPrimaryGold}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20, top: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  height: 2,
                  width: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseStudyCard extends ConsumerWidget {
  final BibleReference reference;
  const _VerseStudyCard({required this.reference});

  String _cleanText(String? text) {
    if (text == null) return "";
    // Remove Strong's codes: [H1234], [G5678]
    String result = text.replaceAll(RegExp(r'\[[HG]\d+\]'), '');
    // Remove HTML tags: <b>, </i>, etc.
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');
    return result.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bibleService = ref.read(bibleServiceProvider);
    final version = ref.read(selectedVersionProvider);
    final label = reference.label ?? "${reference.book} ${reference.chapter}:${reference.verseStart}";

    return FutureBuilder<Map<String, String?>>(
      future: () async {
        try {
          final chapterData = await bibleService.getChapter(
            version, 
            reference.book, 
            reference.chapter
          );
          
          final verse = chapterData.verses.firstWhere(
            (v) => v.number == reference.verseStart,
            orElse: () => chapterData.verses.first,
          );

          // Tenta pegar o comentário (MacArthur)
          final commentary = await bibleService.getCommentaryForVerse(
            filename: 'Notas da Bíblia de Estudo Macarthur.cmt.mybible',
            versionId: 'MACARTHUR',
            bookId: int.parse(reference.book),
            chapter: reference.chapter,
            verse: reference.verseStart,
          );

          return {
            'verse': verse.text,
            'commentary': commentary,
          };
        } catch (e) {
          return {'verse': 'Erro ao carregar versículo.', 'commentary': null};
        }
      }(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        
        final verseText = _cleanText(snapshot.data!['verse']);
        final commentaryText = _cleanText(snapshot.data!['commentary']);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          decoration: BoxDecoration(
            color: AppTheme.kPrimaryGold.withValues(alpha: 0.05), // Fundo dourado sutil
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Cabeçalho Centralizado e Elegante
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 8),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.kPrimaryGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.auto_stories_rounded, color: AppTheme.kPrimaryGold, size: 20),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    // Texto do Versículo - CENTRALIZADO e IMPACTANTE
                    Text(
                      verseText,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                        height: 1.7,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.2,
                      ),
                    ),

                    // NOTAS DE ESTUDO (Se houver)
                    if (commentaryText.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_edu_rounded, color: AppTheme.kPrimaryGold.withValues(alpha: 0.8), size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "CONTEXTO DE ESTUDO",
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.kPrimaryGold.withValues(alpha: 0.8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              commentaryText,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    // REFERÊNCIA AO FINAL, À DIREITA
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        "— $label",
                        style: GoogleFonts.outfit(
                          color: AppTheme.kPrimaryGold,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopicItem extends StatelessWidget {
  final StudyTopic topic;
  const _TopicItem({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B61FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic.title.toUpperCase(),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.9),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: topic.summary,
            builders: {
              'blockquote': _BlockquoteBuilder(context),
            },
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                height: 1.7,
                fontSize: 16,
              ),
              h3: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.9),
                height: 2.0,
              ),
              blockquote: GoogleFonts.outfit(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
              blockquoteDecoration: BoxDecoration(
                color: AppTheme.kPrimaryGold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.kPrimaryGold.withValues(alpha: 0.15)),
              ),
              blockquotePadding: const EdgeInsets.all(24),
              listBullet: GoogleFonts.outfit(color: const Color(0xFF7B61FF)),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ],
      ),
    );
  }
}

class _QuizItem extends StatefulWidget {
  final StudyQuestion question;
  const _QuizItem({required this.question});

  @override
  State<_QuizItem> createState() => _QuizItemState();
}

class _QuizItemState extends State<_QuizItem> {
  bool? selectedAnswer;
  bool showExplanation = false;

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = selectedAnswer == widget.question.isTrue;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedAnswer == null 
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05) 
              : (isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question.text,
            style: GoogleFonts.outfit(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: "VERDADEIRO",
                  isSelected: selectedAnswer == true,
                  color: Colors.green,
                  onTap: selectedAnswer != null ? null : () {
                    setState(() {
                      selectedAnswer = true;
                      showExplanation = true;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnswerButton(
                  label: "FALSO",
                  isSelected: selectedAnswer == false,
                  color: Colors.red,
                  onTap: selectedAnswer != null ? null : () {
                    setState(() {
                      selectedAnswer = false;
                      showExplanation = true;
                    });
                  },
                ),
              ),
            ],
          ),
          if (showExplanation && widget.question.explanation != null) ...[
            const SizedBox(height: 16),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: isCorrect ? Colors.green : AppTheme.kPrimaryGold,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.question.explanation!,
                    style: GoogleFonts.outfit(
                      color: isCorrect ? Colors.green.withValues(alpha: 0.8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.isSelected,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionItem extends StatelessWidget {
  final String question;
  const _QuestionItem({required this.question});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                question,
                style: GoogleFonts.outfit(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockquoteBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  _BlockquoteBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    // Regex para identificar a referência bíblica no final entre parênteses
    // Ex: (Gênesis 1:3-5)
    final refRegex = RegExp(r'\s*\(([^)]+\d+:\d+[^)]*)\)$');
    final match = refRegex.firstMatch(text);

    String bodyText;
    String? referenceText;

    if (match != null) {
      bodyText = text.substring(0, match.start).trim();
      referenceText = match.group(1);
    } else {
      bodyText = text;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          bodyText,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
        if (referenceText != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "— $referenceText",
              style: GoogleFonts.outfit(
                color: AppTheme.kPrimaryGold,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
