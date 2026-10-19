#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de Otimização e Indexação de Conteúdo MyBible / SQLite
Aplica índices B-Tree específicos, PRAGMA page_size=4096, ANALYZE e VACUUM
em todas as Bíblias, Comentários, Dicionários e Livros para garantir leitura ultra-rápida.
"""

import os
import sys
import glob
import sqlite3
import time

BASE_DIR = '/home/nivaldo/Área de trabalho/B2_Downloads'
FOLDERS = {
    'Biblias': os.path.join(BASE_DIR, 'Biblias'),
    'Comentarios': os.path.join(BASE_DIR, 'Comentarios'),
    'Dicionarios': os.path.join(BASE_DIR, 'Dicionarios'),
    'Livros': os.path.join(BASE_DIR, 'Livros'),
}

def clean_locks(path):
    for ext in ['-wal', '-shm', '-journal']:
        lock_file = path + ext
        if os.path.exists(lock_file):
            try:
                os.remove(lock_file)
            except Exception:
                pass

def optimize_bible(path):
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    table_map = {name.lower(): name for name in tables}
    
    target_table = None
    for candidate in ['bible', 'verses', 'verse']:
        if candidate in table_map:
            target_table = table_map[candidate]
            break
            
    if not target_table:
        conn.close()
        return False, "Nenhuma tabela de versículos encontrada"
        
    cur.execute(f'PRAGMA table_info("{target_table}")')
    cols = {r[1].lower(): r[1] for r in cur.fetchall()}
    
    book_col = cols.get('book') or cols.get('book_number') or cols.get('book_id') or 'Book'
    chap_col = cols.get('chapter') or 'Chapter'
    verse_col = cols.get('verse') or 'Verse'
    
    # Criação de índices
    cur.execute(f'CREATE INDEX IF NOT EXISTS idx_bbl_bcv ON "{target_table}" ("{book_col}", "{chap_col}", "{verse_col}")')
    cur.execute(f'CREATE INDEX IF NOT EXISTS idx_bbl_bc ON "{target_table}" ("{book_col}", "{chap_col}")')
    
    cur.execute("PRAGMA page_size = 4096")
    cur.execute("ANALYZE")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()
    clean_locks(path)
    return True, f"Indexado: {target_table}({book_col}, {chap_col}, {verse_col})"

def optimize_commentary(path):
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    table_map = {name.lower(): name for name in tables}
    
    target_table = None
    for candidate in ['commentary', 'commentaries']:
        if candidate in table_map:
            target_table = table_map[candidate]
            break
            
    if not target_table:
        conn.close()
        return False, "Nenhuma tabela de comentários encontrada"
        
    cur.execute(f'PRAGMA table_info("{target_table}")')
    cols = {r[1].lower(): r[1] for r in cur.fetchall()}
    
    book_col = cols.get('book') or cols.get('book_id') or cols.get('book_number') or 'book'
    chap_col = cols.get('chapter') or cols.get('chapter_number') or 'chapter'
    from_col = cols.get('fromverse') or cols.get('from') or cols.get('verse') or 'fromverse'
    to_col = cols.get('toverse') or cols.get('to') or cols.get('verse') or 'toverse'
    
    # Criação de índices para busca instantânea por versículo e por livro
    cur.execute(f'CREATE INDEX IF NOT EXISTS idx_commentary_lookup ON "{target_table}" ("{book_col}", "{chap_col}", "{from_col}", "{to_col}")')
    cur.execute(f'CREATE INDEX IF NOT EXISTS idx_commentary_book ON "{target_table}" ("{book_col}")')
    cur.execute(f'CREATE INDEX IF NOT EXISTS idx_commentary_bc ON "{target_table}" ("{book_col}", "{chap_col}")')
    
    cur.execute("PRAGMA page_size = 4096")
    cur.execute("ANALYZE")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()
    clean_locks(path)
    return True, f"Indexado: {target_table}({book_col}, {chap_col}, {from_col}-{to_col})"

def optimize_dictionary(path):
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    table_map = {name.lower(): name for name in tables}
    
    target_table = None
    for candidate in ['dictionary', 'dictionaries', 'ogntd', 'ohbd']:
        if candidate in table_map:
            target_table = table_map[candidate]
            break
            
    if not target_table:
        conn.close()
        return False, "Nenhuma tabela de dicionário encontrada"
        
    cur.execute(f'PRAGMA table_info("{target_table}")')
    cols = {r[1].lower(): r[1] for r in cur.fetchall()}
    
    indexed = []
    if 'word' in cols:
        cur.execute(f'CREATE INDEX IF NOT EXISTS idx_dict_word ON "{target_table}" ("{cols["word"]}")')
        indexed.append('word')
    if 'topic' in cols:
        cur.execute(f'CREATE INDEX IF NOT EXISTS idx_dict_topic ON "{target_table}" ("{cols["topic"]}")')
        indexed.append('topic')
    if 'relativeorder' in cols:
        cur.execute(f'CREATE INDEX IF NOT EXISTS idx_dict_order ON "{target_table}" ("{cols["relativeorder"]}")')
        indexed.append('order')
    if 'lexeme' in cols:
        cur.execute(f'CREATE INDEX IF NOT EXISTS idx_dict_lexeme ON "{target_table}" ("{cols["lexeme"]}")')
        indexed.append('lexeme')
        
    cur.execute("PRAGMA page_size = 4096")
    cur.execute("ANALYZE")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()
    clean_locks(path)
    return True, f"Indexado: {target_table}({', '.join(indexed) if indexed else 'otimizado'})"

def optimize_book(path):
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cur.fetchall()]
    
    indexed = []
    if 'journal' in tables:
        cur.execute("PRAGMA table_info(journal)")
        cols = {r[1].lower(): r[1] for r in cur.fetchall()}
        if 'id' in cols:
            cur.execute(f'CREATE INDEX IF NOT EXISTS idx_journal_id ON journal ("{cols["id"]}")')
            indexed.append('journal(id)')
        if 'book_number' in cols and 'chapter' in cols:
            cur.execute(f'CREATE INDEX IF NOT EXISTS idx_journal_bc ON journal ("{cols["book_number"]}", "{cols["chapter"]}")')
            indexed.append('journal(bc)')
            
    if 'data' in tables:
        cur.execute("PRAGMA table_info(data)")
        cols = {r[1].lower(): r[1] for r in cur.fetchall()}
        if 'id' in cols:
            cur.execute(f'CREATE INDEX IF NOT EXISTS idx_data_id ON data ("{cols["id"]}")')
            indexed.append('data(id)')
            
    cur.execute("PRAGMA page_size = 4096")
    cur.execute("ANALYZE")
    conn.commit()
    cur.execute("VACUUM")
    conn.close()
    clean_locks(path)
    return True, f"Indexado: {', '.join(indexed) if indexed else 'tabelas existentes'}"

def optimize_assets():
    print("\n📂 Processando BANCOS DE DADOS EM ASSETS...")
    assets_files = [
        ('/home/nivaldo/Área de trabalho/Biblia/assets/bible/sql/NVI.sqlite', [
            'CREATE INDEX IF NOT EXISTS idx_verse_bcv ON verse (book_id, chapter, verse)',
            'CREATE INDEX IF NOT EXISTS idx_verse_bc ON verse (book_id, chapter)',
            'CREATE INDEX IF NOT EXISTS idx_book_id ON book (id)',
            'CREATE INDEX IF NOT EXISTS idx_book_ref ON book (book_reference_id)'
        ]),
        ('/home/nivaldo/Área de trabalho/Biblia/assets/database/strongV2.db', [
            'CREATE INDEX IF NOT EXISTS idx_strong_codigo ON STRONG (CODIGO)',
            'CREATE INDEX IF NOT EXISTS idx_strong_idioma ON STRONG (IDIOMA)'
        ]),
        ('/home/nivaldo/Área de trabalho/Biblia/assets/database/ARA_S.db', [
            'CREATE UNIQUE INDEX IF NOT EXISTS bible_key ON Bible (Book, Chapter, Verse)'
        ]),
        ('/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db', [
            'CREATE INDEX IF NOT EXISTS idx_categoria ON loja(categoria)',
            'CREATE INDEX IF NOT EXISTS idx_titulo ON loja(titulo)'
        ])
    ]
    
    for path, index_sqls in assets_files:
        if not os.path.exists(path):
            print(f"   ⚠️ Não encontrado: {path}")
            continue
        try:
            conn = sqlite3.connect(path)
            cur = conn.cursor()
            for sql in index_sqls:
                cur.execute(sql)
            cur.execute("PRAGMA page_size = 4096")
            cur.execute("ANALYZE")
            conn.commit()
            cur.execute("VACUUM")
            conn.close()
            clean_locks(path)
            fname = os.path.basename(path)
            print(f"   ✅ {fname} indexado e otimizado com sucesso!")
        except Exception as e:
            print(f"   ❌ Erro ao otimizar {path}: {e}")

def run():
    print("=" * 70)
    print("⚡ INICIANDO OTIMIZAÇÃO E INDEXAÇÃO DE BANCOS SQLITE (MYBIBLE & ASSETS)")
    print("=" * 70)
    
    total_processed = 0
    total_success = 0
    start_time = time.time()
    
    # 1. Assets
    optimize_assets()
    
    # 2. B2_Downloads
    for category, folder_path in FOLDERS.items():
        if not os.path.exists(folder_path):
            print(f"⚠️ Pasta não encontrada: {folder_path}")
            continue
            
        files = [
            os.path.join(folder_path, f) for f in os.listdir(folder_path)
            if f.endswith('.mybible') and not f.endswith(('-wal', '-shm', '-journal'))
        ]
        files.sort()
        
        print(f"\n📂 Processando {category.upper()} ({len(files)} arquivos)...")
        cat_success = 0
        
        for i, filepath in enumerate(files, 1):
            filename = os.path.basename(filepath)
            total_processed += 1
            try:
                if category == 'Biblias':
                    ok, msg = optimize_bible(filepath)
                elif category == 'Comentarios':
                    ok, msg = optimize_commentary(filepath)
                elif category == 'Dicionarios':
                    ok, msg = optimize_dictionary(filepath)
                elif category == 'Livros':
                    ok, msg = optimize_book(filepath)
                else:
                    ok, msg = False, "Categoria desconhecida"
                    
                if ok:
                    total_success += 1
                    cat_success += 1
                    if i % 25 == 0 or i == len(files):
                        print(f"   [{i}/{len(files)}] ✅ {filename[:40]}... ({msg})")
                else:
                    print(f"   [{i}/{len(files)}] ⚠️ {filename[:40]}: {msg}")
            except Exception as e:
                print(f"   [{i}/{len(files)}] ❌ Erro em {filename}: {e}")
                
        print(f"✨ Concluído {category}: {cat_success}/{len(files)} otimizados com sucesso.")

    elapsed = time.time() - start_time
    print("\n" + "=" * 70)
    print(f"🎉 OTIMIZAÇÃO CONCLUÍDA EM {elapsed:.1f}s!")
    print(f"📊 Total de arquivos otimizados e indexados: {total_success}/{total_processed}")
    print("=" * 70)

if __name__ == '__main__':
    run()
