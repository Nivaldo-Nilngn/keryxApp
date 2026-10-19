const http = require('http');

// Se o Claude pedir um modelo que nao existe no Ollama (ex: claude-3-5-sonnet), 
// ele usara este aqui como reserva.
const MODELO_RESERVA = "qwen2.5-coder:1.5b"; 

const server = http.createServer((req, res) => {
  console.log(`\n[${new Date().toLocaleTimeString()}] Chamada recebida.`);
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
      'Access-Control-Allow-Headers': '*',
    });
    res.end();
    return;
  }

  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', async () => {
    try {
      if (!body) return res.end();
      const anthropicReq = JSON.parse(body);
      
      // Inteligencia: Se o modelo solicitado contiver "claude-3" ou "haiku",
      // significa que o Claude esta tentando ir para a nuvem. Forcamos o Reserva.
      // Caso contrario, usamos o que o usuario pediu (qwen, claude-local, etc).
      let modeloParaUsar = anthropicReq.model;
      if (modeloParaUsar.startsWith('claude-3') || modeloParaUsar.includes('haiku') || modeloParaUsar.includes('sonnet')) {
          modeloParaUsar = MODELO_RESERVA;
      }
      
      console.log(`-> Claude pediu: ${anthropicReq.model}`);
      console.log(`-> Ollama vai usar: ${modeloParaUsar}`);
      
      const messages = (anthropicReq.messages || []).map(m => {
        let textContent = "";
        if (Array.isArray(m.content)) {
          textContent = m.content.map(c => c.text || "").join("\n");
        } else {
          textContent = m.content || "";
        }
        return { role: m.role, content: textContent };
      });

      const response = await fetch('http://127.0.0.1:11434/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: modeloParaUsar,
          messages: messages,
          stream: false
        })
      });

      const ollamaRes = await response.json();

      if (ollamaRes.error) {
        throw new Error(ollamaRes.error);
      }

      const responseText = ollamaRes.message ? ollamaRes.message.content : "Sem resposta do local.";

      const anthropicRes = {
        id: `msg_local_${Date.now()}`,
        type: 'message',
        role: 'assistant',
        model: modeloParaUsar,
        content: [{ type: 'text', text: responseText }],
        stop_reason: 'end_turn',
        usage: { input_tokens: 0, output_tokens: 0 }
      };

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(anthropicRes));
      console.log('<- Sucesso!');
    } catch (e) {
      console.error('!! Erro:', e.message);
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        id: `err_${Date.now()}`,
        type: 'message',
        role: 'assistant',
        content: [{ type: 'text', text: "Erro: " + e.message }],
        stop_reason: 'stop_sequence'
      }));
    }
  });
});

server.listen(11435, '0.0.0.0', () => {
  console.log('=========================================');
  console.log('TRADUTOR MULTI-MODELO ATIVO (Porta 11435)');
  console.log('=========================================');
});
