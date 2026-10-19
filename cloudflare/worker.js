/**
 * Cloudflare Worker: Gerenciador de Versões e Atualizações do KeryxApp
 * Com persistência KV e endpoint de atualização para o Painel Admin
 */

const DEFAULT_CONFIG = {
  latest_version: 1,
  version_name: "1.0.0",
  release_date: "2026-10-19",
  download_url: "https://github.com/Nivaldo-Nilngn/keryxApp/releases/latest/download/keryxApp.apk",
  ios_url: "https://keryxapp.pages.dev",
  release_notes: "Lançamento inicial do KeryxApp com suporte a PWA para iPhone.",
  force_update: false,
  min_version: 1
};

export default {
  async fetch(request, env, ctx) {
    const corsHeaders = {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization, x-app-token",
      "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0",
      "Pragma": "no-cache",
      "Expires": "0"
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    // ── POST: Atualização da versão pelo Painel Administrativo ───────────────
    if (request.method === "POST") {
      try {
        const authHeader = request.headers.get("Authorization") || "";
        const tokenHeader = request.headers.get("x-app-token") || "";
        const expectedToken = env.APP_TOKEN || "KeryxAppToken2026";

        const bearerMatch = authHeader.replace(/^Bearer\s+/i, "").trim();
        const isValid = bearerMatch === expectedToken || tokenHeader === expectedToken;

        if (!isValid) {
          return new Response(
            JSON.stringify({ error: "Não autorizado. Token de admin inválido." }),
            { status: 401, headers: corsHeaders }
          );
        }

        const body = await request.json();
        if (!body || typeof body !== "object") {
          return new Response(
            JSON.stringify({ error: "Payload JSON inválido." }),
            { status: 400, headers: corsHeaders }
          );
        }

        // Validação e mesclagem com dados padrão
        const updatedConfig = {
          latest_version: Number(body.latest_version) || 1,
          version_name: String(body.version_name || "1.0.0").trim(),
          release_date: String(body.release_date || new Date().toISOString().split("T")[0]),
          download_url: String(body.download_url || DEFAULT_CONFIG.download_url).trim(),
          ios_url: String(body.ios_url || "https://keryxapp.pages.dev").trim(),
          release_notes: String(body.release_notes || "").trim(),
          force_update: Boolean(body.force_update),
          min_version: Number(body.min_version) || 1
        };

        if (env.VERSION_KV) {
          await env.VERSION_KV.put("version_config", JSON.stringify(updatedConfig));
        }

        return new Response(
          JSON.stringify({
            success: true,
            message: "Versão atualizada com sucesso no Cloudflare!",
            data: updatedConfig
          }),
          { status: 200, headers: corsHeaders }
        );
      } catch (err) {
        return new Response(
          JSON.stringify({ error: "Erro ao processar requisição: " + err.message }),
          { status: 500, headers: corsHeaders }
        );
      }
    }

    // ── GET: Consulta da versão atual para os clientes ──────────────────────
    let config = DEFAULT_CONFIG;
    if (env.VERSION_KV) {
      try {
        const stored = await env.VERSION_KV.get("version_config", "json");
        if (stored) {
          config = stored;
        }
      } catch (e) {
        // Fallback silencioso para config padrão
      }
    }

    return new Response(JSON.stringify(config, null, 2), {
      status: 200,
      headers: corsHeaders
    });
  }
};
