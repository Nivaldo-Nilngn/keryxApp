import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keryx_app/core/state/navigation_state.dart';
import 'package:keryx_app/core/widgets/mbiblia_top_bar.dart';
import 'package:keryx_app/core/widgets/custom_bottom_nav.dart';

class GuideScreen extends ConsumerStatefulWidget {
  const GuideScreen({super.key});

  @override
  ConsumerState<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends ConsumerState<GuideScreen> {
  String _searchQuery = '';
  int? _expandedIndex;

  List<Map<String, dynamic>> get _guideItems => [
    {
      'title': 'Bíblia e personalização',
      'icon': Icons.menu_book_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Escolha o livro e o capítulo. Na leitura, use os botões do topo para trocar livro, capítulo ou versão.',
        'Abra Personalizar para escolher fonte, tamanho, espaçamento e versículos separados ou contínuos. A prévia mostra o resultado antes de salvar.',
        'A personalização também acompanha os textos da Harpa e das ferramentas de estudo.',
        'Toque em um versículo para abrir suas ferramentas; você pode selecionar vários.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
      },
    },
    {
      'title': 'Me explica e estudos',
      'icon': Icons.auto_awesome_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Selecione um versículo e toque em "Me explica" para receber uma explicação detalhada gerada por IA.',
        'Acesse dicionários e comentários bíblicos integrados para aprofundar seu entendimento.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(2); // Comentários/Estudos
      },
    },
    {
      'title': 'IATheos Chat',
      'icon': Icons.chat_bubble_outline_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Converse com nossa IA especializada em teologia.',
        'Tire dúvidas sobre passagens complexas ou contextos históricos.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
      },
    },
    {
      'title': 'Comparar versões',
      'icon': Icons.layers_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Selecione um versículo e escolha a opção de comparar.',
        'Veja lado a lado como diferentes traduções interpretam o mesmo texto original.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
      },
    },
    {
      'title': 'Referências bíblicas',
      'icon': Icons.link_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Descubra versículos relacionados que tratam do mesmo tema ou evento.',
        'Navegue facilmente entre as referências cruzadas.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
      },
    },
    {
      'title': 'Minhas marcações',
      'icon': Icons.bookmark_border_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Destaque versículos com cores diferentes.',
        'Encontre todas as suas marcações organizadas em uma única tela.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(4); // Favoritos
      },
    },
    {
      'title': 'Minhas anotações',
      'icon': Icons.edit_note_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Crie notas pessoais vinculadas a versículos específicos.',
        'Use como um diário de devocional ou caderno de estudos.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(3); // Anotações
      },
    },
    {
      'title': 'Comunidade',
      'icon': Icons.people_outline_rounded,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Participe de fóruns de discussão sobre temas bíblicos.',
        'Compartilhe seus estudos e aprenda com outros irmãos.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
      },
    },
    {
      'title': 'Versículos por tema',
      'icon': Icons.local_offer_outlined,
      'color': const Color(0xFFFFB95F),
      'steps': [
        'Busque versículos separados por emoções, situações ou temas teológicos.',
        'Ideal para encontrar a palavra certa para o momento certo.'
      ],
      'actionText': 'Abrir ferramenta',
      'onTap': () {
        Navigator.pop(context);
        ref.read(navigationProvider.notifier).setIndex(1); // Bíblia
      },
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredItems = _guideItems.where((item) {
      final title = item['title'].toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: MBibliaTopBar(
        title: 'KeryxApp',
        showLogo: true,
        showBackButton: false,
        onTitleTap: () => Navigator.pop(context),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  'Seu guia para aproveitar cada ferramenta.',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                    ),
                    boxShadow: isDark ? [] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      hintText: 'Buscar no guia',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 8.0, bottom: 100.0), // Padding extra no bottom pra nav bar
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isExpanded = _expandedIndex == index;

                    return _buildExpandableCard(
                      item: item,
                      isExpanded: isExpanded,
                      onToggle: () {
                        setState(() {
                          _expandedIndex = isExpanded ? null : index;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CustomBottomNav(
              currentIndex: -1, // -1 para não ser a Home, mostrando botões de Voltar e Início
              onTap: (index) {
                Navigator.pop(context);
                ref.read(navigationProvider.notifier).setIndex(index);
              },
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableCard({
    required Map<String, dynamic> item,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Configurações baseadas no tema para evitar dourado no branco e criar efeito 3D
    final iconColor = isDark ? (item['color'] as Color) : Theme.of(context).colorScheme.primary;
    final iconBgColor = isDark 
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
        : Theme.of(context).colorScheme.primary.withOpacity(0.1);
        
    final cardColor = Theme.of(context).cardColor;
    
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? (isExpanded ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.03))
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: isDark
              ? [] // No escuro, mantém sutil
              : [
                  // No claro, efeito 3D em destaque
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.8),
                    blurRadius: 10,
                    offset: const Offset(-2, -2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      item['icon'] as IconData,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    item['title'] as String,
                    style: GoogleFonts.outfit(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 24),
              ...List.generate((item['steps'] as List<String>).length, (i) {
                final step = (item['steps'] as List<String>)[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i + 1}.',
                        style: GoogleFonts.outfit(
                          color: iconColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: GoogleFonts.outfit(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: item['onTap'] as VoidCallback,
                  style: TextButton.styleFrom(
                    backgroundColor: isDark 
                        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.05)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.08),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item['actionText'] as String,
                        style: GoogleFonts.outfit(
                          color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: isDark ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
