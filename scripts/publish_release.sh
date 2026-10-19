#!/usr/bin/env bash
set -e

VERSION=${1:-"v1.0.0"}
APK_PATH="build/app/outputs/flutter-apk/keryxApp.apk"

if [ ! -f "$APK_PATH" ]; then
  if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp -v "build/app/outputs/flutter-apk/app-release.apk" "$APK_PATH"
  else
    echo "❌ APK não encontrado em $APK_PATH. Rode ./scripts/build_release.sh primeiro."
    exit 1
  fi
fi

echo "🚀 Publicando release $VERSION no GitHub com $APK_PATH..."
gh release create "$VERSION" "$APK_PATH" --title "Keryx App $VERSION" --notes "Lançamento do KeryxApp $VERSION (APK: keryxApp.apk)"
echo "✅ Release $VERSION publicada com sucesso no GitHub com keryxApp.apk!"
