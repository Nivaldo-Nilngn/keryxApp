#!/bin/bash
# Este script clona e compila o TDLib (libtdjson.so) para Android (arm64-v8a).
# ATENÇÃO: Você precisa ter o Android NDK e o CMake instalados no seu ambiente.

echo "Preparando o ambiente para compilar o TDLib (Telegram)..."
echo "Isso pode demorar de 20 a 60 minutos dependendo do computador."

# Define a versão do NDK. Se você usa outra versão, mude aqui:
NDK_VERSION="25.1.8937393"

if [ -z "$ANDROID_HOME" ]; then
    # Tenta descobrir o caminho padrão no Linux
    export ANDROID_HOME="$HOME/Android/Sdk"
fi

NDK_PATH="$ANDROID_HOME/ndk/$NDK_VERSION"

if [ ! -d "$NDK_PATH" ]; then
    echo "ERRO: NDK não encontrado em $NDK_PATH."
    echo "Por favor, abra o Android Studio -> SDK Manager -> SDK Tools -> Instale o NDK (Side by side) versão 25.1.8937393."
    exit 1
fi

echo "NDK encontrado em: $NDK_PATH"

# 1. Baixando o código fonte do TDLib
if [ ! -d "td" ]; then
    git clone https://github.com/tdlib/td.git
fi
cd td

# Checkout para a versão 1.8.0 (que costuma ser estável para o wrapper 1.6.0 do Flutter)
git checkout v1.8.0

# 2. Configurando a compilação para Android (ARM64)
rm -rf build-android-arm64
mkdir build-android-arm64
cd build-android-arm64

echo "Configurando o CMake para arm64-v8a..."
cmake -DCMAKE_TOOLCHAIN_FILE="${NDK_PATH}/build/cmake/android.toolchain.cmake" \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-21 \
      -DANDROID_STL=c++_static \
      -DCMAKE_BUILD_TYPE=Release \
      -DTD_ENABLE_JNI=ON \
      ..

# 3. Compilando o projeto
echo "Compilando... Pode ir tomar um café, isso vai demorar!"
cmake --build . --target tdjson -j$(nproc)

echo "Compilação concluída!"

# 4. Copiando para o diretório do KeryxApp
APP_JNI_DIR="../../android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$APP_JNI_DIR"
cp libtdjson.so "$APP_JNI_DIR/"

echo "SUCESSO! O arquivo libtdjson.so foi copiado para $APP_JNI_DIR"
