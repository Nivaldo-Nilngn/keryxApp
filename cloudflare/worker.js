/**
 * Cloudflare Worker: Gerenciador de Versões e Atualizações do KeryxApp
 * 
 * Como usar:
 * 1. Acesse o painel da Cloudflare (dash.cloudflare.com)
 * 2. Vá em 'Workers & Pages' > 'Create Application' > 'Create Worker'
 * 3. Cole o código deste arquivo e clique em 'Deploy'
 * 4. Copie a URL do seu Worker (ex: https://keryx-version.sua-conta.workers.dev)
 * 5. Coloque essa URL no seu arquivo .env:
 *    CLOUDFLARE_VERSION_URL=https://keryx-version.sua-conta.workers.dev
 */

const APP_VERSION_CONFIG = {
  latest_version: 2, // Número de build incremental (ex: 1, 2, 3...)
  version_name: "1.0.1", // Versão semântica visível ao usuário
  release_date: "2026-10-19",
  download_url: "https://github.com/Nivaldo-Nilngn/keryxApp/releases/latest/download/app-release.apk",
  ios_url: "https://bibliapeniel-nilngn.firebaseapp.com",
  release_notes: "Atualização com suporte completo a PWA para iPhone e melhorias de desempenho.",
  force_update: false,
  min_version: 1
};

export default {
  async fetch(request, env, ctx) {
    // Configuração de cabeçalhos CORS para permitir requisições do Flutter Web, Android e iOS
    const headers = {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, User-Agent",
      // Sem cache para garantir que novas versões apareçam imediatamente
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0",
      "Pragma": "no-cache",
      "Expires": "0"
    };

    // Resposta para pre-flight OPTIONS
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers });
    }

    // Se você configurar uma variável de ambiente ou KV no Cloudflare, ela pode sobrescrever o objeto acima
    let config = APP_VERSION_CONFIG;
    if (env && env.VERSION_CONFIG) {
      try {
        config = JSON.parse(env.VERSION_CONFIG);
      } catch (e) {
        // Usa o padrão se o parse falhar
      }
    }

    return new Response(JSON.stringify(config, null, 2), {
      status: 200,
      headers
    });
  }
};
