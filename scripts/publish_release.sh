#!/usr/bin/env bash
set -e

# ==============================================================================
# Script seguro para publicação de atualizações do KeryxApp no Cloudflare Worker
# Uso:
#   VERSION_ADMIN_TOKEN="seu_token_secreto" ./scripts/publish_release.sh
#   Ou passe os parâmetros interativamente / via variáveis de ambiente.
# ==============================================================================

WORKER_URL="${CLOUDFLARE_VERSION_URL:-https://keryx-version.nivaldo-nilngn.workers.dev}"
TOKEN="${VERSION_ADMIN_TOKEN:-$APP_TOKEN}"

if [ -z "$TOKEN" ]; then
  echo "❌ ERRO: A variável de ambiente VERSION_ADMIN_TOKEN não foi informada!"
  echo "Por favor, execute: VERSION_ADMIN_TOKEN=\"seu_secret\" $0"
  exit 1
fi

VERSION_NAME="${1:-2.0.2}"
BUILD_NUMBER="${2:-11}"
DOWNLOAD_URL="${3:-https://github.com/Nivaldo-Nilngn/keryxApp/releases/download/v${VERSION_NAME}/keryxApp.apk}"
IOS_URL="${4:-https://keryxapp.pages.dev}"
RELEASE_NOTES="${5:-Atualizações de segurança, melhorias na instalação e correções no download.}"
SHA256_HASH="${6:-}"

# Se o APK existir localmente e o hash não tiver sido informado, calcula o sha256 automaticamente
APK_LOCAL="build/app/outputs/flutter-apk/keryxApp.apk"
if [ -z "$SHA256_HASH" ] && [ -f "$APK_LOCAL" ]; then
  echo "📦 Calculando SHA-256 do APK local ($APK_LOCAL)..."
  SHA256_HASH=$(sha256sum "$APK_LOCAL" | awk '{print $1}')
  echo "   SHA-256 calculado: $SHA256_HASH"
fi

echo "🚀 Publicando versão no Cloudflare Worker ($WORKER_URL)..."
echo "   Versão: $VERSION_NAME (Build $BUILD_NUMBER)"
echo "   Download APK: $DOWNLOAD_URL"
echo "   iOS / Web: $IOS_URL"
if [ -n "$SHA256_HASH" ]; then
  echo "   SHA-256: $SHA256_HASH"
fi

PAYLOAD=$(cat <<EOF
{
  "latest_version": $BUILD_NUMBER,
  "version_name": "$VERSION_NAME",
  "download_url": "$DOWNLOAD_URL",
  "ios_url": "$IOS_URL",
  "release_notes": "$RELEASE_NOTES",
  "force_update": false,
  "min_version": 1,
  "sha256": $(if [ -n "$SHA256_HASH" ]; then echo "\"$SHA256_HASH\""; else echo "null"; fi),
  "release_date": "$(date -u +%Y-%m-%d)"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WORKER_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-app-token: $TOKEN" \
  -d "$PAYLOAD")

HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "✅ Sucesso! Versão publicada com sucesso no Cloudflare:"
  echo "$BODY"
else
  echo "❌ Falha ao publicar versão (HTTP $HTTP_STATUS):"
  echo "$BODY"
  exit 1
fi
