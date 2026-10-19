#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script Automatizado de Limpeza e Upload dos 425 Módulos para o GitHub Releases
Repositório: Nivaldo-Nilngn/Loja-Keryx
"""

import os
import sys
import subprocess
import time

REPO = "Nivaldo-Nilngn/Loja-Keryx"
GH_CLI = "/home/nivaldo/.local/bin/gh"
TOKEN = "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"

ENV = dict(os.environ)
ENV["GH_TOKEN"] = TOKEN

BASE_DIR = '/home/nivaldo/Área de trabalho/B2_Downloads'
PASTAS = {
    'Livros': {
        'path': os.path.join(BASE_DIR, 'Livros'),
        'desc': 'Coleção de Livros e Obras Teológicas otimizadas com índices SQLite para a Loja Keryx.'
    },
    'Dicionarios': {
        'path': os.path.join(BASE_DIR, 'Dicionarios'),
        'desc': 'Coleção de Dicionários Bíblicos e Teológicos otimizados com índices SQLite para a Loja Keryx.'
    },
    'Biblias': {
        'path': os.path.join(BASE_DIR, 'Biblias'),
        'desc': 'Coleção de Bíblias e Textos Sagrados otimizados com índices compostos SQLite para a Loja Keryx.'
    },
    'Comentarios': {
        'path': os.path.join(BASE_DIR, 'Comentarios'),
        'desc': 'Coleção de Comentários Bíblicos e Expositivos otimizados com índices SQLite para a Loja Keryx.'
    },
}

def run_cmd(cmd_list):
    res = subprocess.run(cmd_list, env=ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.returncode == 0, res.stdout.strip(), res.stderr.strip()

def recreate_release(tag, desc):
    print(f"\n🔄 Recriando release limpa '{tag}'...")
    run_cmd([GH_CLI, "release", "delete", tag, "--repo", REPO, "-y", "--cleanup-tag"])
    time.sleep(1)
    ok, out, err = run_cmd([
        GH_CLI, "release", "create", tag,
        "--title", f"Módulos: {tag}",
        "--notes", desc,
        "--repo", REPO
    ])
    if ok:
        print(f"  ✨ Release '{tag}' criada com sucesso: {out}")
    else:
        print(f"  ❌ Erro ao criar release '{tag}': {err}")
    return ok

def upload_category(tag, info):
    folder = info['path']
    if not os.path.exists(folder):
        print(f"⚠️ Pasta não encontrada: {folder}")
        return

    files = [
        f for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f))
        and not f.endswith(('-wal', '-shm', '-journal', '.tmp'))
    ]
    files.sort()

    print(f"\n" + "=" * 70)
    print(f"🚀 INICIANDO UPLOAD: {tag.upper()} ({len(files)} arquivos)")
    print("=" * 70)

    success_count = 0
    fail_count = 0

    for i, fn in enumerate(files, 1):
        filepath = os.path.join(folder, fn)
        sz_mb = round(os.path.getsize(filepath) / (1024 * 1024), 2)
        print(f"  [{i}/{len(files)}] ⬆️ Enviando ({sz_mb} MB): {fn[:55]}...", flush=True)

        retry = 0
        uploaded = False
        while retry < 3 and not uploaded:
            ok, out, err = run_cmd([
                GH_CLI, "release", "upload", tag, filepath,
                "--repo", REPO,
                "--clobber"
            ])
            if ok:
                uploaded = True
                success_count += 1
            else:
                retry += 1
                print(f"     ⚠️ Falha no envio (tentativa {retry}/3): {err}. Aguardando 3s...", flush=True)
                time.sleep(3)

        if not uploaded:
            fail_count += 1
            print(f"     ❌ FALHA DEFINITIVA: {fn}", flush=True)

    print(f"\n✨ Concluído {tag}: {success_count}/{len(files)} enviados com sucesso (Falhas: {fail_count})")

def main():
    target = sys.argv[1] if len(sys.argv) > 1 else 'Todos'
    
    start_total = time.time()
    print("=" * 70)
    print(f"📦 SINCRONIZADOR DE ARQUIVOS COM O GITHUB RELEASES ({REPO})")
    print("=" * 70)

    cats = [target] if target in PASTAS else ['Livros', 'Dicionarios', 'Biblias', 'Comentarios']

    for cat in cats:
        # 1. Recria a release limpa (exceto se Livros já foi recriada)
        if cat != 'Livros':
            recreate_release(cat, PASTAS[cat]['desc'])
        # 2. Faz o upload de todos os arquivos
        upload_category(cat, PASTAS[cat])

    elapsed = time.time() - start_total
    print("\n" + "=" * 70)
    print(f"🎉 PROCESSO TOTAL DE UPLOAD CONCLUÍDO EM {elapsed/60:.1f} MINUTOS!")
    print(f"🔗 Veja seus lançamentos em: https://github.com/{REPO}/releases")
    print("=" * 70)

if __name__ == '__main__':
    main()
