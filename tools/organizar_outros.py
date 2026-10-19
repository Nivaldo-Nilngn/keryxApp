#!/usr/bin/env python3
import os
import shutil
import sqlite3
import json

BASE_DIR = "/home/nivaldo/Área de trabalho/B2_Downloads"
OUTROS_DIR = os.path.join(BASE_DIR, "Outros")
DUPES_DIR = os.path.join(BASE_DIR, "Duplicados_Removidos")
COMENTARIOS_DIR = os.path.join(BASE_DIR, "Comentarios")

LOJA_JSON = os.path.join(BASE_DIR, "loja_keryx.json")
LOJA_DB_B2 = os.path.join(BASE_DIR, "loja_keryx.db")
LOJA_DB_APP = "/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db"

def run():
    print("="*65)
    print(" ORGANIZAÇÃO E LIMPEZA DA PASTA 'OUTROS'")
    print("="*65)

    os.makedirs(DUPES_DIR, exist_ok=True)

    # 1. Mover duplicatas exatas / cópias com (1) ou tabelas inchadas
    dupes_to_remove = [
        "A Bíblia Comentada Chapter A Day.cmt (1).mybible",
        "ARM_1967_Almeida_Revisada_de_acordo.mybible",
        "CODIGOS DE ANALISE MORFOLOGICA - Robinson.dct (1).mybible",
        "DICIONARIO_TEOLOGICO_Claudionor_Correia_de_Andrade_dct_1.mybible",
        "Dicionário de Temas Bíblicos em Cadeia.dct (1).mybible",
        "EnciclopédiaMerril.dct (1).mybible",
        "Provérbios - William MacDonald.cmt (1).mybible",
        "THOMPSON.dct (1).mybible",
        "louw-nida.dct (1).mybible",
    ]

    print("\n[1/4] Movendo 9 duplicatas/cópias redundantes para Duplicados_Removidos/...")
    for fn in dupes_to_remove:
        src = os.path.join(OUTROS_DIR, fn)
        dst = os.path.join(DUPES_DIR, fn)
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f"  ✓ Isolado: {fn} -> Duplicados_Removidos/")
        else:
            print(f"  - Arquivo não encontrado: {fn}")

    # 2. Atualizar Comentários Expositivos Hernandes Dias Lopes para a versão mais completa (935 seções vs 784)
    print("\n[2/4] Atualizando Comentário Hernandes Dias Lopes com a edição mais completa (935 seções)...")
    hdl_src = os.path.join(OUTROS_DIR, "Comentários Expositivos Hernandes Dias Lopes .cmt (1).mybible")
    hdl_current = os.path.join(COMENTARIOS_DIR, "Comentários Expositivos Hernandes Dias Lopes.cmt.mybible")
    hdl_backup = os.path.join(DUPES_DIR, "Comentários Expositivos Hernandes Dias Lopes (antigo_784_secoes).cmt.mybible")

    if os.path.exists(hdl_src):
        if os.path.exists(hdl_current):
            shutil.move(hdl_current, hdl_backup)
            print(f"  ✓ Versão antiga (784 seções) movida para: {os.path.basename(hdl_backup)}")
        shutil.move(hdl_src, hdl_current)
        print("  ✓ Nova edição completa instalada em: Comentarios/Comentários Expositivos Hernandes Dias Lopes.cmt.mybible")

    # 3. Mover e renomear Comentário David Guzik para Comentarios/
    print("\n[3/4] Movendo Comentário David Guzik para Comentarios/...")
    guzik_src = os.path.join(OUTROS_DIR, "Comentário Guzik_Toda a Bíblia.mybible")
    guzik_dst = os.path.join(COMENTARIOS_DIR, "Comentário David Guzik Toda a Bíblia.cmt.mybible")

    if os.path.exists(guzik_src):
        shutil.move(guzik_src, guzik_dst)
        print(f"  ✓ Movido e renomeado: {os.path.basename(guzik_dst)} ({round(os.path.getsize(guzik_dst)/(1024*1024), 2)} MB, 7.550 seções)")
    else:
        print("  - Comentário Guzik já movido ou não encontrado.")

    # 4. Arquivos restantes em Outros
    remaining = os.listdir(OUTROS_DIR)
    print(f"\nArquivos preservados na pasta Outros ({len(remaining)} itens de sistema/interface):")
    for r in sorted(remaining):
        p = os.path.join(OUTROS_DIR, r)
        sz_kb = round(os.path.getsize(p) / 1024, 1) if os.path.isfile(p) else "DIR"
        print(f"  • {r} ({sz_kb} KB)")

    # 5. Sincronizar catálogo loja_keryx.json e bancos SQLite
    print("\n[4/4] Sincronizando catálogo da Loja...")
    guzik_fn = "Comentário David Guzik Toda a Bíblia.cmt.mybible"
    guzik_size = round(os.path.getsize(guzik_dst)/(1024*1024), 2) if os.path.exists(guzik_dst) else 22.43
    hdl_size = round(os.path.getsize(hdl_current)/(1024*1024), 2) if os.path.exists(hdl_current) else 20.66

    if os.path.exists(LOJA_JSON):
        with open(LOJA_JSON, "r", encoding="utf-8") as f:
            items = json.load(f)

        # Remover quaisquer referências às duplicatas de Outros
        dupes_names = set(dupes_to_remove)
        items = [it for it in items if it.get("nome_arquivo") not in dupes_names and it.get("id") not in dupes_names]

        # Atualizar tamanho do Hernandes Dias Lopes
        for it in items:
            if it.get("nome_arquivo") == "Comentários Expositivos Hernandes Dias Lopes.cmt.mybible":
                it["tamanho_mb"] = hdl_size

        # Adicionar Guzik se não existir
        if not any(it.get("nome_arquivo") == guzik_fn for it in items):
            items.append({
                "id": guzik_fn,
                "titulo": "Comentário David Guzik Toda a Bíblia",
                "nome_arquivo": guzik_fn,
                "tamanho_mb": guzik_size,
                "categoria": "Comentarios",
                "formato": "MYBIBLE",
                "url_image": "",
                "file_id": None,
                "download_url": f"https://github.com/Nivaldo-Nilngn/Loja-Keryx/releases/download/Comentarios/{guzik_fn}"
            })
            print(f"  ✓ Adicionado {guzik_fn} ao loja_keryx.json")

        with open(LOJA_JSON, "w", encoding="utf-8") as f:
            json.dump(items, f, ensure_ascii=False, indent=2)
        print(f"  ✓ loja_keryx.json salvo com {len(items)} itens.")

    # Atualizar SQLite
    for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
        if os.path.exists(db_path):
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()

            # Deletar duplicatas
            for dup in dupes_to_remove:
                cur.execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (dup, dup))

            # Atualizar Hernandes
            cur.execute("""
                UPDATE loja
                SET tamanho_mb = ?
                WHERE nome_arquivo = 'Comentários Expositivos Hernandes Dias Lopes.cmt.mybible';
            """, (hdl_size,))

            # Inserir Guzik se não existir
            cur.execute("SELECT count(*) FROM loja WHERE nome_arquivo = ?;", (guzik_fn,))
            if cur.fetchone()[0] == 0:
                cur.execute("""
                    INSERT INTO loja (id, titulo, nome_arquivo, tamanho_mb, categoria, formato, url_image, file_id, download_url)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """, (
                    guzik_fn,
                    "Comentário David Guzik Toda a Bíblia",
                    guzik_fn,
                    guzik_size,
                    "Comentarios",
                    "MYBIBLE",
                    "",
                    None,
                    f"https://github.com/Nivaldo-Nilngn/Loja-Keryx/releases/download/Comentarios/{guzik_fn}"
                ))
                print(f"  ✓ Inserido {guzik_fn} no banco: {os.path.basename(db_path)}")

            conn.commit()
            total = cur.execute("SELECT count(*) FROM loja;").fetchone()[0]
            conn.close()
            print(f"  ✓ Banco {os.path.basename(db_path)} atualizado com {total} itens.")

    print("\n🎉 Limpeza e organização de 'Outros' concluída com sucesso!")

if __name__ == "__main__":
    run()
