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

# 1. Duplicatas a mover para a pasta Quarentena / Duplicados_Removidos
DUPLICATES_TO_REMOVE = [
    # (Arquivo redundante a remover, Arquivo canônico que permanece)
    ("J.dct.mybible", "J D Douglas.dct.mybible"),
    ("Enc Histórico Teologico Da Igreja Crista.dct.mybible", "Enciclopedia Historico Teologico Da Igreja Crista.dct.mybible"),
    ("Thompson expandido.dct.mybible", "Thompson Expandido.dct.mybible"),
    ("Champlim.dct.mybible", "Champlin.dct.mybible"),
    ("Dogmatica.dct.mybible", "Dogmatica Reformada.dct.mybible"),
    ("Minhas 95 Teses Elinaldo Nogueira.dct.mybible", "95 Teses Sobre A Vinda De Jesus Elinaldo Nogueira.dct.mybible"),
    ("RADIOGRAFIA DO JEOVISMO.dct.mybible", "Radiografia Do Jeovismo.dct.mybible"),
    ("Enciclopédia Bíblica Strong E Mcclintock.dct.mybible.zip", "Enciclopédia Bíblica Strong E Mcclintock.dct.mybible"),
]

# 2. Obras que são livros/tratados e devem ser movidas para Livros
BOOKS_TO_MOVE = [
    "95 Teses Sobre A Vinda De Jesus Elinaldo Nogueira.dct.mybible",
    "Dogmatica Reformada.dct.mybible",
    "Radiografia Do Jeovismo.dct.mybible",
    "Teologia Sistemática De Charles Finney.dct.mybible",
    "Hermenêutica Bíblica Br.dct.mybible",
]

def run():
    print("="*60)
    print(" ORGANIZAÇÃO E LIMPEZA DE DICIONÁRIOS / LIVROS")
    print("="*60)

    os.makedirs(DUPES_DIR, exist_ok=True)
    os.makedirs(BOOKS_DIR, exist_ok=True)

    # 1. Mover duplicatas
    print("\n[1/4] Removendo duplicatas para Duplicados_Removidos...")
    removed_dupes = []
    for dup_file, canonical in DUPLICATES_TO_REMOVE:
        src = os.path.join(DICT_DIR, dup_file)
        dst = os.path.join(DUPES_DIR, dup_file)
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f"  ✓ Movido: {dup_file} -> Duplicados_Removidos/ (Mantido: {canonical})")
            removed_dupes.append(dup_file)
        else:
            print(f"  - Já não existe: {dup_file}")

    # 2. Mover livros identificados para a pasta Livros
    print("\n[2/4] Movendo livros de Dicionarios para Livros...")
    moved_books = []
    for book_file in BOOKS_TO_MOVE:
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
            print(f"  - Não encontrado: {book_file}")

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
            
            # Se for duplicata que foi removida, ignorar
            if fname in dupes_set:
                dupes_removed_count += 1
                continue

            # Se for livro, atualizar categoria e URL de download se aplicável
            if fname in books_set:
                item["categoria"] = "Livros"
                if "download_url" in item and "/Dicionarios/" in item["download_url"]:
                    item["download_url"] = item["download_url"].replace("/Dicionarios/", "/Livros/")
                books_migrated_count += 1

            new_items.append(item)

        with open(LOJA_JSON, "w", encoding="utf-8") as f:
            json.dump(new_items, f, ensure_ascii=False, indent=2)

        print(f"  ✓ loja_keryx.json atualizado: {dupes_removed_count} duplicatas removidas, {books_migrated_count} livros migrados para categoria 'Livros'. Total final de itens: {len(new_items)}.")

    # 4. Atualizar bancos SQLite (loja_keryx.db em B2_Downloads e no App)
    print("\n[4/4] Sincronizando bancos SQLite da loja...")
    for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
        if os.path.exists(db_path):
            try:
                conn = sqlite3.connect(db_path)
                cur = conn.cursor()

                # Remover duplicatas do banco
                for dup_file, _ in DUPLICATES_TO_REMOVE:
                    cur.execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (dup_file, dup_file))

                # Atualizar categoria dos livros
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
