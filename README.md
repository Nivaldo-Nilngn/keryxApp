# KeryxApp 📖

Um aplicativo de estudo e leitura bíblica completo, focado em entregar uma experiência moderna, elegante e rica em recursos para aprofundamento teológico e devocional.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)

## ✨ Funcionalidades Principais

- **Leitura Bíblica Avançada**: Suporte a múltiplas versões e traduções com troca rápida.
- **Comentários Bíblicos Integrados**: Estude os versículos lado a lado com comentários de grandes teólogos, divididos por blocos e capítulos (Comentários Expositivos, Cultura e História, etc.).
- **Dicionários Teológicos**: Acesse definições ricas de termos, personagens e contextos teológicos.
- **Sistema de Anotações Inteligente**:
  - Crie notas pessoais atreladas a versículos específicos ou blocos de comentários.
  - Suporte a inteligência artificial para resumos e notas geradas.
  - Notas públicas e privadas.
- **Loja Integrada (Store)**: Faça o download de dezenas de módulos gratuitos (Bíblias, Comentários, Dicionários e Fontes personalizadas) hospedados na nuvem.
- **Design Premium**: Interface modo escuro super agradável com destaques e micro-animações, focado em uma UX limpa para leitura prolongada.

## 🛠️ Tecnologias Utilizadas

- **Flutter / Dart**: Framework principal para construção da interface multiplataforma.
- **Riverpod**: Gerenciamento de estado reativo e injeção de dependências.
- **SQLite**: Armazenamento local rápido e indexado para os módulos MyBible (.bbl.mybible, .cmt.mybible, .dct.mybible).
- **GitHub Releases API**: Hospedagem global e gratuita dos módulos de expansão (Bíblias, Dicionários e Comentários).

## 🚀 Como Executar o Projeto

1. Clone o repositório:
   ```bash
   git clone https://github.com/Nivaldo-Nilngn/KeryxApp.git
   ```
2. Instale as dependências:
   ```bash
   cd KeryxApp
   flutter pub get
   ```
3. Execute o aplicativo (Dispositivo físico, emulador ou web):
   ```bash
   flutter run
   ```

## 📚 Como adicionar Módulos (Bibliotecas)
Os módulos (bíblias, comentários) são baixados dinamicamente pela **Loja (Store)** do aplicativo, conectando-se diretamente aos releases oficiais do GitHub. Basta abrir a página da Loja dentro do aplicativo e tocar em baixar.

---
Feito com ❤️ para o Reino.
