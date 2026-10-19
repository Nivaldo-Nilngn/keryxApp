/**
 * Cloudflare Worker – Telegram Proxy para Flutter Web (Keryx App)
 *
 * Resolve CORS ao acessar a API do Telegram a partir do browser.
 * O BOT_TOKEN é armazenado como Secret no Cloudflare (nunca exposto no app).
 *
 * Rotas:
 *   POST /telegram/getFile    → { file_id: "..." }  → retorna file_path do Telegram
 *   GET  /telegram/download   → ?path=documents/... → faz streaming do arquivo
 *
 * Deploy:
 *   cd telegram-proxy
 *   npx wrangler secret put BOT_TOKEN   # cola o token quando solicitado
 *   npx wrangler deploy
 */

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, X-App-Token',
  'Access-Control-Max-Age': '86400',
};

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS_HEADERS },
  });

export default {
  async fetch(req, env) {
    // Preflight CORS
    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(req.url);
    const token = env.BOT_TOKEN;

    if (!token) {
      return json({ error: 'BOT_TOKEN não configurado no Worker' }, 500);
    }

    // ────────────────────────────────────────────────────────────────
    // POST /telegram/getFile  →  obtém o file_path dado um file_id
    // Body: { "file_id": "BQADAQAD..." }
    // ────────────────────────────────────────────────────────────────
    if (url.pathname === '/telegram/getFile' && req.method === 'POST') {
      let body;
      try {
        body = await req.json();
      } catch {
        return json({ error: 'bad_json' }, 400);
      }

      const fileId = body?.file_id;
      if (!fileId) return json({ error: 'file_id obrigatório' }, 400);

      const tgUrl = `https://api.telegram.org/bot${token}/getFile?file_id=${encodeURIComponent(fileId)}`;
      const tgRes = await fetch(tgUrl);
      const tgData = await tgRes.json();

      return json(tgData, tgRes.status);
    }

    // ────────────────────────────────────────────────────────────────
    // GET /telegram/download  →  proxy de streaming do arquivo PDF
    // Query: ?path=documents/file_17
    // ────────────────────────────────────────────────────────────────
    if (url.pathname === '/telegram/download' && req.method === 'GET') {
      const filePath = url.searchParams.get('path');
      if (!filePath) return json({ error: 'parâmetro "path" obrigatório' }, 400);

      const downloadUrl = `https://api.telegram.org/file/bot${token}/${filePath}`;
      const upstream = await fetch(downloadUrl);

      if (!upstream.ok) {
        return json({ error: `Telegram retornou ${upstream.status}` }, upstream.status);
      }

      // Repassa o streaming com os headers CORS adicionados
      const responseHeaders = new Headers(upstream.headers);
      for (const [k, v] of Object.entries(CORS_HEADERS)) {
        responseHeaders.set(k, v);
      }

      return new Response(upstream.body, {
        status: upstream.status,
        headers: responseHeaders,
      });
    }

    // ────────────────────────────────────────────────────────────────
    // GET /devocional  →  proxy para o devocional diário da bibliaonline
    // ────────────────────────────────────────────────────────────────
    if (url.pathname === '/devocional' && req.method === 'GET') {
      const devocionalUrl = 'https://www.bibliaonline.com.br/devocional-diario?b=acf';
      
      const upstream = await fetch(devocionalUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        }
      });

      const responseHeaders = new Headers();
      for (const [k, v] of Object.entries(CORS_HEADERS)) {
        responseHeaders.set(k, v);
      }
      // Content type
      responseHeaders.set('Content-Type', upstream.headers.get('content-type') || 'text/html');

      return new Response(upstream.body, {
        status: upstream.status,
        headers: responseHeaders,
      });
    }

    return json({ error: 'rota não encontrada', path: url.pathname }, 404);
  },
};
