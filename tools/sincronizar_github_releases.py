#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Sincronização e Upload para o GitHub Releases
Repositório: Nivaldo-Nilngn/Loja-Keryx
Faz upload dos 425 arquivos otimizados para as releases correspondentes:
- Biblias
- Comentarios
- Dicionarios
- Livros

Suporta:
- Limpeza opcional de releases anteriores (--limpar)
- Retomada inteligente (não reenvia arquivos que já estão no GitHub com o mesmo tamanho)
- Uso via GitHub Token (GITHUB_TOKEN ou argumento --token) ou via gh cli
"""

import os
import sys
import re
import json
import argparse
import unicodedata
import urllib.request
import urllib.error

REPO = "Nivaldo-Nilngn/Loja-Keryx"
API_BASE = f"https://api.github.com/repos/{REPO}"
UPLOADS_BASE = f"https://uploads.github.com/repos/{REPO}"

BASE_DIR = '/home/nivaldo/Área de trabalho/B2_Downloads'
PASTAS = {
    'Biblias': os.path.join(BASE_DIR, 'Biblias'),
    'Comentarios': os.path.join(BASE_DIR, 'Comentarios'),
    'Dicionarios': os.path.join(BASE_DIR, 'Dicionarios'),
    'Livros': os.path.join(BASE_DIR, 'Livros'),
}

def to_github_asset_name(filename):
    nfkd = unicodedata.normalize('NFKD', filename)
    ascii_str = ''.join([c for c in nfkd if not unicodedata.combining(c)])
    clean = re.sub(r'\s+', '.', ascii_str.strip())
    clean = re.sub(r'[,()\[\]\'\"~^]', '', clean)
    clean = re.sub(r'\.+', '.', clean)
    return clean

class GitHubClient:
    def __init__(self, token):
        self.token = token
        self.headers = {
            "Authorization": f"token {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "Keryx-Sync/1.0"
        }

    def get_releases(self):
        req = urllib.request.Request(f"{API_BASE}/releases", headers=self.headers)
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            print(f"❌ Erro ao listar releases: {e.code} - {e.read().decode('utf-8')}")
            return []

    def delete_release(self, release_id, tag_name):
        req = urllib.request.Request(f"{API_BASE}/releases/{release_id}", headers=self.headers, method='DELETE')
        try:
            with urllib.request.urlopen(req):
                print(f"  🗑️ Release deletada: {tag_name} (ID: {release_id})")
        except Exception as e:
            print(f"  ⚠️ Falha ao deletar release {tag_name}: {e}")

    def create_release(self, tag_name, name=None, body=""):
        name = name or f"Módulos: {tag_name}"
        data = json.dumps({
            "tag_name": tag_name,
            "name": name,
            "body": body,
            "draft": False,
            "prerelease": False
        }).encode('utf-8')
        req = urllib.request.Request(f"{API_BASE}/releases", data=data, headers=self.headers, method='POST')
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            print(f"❌ Erro ao criar release {tag_name}: {e.code} - {e.read().decode('utf-8')}")
            return None

    def get_release_by_tag(self, tag_name):
        req = urllib.request.Request(f"{API_BASE}/releases/tags/{tag_name}", headers=self.headers)
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            print(f"❌ Erro ao buscar release {tag_name}: {e.code}")
            return None

    def delete_asset(self, asset_id, asset_name):
        req = urllib.request.Request(f"{API_BASE}/releases/assets/{asset_id}", headers=self.headers, method='DELETE')
        try:
            with urllib.request.urlopen(req):
                print(f"    🗑️ Asset antigo removido: {asset_name}")
        except Exception as e:
            print(f"    ⚠️ Falha ao deletar asset {asset_name}: {e}")

    def upload_asset(self, release_id, filepath, asset_name):
        url = f"{UPLOADS_BASE}/releases/{release_id}/assets?name={urllib.parse.quote(asset_name)}"
        size = os.path.getsize(filepath)
        headers = dict(self.headers)
        headers["Content-Type"] = "application/octet-stream"
        headers["Content-Length"] = str(size)

        with open(filepath, 'rb') as f:
            req = urllib.request.Request(url, data=f, headers=headers, method='POST')
            try:
                with urllib.request.urlopen(req) as resp:
                    return json.loads(resp.read().decode('utf-8'))
            except urllib.error.HTTPError as e:
                print(f"    ❌ Erro ao enviar {asset_name}: {e.code} - {e.read().decode('utf-8')}")
                return None

def main():
    parser = argparse.ArgumentParser(description="Upload dos módulos para o GitHub Releases")
    parser.add_argument("--token", help="GitHub Personal Access Token (PAT)")
    parser.add_argument("--limpar", action="store_true", help="Limpa releases anteriores antes de recriar")
    parser.add_argument("--categoria", choices=['Biblias', 'Comentarios', 'Dicionarios', 'Livros', 'Todas'], default='Todas')
    args = parser.parse_args()

    token = args.token or os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if not token:
        print("=" * 70)
        print("🔑 TOKEN DO GITHUB NECESSÁRIO")
        print("=" * 70)
        print("Para enviar arquivos para os Releases do GitHub, forneça seu Token.")
        print("Você pode gerar um token em: https://github.com/settings/tokens")
        print("Permissões necessárias: repo (ou Contents: Read and write)")
        print("\nUso:")
        print("  python3 tools/sincronizar_github_releases.py --token SEU_TOKEN [--limpar]")
        sys.exit(1)

    client = GitHubClient(token)

    print("=" * 70)
    print(f"🚀 SINCRONIZADOR DE RELEASES DO GITHUB: {REPO}")
    print("=" * 70)

    # 1. Se --limpar estiver ativado, deleta as releases de categorias existentes
    if args.limpar:
        print("\n🧹 LIMPEZA DE RELEASES ANTERIORES SOLICITADA...")
        existing_releases = client.get_releases()
        for rel in existing_releases:
            tag = rel.get('tag_name')
            if tag in PASTAS or tag in ['v1.0-conteudos', 'Outros']:
                client.delete_release(rel['id'], tag)

    target_categories = PASTAS.keys() if args.categoria == 'Todas' else [args.categoria]

    total_uploaded = 0
    total_skipped = 0

    for cat in target_categories:
        folder = PASTAS[cat]
        if not os.path.exists(folder):
            print(f"⚠️ Pasta não encontrada: {folder}")
            continue

        files = [
            f for f in os.listdir(folder)
            if os.path.isfile(os.path.join(folder, f))
            and not f.endswith(('-wal', '-shm', '-journal', '.tmp'))
        ]
        files.sort()

        print(f"\n📂 Processando Categoria: {cat} ({len(files)} arquivos)")
        
        # Garante release
        release = client.get_release_by_tag(cat)
        if not release:
            print(f"  ✨ Criando Release '{cat}'...")
            release = client.create_release(cat, name=f"Módulos: {cat}", body=f"Coleção otimizada de módulos {cat} para a Loja Keryx.")
            if not release:
                print(f"  ❌ Não foi possível criar a release '{cat}'. Pulando.")
                continue

        release_id = release['id']
        existing_assets = {a['name']: a for a in release.get('assets', [])}

        for i, fn in enumerate(files, 1):
            filepath = os.path.join(folder, fn)
            filesize = os.path.getsize(filepath)
            asset_name = to_github_asset_name(fn)

            # Verifica se já existe com o mesmo tamanho
            if asset_name in existing_assets:
                remote_size = existing_assets[asset_name].get('size', 0)
                if remote_size == filesize:
                    total_skipped += 1
                    if i % 25 == 0 or i == len(files):
                        print(f"  [{i}/{len(files)}] ⏭️ {asset_name} (já sincronizado no GitHub)")
                    continue
                else:
                    # Tamanho diferente: remove asset antigo para atualizar com o novo
                    client.delete_asset(existing_assets[asset_name]['id'], asset_name)

            sz_mb = round(filesize / (1024 * 1024), 2)
            print(f"  [{i}/{len(files)}] ⬆️ Enviando: {asset_name} ({sz_mb} MB)...")
            res = client.upload_asset(release_id, filepath, asset_name)
            if res:
                total_uploaded += 1
            else:
                print(f"  ⚠️ Falha no envio de: {fn}")

    print("\n" + "=" * 70)
    print("🎉 SINCRONIZAÇÃO COM O GITHUB CONCLUÍDA!")
    print(f"📊 Novos/atualizados: {total_uploaded} | Já em dia: {total_skipped}")
    print("=" * 70)

if __name__ == '__main__':
    main()
