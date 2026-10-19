#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Geração do Catálogo da Loja Keryx (JSON + SQLite)
Lê as pastas organizadas e otimizadas em B2_Downloads:
- Biblias
- Comentarios
- Dicionarios
- Livros

Gera loja_keryx.json e loja_keryx.db perfeitamente indexados em assets/data/
e em B2_Downloads/
"""

import os
import re
import json
import sqlite3
import unicodedata

BASE_DIR = '/home/nivaldo/Área de trabalho/B2_Downloads'
APP_ASSETS_DIR = '/home/nivaldo/Área de trabalho/Biblia/assets/data'

CATEGORIAS = {
    'Biblias': os.path.join(BASE_DIR, 'Biblias'),
    'Comentarios': os.path.join(BASE_DIR, 'Comentarios'),
    'Dicionarios': os.path.join(BASE_DIR, 'Dicionarios'),
    'Livros': os.path.join(BASE_DIR, 'Livros'),
}

REPO_BASE_URL = 'https://github.com/Nivaldo-Nilngn/Loja-Keryx/releases/download'

def clean_title(filename):
    """Gera um título limpo removendo extensões e formatações brutas."""
    t = filename
    for ext in ['.bbl.mybible', '.cmt.mybible', '.dct.mybible', '.bok.mybible', '.mybible', '.pdf']:
        if t.lower().endswith(ext):
            t = t[:-len(ext)]
            break
    return t.strip()

def to_github_asset_name(filename):
    """
    Converte o nome do arquivo para o formato padrão do GitHub Releases
    (remove acentos, espaços viram pontos, limpa caracteres especiais).
    """
    nfkd = unicodedata.normalize('NFKD', filename)
    ascii_str = ''.join([c for c in nfkd if not unicodedata.combining(c)])
    clean = re.sub(r'\s+', '.', ascii_str.strip())
    clean = re.sub(r'[,()\[\]\'\"~^]', '', clean)
    clean = re.sub(r'\.+', '.', clean)
    return clean

def generate_catalog():
    print("=" * 70)
    print("📦 GERANDO CATÁLOGO OTIMIZADO DA LOJA KERYX (JSON + SQLITE)")
    print("=" * 70)

    items = []
    category_counts = {}

    for cat_name, folder_path in CATEGORIAS.items():
        if not os.path.exists(folder_path):
            print(f"⚠️ Pasta não encontrada: {folder_path}")
            continue

        files = [
            f for f in os.listdir(folder_path)
            if os.path.isfile(os.path.join(folder_path, f))
            and not f.endswith(('-wal', '-shm', '-journal', '.tmp'))
        ]
        files.sort()
        category_counts[cat_name] = len(files)
        print(f"📂 Processando {cat_name}: {len(files)} arquivos...")

        for fn in files:
            full_path = os.path.join(folder_path, fn)
            size_bytes = os.path.getsize(full_path)
            size_mb = round(size_bytes / (1024 * 1024), 2)
            
            asset_name = to_github_asset_name(fn)
            download_url = f"{REPO_BASE_URL}/{cat_name}/{asset_name}"
            
            formato = 'PDF' if fn.lower().endswith('.pdf') else 'MYBIBLE'
            titulo = clean_title(fn)

            item = {
                "id": fn,
                "titulo": titulo,
                "nome_arquivo": fn,
                "tamanho_mb": size_mb,
                "categoria": cat_name,
                "formato": formato,
                "url_image": "",
                "file_id": None,
                "download_url": download_url
            }
            items.append(item)

    # Ordenação alfabética por categoria e título
    items.sort(key=lambda x: (x['categoria'], x['titulo'].lower()))

    print(f"\n📊 Total de itens catalogados: {len(items)}")
    for cat, count in category_counts.items():
        print(f"   • {cat}: {count} itens")

    # 1. Salvar JSON
    json_paths = [
        os.path.join(APP_ASSETS_DIR, 'loja_keryx.json'),
        os.path.join(BASE_DIR, 'loja_keryx.json')
    ]
    for jp in json_paths:
        os.makedirs(os.path.dirname(jp), exist_ok=True)
        with open(jp, 'w', encoding='utf-8') as f:
            json.dump(items, f, ensure_ascii=False, indent=2)
        print(f"✅ JSON salvo: {jp} ({round(os.path.getsize(jp)/1024, 1)} KB)")

    # 2. Salvar e indexar SQLite
    db_paths = [
        os.path.join(APP_ASSETS_DIR, 'loja_keryx.db'),
        os.path.join(BASE_DIR, 'loja_keryx.db')
    ]
    for db_path in db_paths:
        if os.path.exists(db_path):
            try:
                os.remove(db_path)
            except Exception:
                pass

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()
        cur.execute('''
            CREATE TABLE loja (
                id TEXT PRIMARY KEY,
                titulo TEXT,
                nome_arquivo TEXT,
                tamanho_mb REAL,
                categoria TEXT,
                formato TEXT,
                url_image TEXT,
                file_id TEXT,
                download_url TEXT
            )
        ''')

        for it in items:
            cur.execute('''
                INSERT INTO loja (id, titulo, nome_arquivo, tamanho_mb, categoria, formato, url_image, file_id, download_url)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                it['id'],
                it['titulo'],
                it['nome_arquivo'],
                it['tamanho_mb'],
                it['categoria'],
                it['formato'],
                it['url_image'],
                it['file_id'],
                it['download_url']
            ))

        # Índices essenciais para consultas instantâneas na Loja
        cur.execute('CREATE INDEX IF NOT EXISTS idx_categoria ON loja(categoria)')
        cur.execute('CREATE INDEX IF NOT EXISTS idx_titulo ON loja(titulo)')
        cur.execute('CREATE INDEX IF NOT EXISTS idx_nome_arquivo ON loja(nome_arquivo)')
        
        cur.execute('PRAGMA page_size = 4096')
        cur.execute('ANALYZE')
        conn.commit()
        cur.execute('VACUUM')
        conn.close()
        print(f"✅ SQLite salvo e indexado: {db_path} ({round(os.path.getsize(db_path)/1024, 1)} KB)")

    print("\n🎉 Sincronização de catálogo finalizada com sucesso!")

if __name__ == '__main__':
    generate_catalog()
