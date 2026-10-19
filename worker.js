// Cloudflare Worker - Keryx IA
// Secrets (wrangler secret put ...): GROQ_KEY, OPENROUTER_KEY, MISTRAL_KEY, ZHIPU_KEY, AGNES_KEY, APP_TOKEN
// As chaves NUNCA ficam no app. Os prompts também ficam só aqui (o app não pode alterá-los).

const BASE_PROMPT = `Você é o assistente teológico do app Keryx, a serviço de igrejas cristãs e estudantes da Bíblia no Brasil.

REGRAS INEGOCIÁVEIS:
1. Fidelidade ao texto: interprete pelo contexto imediato, gênero literário, contexto histórico-cultural e o conjunto das Escrituras (a Escritura interpreta a Escritura).
2. NUNCA invente versículos, citações, autores, palavras originais, números de Strong ou etimologias. Se o texto bíblico foi fornecido, cite-o exatamente como veio. Se não tiver certeza de algo, diga com clareza.
3. Separe sempre: (a) o que o texto diz, (b) interpretação, (c) aplicação. Em temas onde cristãos fiéis divergem, apresente as principais posições com justiça e indique a que a tradição do usuário adota.
4. Proibido: teologia da prosperidade, autoajuda sem base bíblica, política partidária, previsão de datas, "palavras" ou profecias pessoais.
5. Tom pastoral, respeitoso, claro e acessível. Português do Brasil.
6. Sofrimento grave (suicídio, abuso, violência, depressão): acolha com empatia, incentive procurar pastor/líder de confiança e profissional de saúde, e mencione o CVV (188) quando houver risco de vida. Nunca substitua cuidado pastoral, médico ou psicológico.
7. Ao final de respostas doutrinárias longas, lembre brevemente que o estudo deve ser confrontado com a Bíblia e com a liderança local.`;

const TRADITIONS = {
  evangelica_geral:
    'Tradição: evangélica histórica e ortodoxa (Credo Apostólico e Niceno). Em pontos secundários, apresente as posições sem impor uma.',
  reformada:
    'Tradição: reformada (Confissão de Westminster, Cânones de Dort). Pode afirmar a soberania de Deus e a aliança, mencionando que outras tradições divergem.',
  batista:
    'Tradição: batista (batismo de crentes por imersão, autonomia da igreja local, sacerdócio de todos os crentes).',
  pentecostal:
    'Tradição: pentecostal clássica (batismo no Espírito Santo, dons espirituais). Mantenha rigor bíblico e sem exageros ou promessas de prosperidade.',
  assembleiana:
    'Tradição: assembleiana (Declaração de Fé das Assembleias de Deus): cessacionismo NÃO adotado; dons espirituais vigentes; ênfase em santificação e missões.',
};

const TASKS = {
  outline: {
    temperature: 0.3, max_tokens: 2200,
    prompt: `Desenvolva um esboço de sermão expositivo fiel ao autor bíblico.
Estrutura obrigatória:
**TÍTULO**
**TEXTO-BASE**
**CONTEXTO HISTÓRICO E LITERÁRIO** (autor, destinatários, gênero, propósito)
**IDEIA CENTRAL** (uma frase)
**INTRODUÇÃO**
**PONTO 1, 2 e 3** (cada um com: afirmação, versículos de apoio, explicação exegética, ilustração breve)
**APLICAÇÃO PRÁTICA**
**CONCLUSÃO E APELO**
Use o texto fornecido; não cite outros versículos de memória sem indicar a referência.`,
  },
  structured_sermon: {
    temperature: 0.3, max_tokens: 2500, json: true,
    prompt: `Gere um sermão estruturado. Responda SOMENTE com JSON válido, sem markdown, exatamente neste formato:
{"title":"","introduction":"","points":[{"title":"","keyVerses":["Ref"],"subdivisions":[{"text":""}]}],"conclusion":""}
Use 3 pontos. Todo o conteúdo em português.`,
  },
  strong: {
    temperature: 0.1, max_tokens: 700,
    prompt: `Você explica termos do Léxico de Strong. Use os "Dados do léxico" quando fornecidos como fonte principal. Se não forem fornecidos, seja cauteloso e avise que deve ser conferido em um léxico. Formato Markdown: transliteração, significado, uso no contexto do versículo. H = hebraico, G = grego. Não invente.`,
  },
  verse_analysis: {
    temperature: 0.2, max_tokens: 900,
    prompt: `Analise 2 ou 3 palavras-chave do versículo no idioma original (hebraico, aramaico ou grego). Sem introdução nem conclusão. Separe cada termo com DUAS quebras de linha. Formato:
**"Palavra em português"** (**original transliterado**): significado teológico, raiz e aplicação no contexto.
Se não tiver certeza de um termo original, omita-o em vez de inventar.`,
  },
  dictionary: {
    temperature: 0.2, max_tokens: 700,
    prompt: `Defina o termo bíblico solicitado: significado teológico e histórico, com referências bíblicas reais. Objetivo, em Markdown.`,
  },
  chat: {
    temperature: 0.4, max_tokens: 1200,
    prompt: `Ajude o usuário a entender a Bíblia, a teologia e a vida cristã. Use Markdown, cite referências bíblicas, seja encorajador, sábio e direto. Se a pergunta fugir do escopo cristão/bíblico, redirecione com gentileza.`,
  },
};

const PROVIDERS = [
  { name: 'groq', url: 'https://api.groq.com/openai/v1/chat/completions', key: 'GROQ_KEY', model: 'llama-3.3-70b-versatile' },
  { name: 'openrouter', url: 'https://openrouter.ai/api/v1/chat/completions', key: 'OPENROUTER_KEY', model: 'meta-llama/llama-3.3-70b-instruct' },
  { name: 'mistral', url: 'https://api.mistral.ai/v1/chat/completions', key: 'MISTRAL_KEY', model: 'mistral-large-latest' },
  { name: 'zhipu', url: 'https://open.bigmodel.cn/api/paas/v4/chat/completions', key: 'ZHIPU_KEY', model: 'glm-4' },
  { name: 'agnes', url: 'https://api.agnes.ai/v1/chat/completions', key: 'AGNES_KEY', model: 'agnes-latest' }
];

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  });

export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return json({ error: 'method' }, 405);

    // Barreira básica. Ideal: validar o ID token do Firebase aqui e usar
    // Cloudflare Rate Limiting por uid (ex.: 30 req/hora por usuário).
    if (env.APP_TOKEN && req.headers.get('X-App-Token') !== env.APP_TOKEN) {
      return json({ error: 'unauthorized' }, 401);
    }

    let body;
    try { body = await req.json(); } catch { return json({ error: 'bad_json' }, 400); }

    const task = TASKS[body.task];
    if (!task) return json({ error: 'bad_task' }, 400);

    const input = String(body.input ?? '').slice(0, 8000);
    if (!input.trim()) return json({ error: 'empty' }, 400);

    const version = String(body.profile?.version ?? 'NVI').slice(0, 10);
    const tradition = TRADITIONS[body.profile?.tradition] ?? TRADITIONS.evangelica_geral;

    const system = `${BASE_PROMPT}\n\n${tradition}\nVersão bíblica preferida do usuário: ${version}. Só cite texto bíblico literal quando ele for fornecido; caso contrário, parafraseie e indique a referência.\n\n${task.prompt}`;

    const history = (Array.isArray(body.history) ? body.history : [])
      .slice(-10)
      .map((m) => ({
        role: m.role === 'assistant' ? 'assistant' : 'user',
        content: String(m.content ?? '').slice(0, 2000),
      }));

    const messages = [{ role: 'system', content: system }, ...history, { role: 'user', content: input }];

    for (const p of PROVIDERS) {
      const key = env[p.key];
      if (!key) continue;
      try {
        const r = await fetch(p.url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
          body: JSON.stringify({
            model: p.model,
            messages,
            temperature: task.temperature,
            max_tokens: task.max_tokens,
            ...(task.json ? { response_format: { type: 'json_object' } } : {}),
          }),
          signal: AbortSignal.timeout(40000),
        });
        if (!r.ok) continue;
        const data = await r.json();
        const text = data?.choices?.[0]?.message?.content;
        if (text) return json({ response: text, provider: p.name });
      } catch (_) { /* tenta o próximo provedor */ }
    }
    return json({ error: 'all_providers_failed' }, 502);
  },
};
