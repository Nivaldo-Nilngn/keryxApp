#!/usr/bin/env python3
import os
import shutil
import sqlite3
import json

BASE_DIR = "/home/nivaldo/Área de trabalho/B2_Downloads"
DICT_DIR = os.path.join(BASE_DIR, "Dicionarios")
BOOKS_DIR = os.path.join(BASE_DIR, "Livros")
DUPES_DIR = os.path.join(BASE_DIR, "Duplicados_Removidos")

LOJA_JSON = os.path.join(BASE_DIR, "loja_keryx.json")
LOJA_DB_B2 = os.path.join(BASE_DIR, "loja_keryx.db")
LOJA_DB_APP = "/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db"

# 1. Duplicatas adicionais a isolar em Duplicados_Removidos
ADDITIONAL_DUPLICATES = [
    # (Arquivo a remover, Arquivo principal que fica)
    ("Dicjesus.dct.mybible", "Jesus E Os Evangelhos.dct.mybible"),
    ("Novo Dicionario De Teologia.dct.mybible", "Novo Dicionário De Teologia.dct.mybible"),
    ("Dicionario De Escatologia.dct.mybible", "Dicionário De Escatologia.dct.mybible"),
    ("Tesouro De Conhecimentos Biblicos.dct.mybible", "Tesouro De Conhecimentos Bíblicos.dct.mybible"),
    ("Codigos De Analise Morfologica Robinson.dct.mybible", "Códigos De Análise Morfológica De Robinson.dct.mybible"),
    ("ALMEIDA.dct.mybible", "Almeida Links.dct.mybible"),
    ("Almeida.dct.mybible", "Almeida Links.dct.mybible"),
    ("Nomes.dct.mybible", "Dct Dicionario Nomes.dct.mybible"),
    ("NOMES.dct.mybible", "Dct Dicionario Nomes.dct.mybible"),
    ("Strong Pt Dicionários Bdb Thayer Tvm.dct.mybible", "Strong Pt Dicionários Bdb Thayer Tvm Com Strong.dct.mybible"),
    ("Louw Nida.dct.mybible", "Louw-Nida.dct.mybible"),
]

# 2. Livros e Estudos Temáticos para mover para Livros
ADDITIONAL_BOOKS_TO_MOVE = [
    "Enciclopedia Estudos Da Teologia.dct.mybible",
    "Ajuda Exaustiva Da Biblia Thompson.dct.mybible",
    "Temas Em Cadeia Bíblia Thompson Aal.dct.mybible",
    "Estudos Da Biblia Pentecostal.dct.mybible",
    "Infográficos.dct.mybible",
    "Introduções Plenitude.dct.mybible",
    "Enciclopsheed.dct.mybible",
    "Dicionário Bíblico Respostas Bíblicas.dct.mybible",
    "Chave Biblica Do Conselheiro.dct.mybible",
    "Enciclopedia Popular De Profecia Biblica.dct.mybible",
]

def run():
    print("="*65)
    print(" FASE 2: MOVENDO MAIS LIVROS/ESTUDOS E REMOVENDO DUPLICATAS")
    print("="*65)

    os.makedirs(DUPES_DIR, exist_ok=True)
    os.makedirs(BOOKS_DIR, exist_ok=True)

    # 1. Mover duplicatas
    print("\n[1/4] Removendo duplicatas adicionais para Duplicados_Removidos/...")
    removed_dupes = []
    for dup_file, canonical in ADDITIONAL_DUPLICATES:
        src = os.path.join(DICT_DIR, dup_file)
        dst = os.path.join(DUPES_DIR, dup_file)
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f"  ✓ Isolado: {dup_file} -> Duplicados_Removidos/ (Mantido: {canonical})")
            removed_dupes.append(dup_file)
        else:
            print(f"  - Já não existe em Dicionários: {dup_file}")

    # 2. Mover livros para Livros/
    print("\n[2/4] Movendo livros e estudos temáticos para Livros/...")
    moved_books = []
    for book_file in ADDITIONAL_BOOKS_TO_MOVE:
        src = os.path.join(DICT_DIR, book_file)
        dst = os.path.join(BOOKS_DIR, book_file)
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f"  ✓ Movido: {book_file} -> Livros/")
            moved_books.append(book_file)
        elif os.path.exists(dst):
            print(f"  - Já está em Livros/: {book_file}")
            moved_books.append(book_file)
        else:
            print(f"  - Não encontrado em Dicionários: {book_file}")

    # 3. Atualizar loja_keryx.json
    print("\n[3/4] Atualizando loja_keryx.json...")
    if os.path.exists(LOJA_JSON):
        with open(LOJA_JSON, "r", encoding="utf-8") as f:
            loja_items = json.load(f)

        new_items = []
        dupes_set = set(removed_dupes)
        books_set = set(moved_books)

        dupes_removed_count = 0
        books_migrated_count = 0

        for item in loja_items:
            fname = item.get("nome_arquivo", "")
            
            # Se for duplicata removida, retirar do catálogo
            if fname in dupes_set:
                dupes_removed_count += 1
                continue

            # Se for livro, atualizar categoria
            if fname in books_set:
                item["categoria"] = "Livros"
                if "download_url" in item and "/Dicionarios/" in item["download_url"]:
                    item["download_url"] = item["download_url"].replace("/Dicionarios/", "/Livros/")
                books_migrated_count += 1

            new_items.append(item)

        with open(LOJA_JSON, "w", encoding="utf-8") as f:
            json.dump(new_items, f, ensure_ascii=False, indent=2)

        print(f"  ✓ loja_keryx.json atualizado: {dupes_removed_count} duplicatas retiradas, {books_migrated_count} livros migrados para categoria 'Livros'. Total atual: {len(new_items)}.")

    # 4. Sincronizar bancos SQLite da loja
    print("\n[4/4] Sincronizando bancos SQLite locais...")
    for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
        if os.path.exists(db_path):
            try:
                conn = sqlite3.connect(db_path)
                cur = conn.cursor()

                for dup_file, _ in ADDITIONAL_DUPLICATES:
                    cur.execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (dup_file, dup_file))

                for book_file in moved_books:
                    cur.execute("""
                        UPDATE loja 
                        SET categoria = 'Livros',
                            download_url = REPLACE(download_url, '/Dicionarios/', '/Livros/')
                        WHERE nome_arquivo = ? OR id = ?;
                    """, (book_file, book_file))

                conn.commit()
                total = cur.execute("SELECT count(*) FROM loja;").fetchone()[0]
                books_cnt = cur.execute("SELECT count(*) FROM loja WHERE categoria = 'Livros';").fetchone()[0]
                dicts_cnt = cur.execute("SELECT count(*) FROM loja WHERE categoria = 'Dicionarios';").fetchone()[0]
                conn.close()
                print(f"  ✓ Atualizado: {db_path} (Total: {total} itens | Livros: {books_cnt} | Dicionários: {dicts_cnt})")
            except Exception as e:
                print(f"  ❌ Erro ao atualizar {db_path}: {e}")

    print("\n🎉 Operação concluída com sucesso!")

if __name__ == "__main__":
    run()
