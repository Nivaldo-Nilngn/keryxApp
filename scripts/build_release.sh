#!/usr/bin/env bash
set -e

echo "🚀 Iniciando build do APK Release para KeryxApp..."
flutter build apk --release

OUTPUT_DIR="build/app/outputs/flutter-apk"

# Garante que o arquivo keryxApp.apk seja sempre atualizado com o build mais recente
if [ -f "$OUTPUT_DIR/app-release.apk" ]; then
  cp -fv "$OUTPUT_DIR/app-release.apk" "$OUTPUT_DIR/keryxApp.apk"
  echo "✅ APK copiado/atualizado com sucesso: $OUTPUT_DIR/keryxApp.apk"
elif [ -f "$OUTPUT_DIR/keryxApp.apk" ]; then
  echo "✅ APK encontrado: $OUTPUT_DIR/keryxApp.apk"
else
  echo "❌ Erro: nenhum APK encontrado em $OUTPUT_DIR"
  exit 1
fi

ls -lh "$OUTPUT_DIR/keryxApp.apk"
