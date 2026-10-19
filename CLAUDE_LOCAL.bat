@echo off
title Claude Code Local - MODO INTELIGENCIA (14B)
echo ==========================================
echo INICIANDO AMBIENTE TURBO (OLLAMA + CLAUDE)
echo ==========================================

:: 1. Define as variaveis necessarias
:: ANTHROPIC_API_KEY deve estar definida como variável de ambiente
:: ou pode ser colocada no arquivo .env
if not defined ANTHROPIC_API_KEY (
    echo ERRO: ANTHROPIC_API_KEY nao definida!
    echo Defina a variavel de ambiente ANTHROPIC_API_KEY ou adicione no .env
    pause
    exit /b 1
)
set ANTHROPIC_BASE_URL=http://127.0.0.1:11435
set CLAUDE_CODE_SKIP_BILLING=true

:: 2. Inicia o Tradutor em uma janela separada e minimizada
echo [1/2] Iniciando o Tradutor...
start /min node C:\Users\nivaldo\Desktop\Biblia\proxy.js

:: 3. Aguarda 2 segundos para o tradutor subir
timeout /t 2 >nul

:: 4. Abre o Claude
echo [2/2] Abrindo o Claude com Cérebro 14B...
echo --------------------------------------------------
echo COPIE E COLE PARA MUDAR O MODELO NO CHAT:
echo --------------------------------------------------
echo [RAPIDO]      /model qwen2.5-coder:1.5b
echo [EQUILIBRADO] /model qwen2.5-coder:7b
echo [INTELIGENTE] /model qwen2.5-coder:14b
echo [GRANDE MEM]  /model claude-local
echo --------------------------------------------------
echo DICA: O modelo 14B pode levar 30-60s para carregar.
echo --------------------------------------------------

claude --model qwen2.5-coder:14b --dangerously-skip-permissions

:: 5. Quando o Claude fechar, mata o tradutor
echo Encerrando processos locais...
taskkill /f /im node.exe >nul 2>&1
exit
