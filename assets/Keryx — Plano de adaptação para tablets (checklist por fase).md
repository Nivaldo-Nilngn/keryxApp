# Keryx — Plano de adaptação para tablets

Checklist de implementação por fase. Regra de ouro: **cada fase termina com o celular funcionando exatamente como antes.**

## Visão geral

- **Objetivo:** aproveitar telas grandes com painel duplo (Bíblia + Hub de Estudos) e um chat ancorado no texto, estilo NotebookLM.
- **Bônus:** a mesma base deixa o app pronto para Web, Windows e macOS.
- **Dependência do Worker:** o chat só fica estável com o Worker novo no ar (veja a Fase 0).

### Faixas de largura (medidas com `LayoutBuilder`, não com `MediaQuery`)

| Faixa | Largura | Layout |
| --- | --- | --- |
| Compacta | menor que 600 | Atual: uma coluna, `BottomNavigationBar`, hub em BottomSheet |
| Média | 600 a 840 | Uma coluna de leitura, `NavigationRail` compacto, hub em BottomSheet ou painel recolhível |
| Expandida | 840 ou mais | Painel duplo, `NavigationRail` estendido |

Larguras mínimas na faixa expandida: leitura cerca de 420 px; hub entre 360 e 480 px. Em vez de 60/40 fixo, use divisor arrastável e botão para recolher o hub.

---

## Fase 0 — Pré-requisito: Worker da IA estável

- [ ] Substituir `worker/index.js` pela versão correta (sem `\${` escapado)
- [ ] Conferir que não sobrou escape indevido: o `grep` por `\${` no arquivo não deve achar nada
- [ ] Rodar `node --check worker/index.js`
- [ ] Conferir que o `wrangler.toml` tem os dois KV (`PDF_CATALOG` e `RATE_KV`), os três D1 e o binding `AI`
- [ ] Fazer o deploy e rodar o `curl` de teste: a resposta deve trazer o campo `model`
- [ ] Ajustar `GROQ_MODELS`, `GOOGLE_MODELS`, `MISTRAL_MODELS` e `ZHIPU_MODELS` conforme as listas reais das APIs
- [ ] Trocar as chaves que foram expostas e tirar do `.env` do app tudo que não seja o `APP_TOKEN` e a configuração pública do Firebase

**Pronto quando:** o app recebe resposta da IA e o campo `provider`/`model` aparece.

---

## Fase 1 — Estado da seleção fora da tela

Tirar do widget o estado de leitura, para o BottomSheet e o painel lerem a mesma fonte.

- [ ] Criar um provider (Riverpod) com: livro, capítulo, versão da Bíblia, versículos selecionados e intervalo (início/fim)
- [ ] Migrar `reading_screen.dart` para ler e escrever nesse provider
- [ ] Garantir que girar a tela ou redimensionar a janela não perde a seleção
- [ ] Teste: selecionar versículos, girar o aparelho, a seleção continua

**Pronto quando:** nenhuma mudança visual, e a seleção sobrevive a rebuilds.

---

## Fase 2 — Utilitário de responsividade

- [ ] Criar `ResponsiveLayout` com as três faixas (compacta, média, expandida) usando `LayoutBuilder`
- [ ] Expor um enum de faixa e helpers (`isExpanded`, `isMedium`)
- [ ] Constantes de larguras mínimas e máximas num único arquivo
- [ ] Teste de widget para cada faixa (390, 720 e 1100 px)

**Pronto quando:** dá para pedir a faixa atual em qualquer tela.

---

## Fase 3 — Extrair o `StudyHubPanel`

- [ ] Extrair o conteúdo do `_CommentarySheet` para o widget `StudyHubPanel`
- [ ] Ele recebe a seleção do provider, não parâmetros soltos
- [ ] Seções: cabeçalho (versículos selecionados), análise (exegese, comentários, Strong, dicionário) e, depois, chat
- [ ] No celular, continua abrindo dentro do BottomSheet atual
- [ ] Carregamento automático só do que é barato (comentários, Strong, dicionário), com debounce de cerca de 400 ms
- [ ] Cache por (versão, livro, capítulo, intervalo)
- [ ] A exegese por IA é sob demanda: botão "Analisar" e resultado em cache

**Pronto quando:** o celular está idêntico ao anterior, agora usando o novo widget.

---

## Fase 4 — Painel duplo na faixa expandida

- [ ] `ResponsiveSplitView`: dois painéis lado a lado quando houver espaço; empilhado (BottomSheet) quando não houver
- [ ] Painel esquerdo: texto bíblico; painel direito: `StudyHubPanel`
- [ ] Divisor arrastável com limites mínimos e máximos
- [ ] Botão para recolher e expandir o hub
- [ ] O hub atualiza ao mudar a seleção, sem animação pesada
- [ ] Persistir a largura escolhida e o estado recolhido
- [ ] Teste: 1100 px mostra o painel duplo e 390 px mostra o BottomSheet

**Pronto quando:** no tablet dá para ler à esquerda e estudar à direita sem fechar nada.

---

## Fase 5 — Navegação adaptativa

- [ ] Definir a lista de destinos uma única vez (ícone, rótulo, rota)
- [ ] Compacta: `BottomNavigationBar`; média: `NavigationRail` compacto; expandida: `NavigationRail` estendido
- [ ] Preservar o estado de cada aba (por exemplo `StatefulShellRoute`), para não perder a posição de leitura ao trocar de aba
- [ ] Testar retorno de abas, botão voltar do Android e mudança de faixa com o app aberto

**Pronto quando:** a troca de faixa não reinicia nenhuma tela.

---

## Fase 6 — Chat ancorado no `StudyHubPanel`

- [ ] Interface: lista de mensagens, campo de texto, botão enviar e botão "Parar"
- [ ] Streaming da resposta (`stream: true`)
- [ ] Enviar em cada pergunta: `book_id`, `chapter`, `verse` e `verse_end`, além do texto bíblico local com o marcador `TEXTO BÍBLICO`
- [ ] Ler os headers `X-Sources-Used` e `X-Provider` e mostrar abaixo da resposta as fontes usadas
- [ ] Guardar a conversa completa no app (por passagem ou por estudo) e enviar ao Worker só o trecho recente; o Worker aceita as últimas 12 mensagens de até 2000 caracteres
- [ ] Botão "Novo assunto" para limpar o contexto
- [ ] Tratar os erros do Worker: `401` (token), `429` (limite), `502` (todos os provedores falharam), com mensagem amigável e botão "Tentar de novo"
- [ ] No celular, o chat aparece como aba do BottomSheet

**Pronto quando:** dá para conversar sobre o versículo selecionado e ver de quais comentários vieram as ideias.

---

## Fase 7 — Teclado, mouse e acabamento

- [ ] Seleção de vários versículos com shift+clique ou arrastar
- [ ] Atalhos: setas para mudar de capítulo, Ctrl+Enter para enviar no chat, Esc para recolher o hub
- [ ] `hover` nos versículos que têm comentário
- [ ] Foco no campo do chat sem cobrir o texto bíblico quando o teclado abrir
- [ ] Revisar contraste, tamanhos de toque e fonte do sistema aumentada
- [ ] Testar em Web, Windows e macOS, se for lançar nessas plataformas

---

## Testes de aceitação (rodar ao fim de cada fase)

- [ ] Larguras 390, 720 e 1100 px, em retrato e paisagem
- [ ] Fonte do sistema no tamanho máximo
- [ ] Seleção, aba e posição de leitura preservadas ao girar ou redimensionar
- [ ] Offline: a leitura funciona com o SQLite local; a IA mostra erro amigável
- [ ] Limite de 20 pedidos por minuto do Worker não é estourado ao trocar rápido de versículo

## Decisões em aberto

- [ ] O app roda só em Android, ou também em Web/Desktop? (muda a prioridade da Fase 7)
- [ ] A conversa do chat fica só no aparelho ou sincroniza na conta (Firestore)?
- [ ] O hub abre sozinho ao selecionar um versículo, ou só quando o usuário tocar em um botão?

## Riscos e cuidados

- **Estado preso ao widget:** é o maior risco de retrabalho; por isso a Fase 1 vem antes de qualquer layout.
- **Gasto de IA:** chamadas automáticas a cada toque estouram cota e limite; mantenha só as consultas locais e do banco automáticas.
- **Segurança:** chaves de IA ficam só nos secrets do Worker; o app carrega apenas o `APP_TOKEN` e a configuração pública do Firebase.
- **Worker alterado por ferramenta externa:** confira sempre o arquivo antes do deploy (sintaxe e escapes).

---

## Fase Extra — Correções e QA (10 Problemas Mapeados)

**Fase QA 1: Bíblia (Problemas 9, 10 e 11)**
- [x] Ajustar o corte do scroll no seletor de capítulos na versão mobile (Problema 9).
- [x] Desligar o áudio do TTS ao dar dispose ou criar um mini-player flutuante global (Problema 10).
- [x] Dar funcionalidade ao botão azul "Versículos" (Problema 11).

**Fase QA 2: Fórum e Anotações (Problemas 5, 6, 7 e 8)**
- [x] Corrigir o layout desktop renderizando incorretamente no celular na criação de Tópicos (Problema 7) e Notas (Problema 8).
- [x] Corrigir o indicador visual da Navbar marcando "Anotações" quando dentro do Fórum (Problema 5).
- [x] Adicionar botão de excluir comentários/tópicos próprios no Fórum (Problema 6).

**Fase QA 3: Navegação Global e Primeiros Passos (Problemas 1, 2 e 3)**
- [x] Revisar responsividade e proporções da `CustomBottomNav` (Problema 1).
- [x] Ajustar o botão de voltar nativo do Android (`PopScope`) para obedecer a árvore hierárquica (Problema 2).
- [x] Tornar o botão/guia "Primeiros Passos" interativo e clicável (Problema 3).
