import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:keryx_app/features/outlines/model/outline_model.dart';
import 'package:keryx_app/core/constants/bible_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:keryx_app/core/services/ai_service.dart';
import 'package:keryx_app/features/bible/view_model/bible_state.dart';
import 'dart:convert';
  

class OutlineEditorScreen extends ConsumerStatefulWidget {
  final String? initialBook;
  final int? initialChapter;
  final String? initialVerse;

  const OutlineEditorScreen({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.initialVerse,
  });

  @override
  ConsumerState<OutlineEditorScreen> createState() => _OutlineEditorScreenState();
}

class _OutlineEditorScreenState extends ConsumerState<OutlineEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _themeCtrl = TextEditingController();
  final _versesCtrl = TextEditingController();

  String _selectedType = 'Expositivo (Verso por Verso)';
  String _selectedVersion = 'Almeida Revisada e Atualizada (ARA)';

  late String _selectedBook;
  late int _selectedChapter;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialBook != null 
        ? 'Estudo: ${widget.initialBook} ${widget.initialChapter}:${widget.initialVerse ?? ""}' 
        : "";
    _versesCtrl.text = widget.initialVerse ?? "";
    _selectedBook = widget.initialBook ?? 'Gênesis';
    _selectedChapter = widget.initialChapter ?? 1;
  }

  final List<String> _selectedAnalyses = [];
  final List<String> _associatedVerses = [];
  final List<String> _associatedPdfs = [];

  final List<Map<String, dynamic>> _analysisOptions = [
    {'id': 'context', 'name': 'Contexto Histórico e Cultural', 'icon': Icons.history},
    {'id': 'theme', 'name': 'Análise Temática Profunda', 'icon': Icons.auto_awesome},
    {'id': 'greek_hebrew', 'name': 'Estudo de Chaves no Original (Grego/Hebraico)', 'icon': Icons.translate},
    {'id': 'homiletics', 'name': 'Sugestões Homiléticas (Pontos do Sermão)', 'icon': Icons.mic},
    {'id': 'application', 'name': 'Aplicações Práticas Contemporâneas', 'icon': Icons.lightbulb},
  ];

  final List<String> _types = [
    'Expositivo (Verso por Verso)',
    'Temático',
    'Textual',
    'Narrativo',
    'Biográfico',
  ];

  final List<String> _versions = [
    'Almeida Revisada e Atualizada (ARA)',
    'Almeida Corrigida Fiel (ACF)',
    'Nova Versão Internacional (NVI)',
    'Nova Almeida Atualizada (NAA)',
    'King James Atualizada (KJA)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.blueAccent), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Editar Esboço', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20)),
                Text('Refine as análises e configurações do seu esboço', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildStepCard(
                '1', 
                'Informações Básicas',
                [
                  _buildLabel('Título do Esboço *', Icons.history_edu),
                  _buildTextField(_titleCtrl, 'Ex: Criação do mundo'),
                  const SizedBox(height: 16),
                  _buildLabel('Tema do Esboço', Icons.bookmark),
                  _buildTextField(_themeCtrl, 'Ex: Cristo estava lá desde o começo'),
                  const SizedBox(height: 16),
                  _buildLabel('Tipo de Estudo *', Icons.architecture),
                  _buildDropdown(_selectedType, _types, (v) => setState(() => _selectedType = v!)),
                  const SizedBox(height: 16),
                  _buildLabel('Versão da Bíblia', Icons.menu_book),
                  _buildDropdown(_selectedVersion, _versions, (v) => setState(() => _selectedVersion = v!)),
                ],
              ),
              const SizedBox(height: 20),
              _buildStepCard(
                '2', 
                'Referência Bíblica',
                [
                  _buildLabel('Livro *', Icons.menu_book),
                  _buildDropdown(_selectedBook, BibleMetadata.books.map((b) => b['name'] as String).toList(), (v) => setState(() => _selectedBook = v!)),
                  const SizedBox(height: 16),
                  _buildLabel('Capítulo *', Icons.format_list_numbered),
                  _buildDropdown(_selectedChapter.toString(), List.generate(50, (i) => (i+1).toString()), (v) => setState(() => _selectedChapter = int.parse(v!))),
                  const SizedBox(height: 16),
                  _buildLabel('Versículos', Icons.list),
                  _buildTextField(_versesCtrl, 'Ex: 1,2,3 ou 1-5'),
                ],
              ),
              const SizedBox(height: 20),
              _buildStepCard(
                '3', 
                'Recursos e Análises (IA)',
                [
                  _buildLabel('Análises solicitadas à IA', Icons.psychology),
                  const SizedBox(height: 8),
                  ..._analysisOptions.map((opt) => CheckboxListTile(
                    title: Text(opt['name'], style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                    secondary: Icon(opt['icon'], color: const Color(0xFFF59E0B), size: 18),
                    value: _selectedAnalyses.contains(opt['id']),
                    activeColor: const Color(0xFF4B45D8),
                    dense: true,
                    onChanged: (v) {
                      setState(() {
                        if (v!) {
                          _selectedAnalyses.add(opt['id']);
                        } else {
                          _selectedAnalyses.remove(opt['id']);
                        }
                      });
                    },
                  )),
                  const Divider(color: Colors.white10, height: 32),
                  _buildLabel('Anexar Versículos Favoritos', Icons.favorite),
                  Text('Seus versículos marcados serão incluídos na análise da IA.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11)),
                  const SizedBox(height: 8),
                  // Seletor de favoritos
                  OutlinedButton.icon(
                    onPressed: _showFavoriteSelector, 
                    icon: const Icon(Icons.add, size: 14), 
                    label: Text(_associatedVerses.isEmpty ? 'Selecionar Favoritos' : '${_associatedVerses.length} favoritos selecionados'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _associatedVerses.isEmpty ? Colors.blueAccent : Colors.greenAccent,
                      side: BorderSide(color: _associatedVerses.isEmpty ? Colors.blueAccent : Colors.greenAccent),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLabel('Anexar PDFs da Biblioteca', Icons.picture_as_pdf),
                  Text('A IA analisará o conteúdo destes livros para enriquecer o esboço.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11)),
                  const SizedBox(height: 8),
                  // Seletor de PDFs
                  OutlinedButton.icon(
                    onPressed: _showPdfSelector, 
                    icon: const Icon(Icons.add, size: 14), 
                    label: Text(_associatedPdfs.isEmpty ? 'Selecionar Livros' : '${_associatedPdfs.length} livros selecionados'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _associatedPdfs.isEmpty ? Colors.blueAccent : Colors.greenAccent,
                      side: BorderSide(color: _associatedPdfs.isEmpty ? Colors.blueAccent : Colors.greenAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSaveButton(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStepCard(String step, String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Center(child: Text(step, style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const Divider(color: Colors.white10, height: 32),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint) {
    return TextFormField(
      controller: ctrl,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 14),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDropdown(String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          dropdownColor: Theme.of(context).colorScheme.surface,
          icon: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          isExpanded: true,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4B45D8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('PRÓXIMO PASSO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
      ),
    );
  }

  Future<void> _showFavoriteSelector() async {
    final favorites = ref.read(favoritesProvider);
    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Você não tem versículos favoritados.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Selecionar Favoritos', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            Expanded(
              child: ListView(
                children: favorites.map((key) => CheckboxListTile(
                  title: Text(key.replaceAll('_', ' '), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  value: _associatedVerses.contains(key),
                  onChanged: (v) {
                    setState(() {
                      if (v!) {
                        _associatedVerses.add(key);
                      } else {
                        _associatedVerses.remove(key);
                      }
                    });
                    setM(() {});
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _showPdfSelector() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> library = prefs.getStringList('biblioteca_books_v1') ?? [];
    
    if (library.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sua biblioteca está vazia.')));
      return;
    }

    final books = library.map((s) => json.decode(s)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Selecionar Livros da Biblioteca', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
            Expanded(
              child: ListView.builder(
                itemCount: books.length,
                itemBuilder: (context, i) {
                  final b = books[i];
                  final title = b['name'] ?? 'Sem nome';
                  return CheckboxListTile(
                    title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                    value: _associatedPdfs.contains(title),
                    onChanged: (v) {
                      setState(() {
                        if (v!) {
                          _associatedPdfs.add(title);
                        } else {
                          _associatedPdfs.remove(title);
                        }
                      });
                      setM(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('outlines')
          .doc();

      final outline = BibleOutline(
        id: docRef.id,
        title: _titleCtrl.text,
        theme: _themeCtrl.text,
        type: _selectedType,
        version: _selectedVersion,
        reference: '$_selectedBook $_selectedChapter:${_versesCtrl.text}',
        associatedVerses: _associatedVerses,
        associatedPdfs: _associatedPdfs,
        createdAt: DateTime.now(),
        analyses: _selectedAnalyses,
        isGenerating: true,
      );

      await docRef.set(outline.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Esboço criado! A IA está gerando o conteúdo...')),
        );
        Navigator.pop(context);
      }
      
      // Inicia geração via AI Service (em background ou via função)
      // Para este MVP, chamaremos o serviço aqui mesmo e atualizaremos o doc
      _generateWithAi(docRef, outline);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _isSaving = false;

  Future<void> _generateWithAi(DocumentReference docRef, BibleOutline outline) async {
    final ai = AiService();
    
    // Concatena as solicitações de análise
    String analysisStr = _selectedAnalyses.map((id) => _analysisOptions.firstWhere((o) => o['id'] == id)['name']).join(', ');
    
    final content = await ai.generateOutline(outline, additionalData: 'Análises desejadas: $analysisStr');
    
    await docRef.update({
      'content': content,
      'isGenerating': false,
    });
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, border: Border(top: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)))),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.arrow_back), label: 'Voltar'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Bíblia'),
          BottomNavigationBarItem(icon: Icon(Icons.sticky_note_2_outlined), label: 'Anotações'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'Favoritos'),
        ],
      ),
    );
  }
}
