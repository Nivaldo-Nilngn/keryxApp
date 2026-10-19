# Gerenciador de Versões e Atualizações via Cloudflare

Este módulo permite gerenciar e lançar novas versões do aplicativo **KeryxApp** sem depender da Google Play Store ou Apple App Store.

O aplicativo consulta o endpoint do Cloudflare e exibe automaticamente um card de notificação responsivo:
- **No Android:** Notifica sobre a nova versão e permite baixar/instalar o APK com barra de progresso.
- **No iPhone (iOS):** Notifica sobre novidades e orienta a instalar/atualizar o PWA na Tela de Início.

---

## Opção 1: Cloudflare Worker (Recomendada - Mais Fácil e Rápida)

1. Acesse o [Painel da Cloudflare](https://dash.cloudflare.com/) (gratuito).
2. No menu lateral esquerdo, clique em **Workers & Pages** > **Create application** > **Create Worker**.
3. Dê um nome ao seu worker (ex: `keryx-version`) e clique em **Deploy**.
4. Clique em **Edit code** (ou **Quick Edit**).
5. Cole todo o conteúdo do arquivo [`worker.js`](worker.js) e clique em **Deploy**.
6. Pronto! Sua URL será algo como:
   `https://keryx-version.<seu-subdominio>.workers.dev`

---

## Opção 2: Cloudflare Pages (Com arquivo `version.json`)

1. Crie um repositório no GitHub contendo o arquivo [`version.json`](version.json) na raiz ou dentro de uma pasta `public`.
2. No Cloudflare, vá em **Workers & Pages** > **Create application** > aba **Pages** > **Connect to Git**.
3. Selecione o repositório e publique.
4. Sua URL será:
   `https://<seu-projeto>.pages.dev/version.json`

---

## Configuração no Aplicativo Flutter

No arquivo `.env` na raiz do projeto `Biblia`, adicione a variável com a URL do seu Cloudflare:

```env
CLOUDFLARE_VERSION_URL=https://keryx-version.<seu-subdominio>.workers.dev
```

---

## Como Lançar uma Nova Versão

Sempre que você fizer alterações no app:

1. Gere o novo APK:
   ```bash
   flutter build apk --release
   ```
2. Crie uma nova Release no GitHub e faça o upload do arquivo `app-release.apk`.
3. No Cloudflare (no Worker ou no `version.json`), altere:
   ```json
   {
     "latest_version": 3,
     "version_name": "1.0.2",
     "download_url": "https://github.com/<seu-usuario>/<repo>/releases/download/v1.0.2/app-release.apk",
     "release_notes": "Correções e melhorias no leitor de comentários bíblicos."
   }
   ```
4. Salve e clique em **Deploy**. Instantaneamente, todos os usuários que abrirem o aplicativo receberão a notificação de nova versão no topo da tela!
