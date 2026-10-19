#!/usr/bin/env python3
import os
import shutil
import sqlite3
import json

BASE_DIR = "/home/nivaldo/Área de trabalho/B2_Downloads"
COMMENTS_DIR = os.path.join(BASE_DIR, "Comentarios")
DUPES_DIR = os.path.join(BASE_DIR, "Duplicados_Removidos")
BOOKS_DIR = os.path.join(BASE_DIR, "Livros")

LOJA_JSON = os.path.join(BASE_DIR, "loja_keryx.json")
LOJA_DB_B2 = os.path.join(BASE_DIR, "loja_keryx.db")
LOJA_DB_APP = "/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db"

# Duplicatas exatas detectadas por comparação de versículos e hash
# (Arquivo duplicado redundante a mover, Arquivo canônico mantido)
CONFIRMED_DUPLICATES = [
    # 0 bytes corrupt
    ("Historico.Cultural.NT.cmt.mybible", "Histórico Cultural.cmt.mybible"),

    # Variações de acento / grafia idênticas
    ("A Epistola Aos Galatas.cmt.mybible", "A Epístola Aos Gálatas.cmt.mybible"),
    ("A Epistola Aos Hebreus Thomas Charles Edwards.cmt.mybible", "A Epístola Aos Hebreus Thomas Charles Edwards, D.cmt.mybible"),
    ("A Mensagem De Eclesiastes Derek Kidner.cmt.mybible", "A Mensagem de Eclesiastes - Derek Kidner.cmt.mybible"),
    ("A Mensagem De Galatas.cmt.mybible", "A Mensagem De Gálatas.cmt.mybible"),
    ("A Mensagem De Rute David Atkinson.cmt.mybible", "A Mensagem de Rute - David Atkinson.cmt.mybible"),
    ("Apocalipse Versiculo Por Versiculo.cmt.mybible", "Apocalipse Versículo Por Versículo.cmt.mybible"),
    ("Biblia De Estudo Conselheira.cmt.mybible", "Bíblia De Estudo Conselheira.cmt.mybible"),
    ("Biblia De Estudo Pentecostal.cmt.mybible", "Bíblia De Estudo Pentencostal.cmt.mybible"),
    ("Biblia de Estudo NTLH.cmt.mybible", "Biblia De Estudo [NTLH].cmt.mybible"),
    ("Notas Bíblia De Estudo [NVI].cmt.mybible", "Biblia De Estudo [NVI] (notas).cmt.mybible"),
    ("Biblia De Genebra.cmt.mybible", "Comentário Bíblia Genebra.cmt.mybible"),
    ("Biblia Diario Viver.cmt.mybible", "Comentários Da Bíblia Diario Viver.cmt.mybible"),
    ("Comentario Atos Antigo E Novo Testamento.cmt.mybible", "Comentário Atos At E Novo Testamento.cmt.mybible"),
    ("Comentario Basico Do Novo Testamento.cmt.mybible", "Comentário Básico Do Novo Testamento.cmt.mybible"),
    ("Comentario Biblico Aos Romanos Rubem Martins.cmt.mybible", "Comentário Bíblico Romanos.cmt.mybible"),
    ("Kretzmann.cmt.mybible", "Comentario Bíblico Popular Kretzmann.cmt.mybible"),
    ("Comentario Com Recursos Adicionais.cmt.mybible", "Comentário Com Recursos Adicionais.cmt.mybible"),
    ("Comentario Esperanca Novo Testamento.cmt.mybible", "Comentario Esperança Novo Testamento.cmt.mybible"),
    ("Comentario Exaustivo Da Carta Aos Hebreus Orton.cmt.mybible", "Comentário Exaustivo Da Carta Aos Hebreus Orton.cmt.mybible"),
    ("Comentario Exegese E Exposicao.cmt.mybible", "Comentario Exegese E Exposição.cmt.mybible"),
    ("Exegese E Exposição.cmt.mybible", "Comentario Exegese E Exposição.cmt.mybible"),
    ("Wesleyana Comentario Biblico.cmt.mybible", "Comentário Bíblico Wesleyana.cmt.mybible"),
    ("Comentário Da Bíblia [NVI] Ffbruce.cmt.mybible", "Comentário Da Bíblia [NVI] F F Bruce.cmt.mybible"),
    ("Comentário Exposito O Conhecimento Bíblico John F.cmt.mybible", "Comentário Expositivo O Conhecimento.cmt.mybible"),
    ("Daniel Vers.cmt.mybible", "Daniel Versiculo Por Versiculo.cmt.mybible"),
    ("Tiago William Taylor.cmt.mybible", "Epístola De Tiago William Taylor.cmt.mybible"),
    ("Estudo Da Carta Aos Efesios.cmt.mybible", "Estudo Da Carta Aos Efésios.cmt.mybible"),
    ("Estudos Nas Epistolas De Pedro.cmt.mybible", "Estudos Nas Epístolas De Pedro.cmt.mybible"),
    ("Galatas Spurgeon.cmt.mybible", "Gálatas Spurgeon.cmt.mybible"),
    ("Novo Comentario Conteporaneo (nt).cmt.mybible", "Novo Comentário Bíblico Contemporâneo.cmt.mybible"),
    ("Warren.cmt.mybible", "Wiersbe Conciso.cmt.mybible"),
    ("Adam Clarke Velho Testamento.cmt.mybible", "Comentário Do Velho Testamento De Adam Clarke.cmt.mybible"),
    ("Antonio Neves De Mesquita.cmt.mybible", "Comentarios Antonio Mesquita.cmt.mybible"),
]

def run(execute=False):
    print("="*65)
    print(" AUDITORIA E LIMPEZA DE COMENTÁRIOS")
    print("="*65)

    if not execute:
        print("\n[MODO SIMULAÇÃO] Para executar a limpeza real, passe o argumento --execute.")
    
    os.makedirs(DUPES_DIR, exist_ok=True)
    
    found_dupes = []
    for dup, canon in CONFIRMED_DUPLICATES:
        src = os.path.join(COMMENTS_DIR, dup)
        if os.path.exists(src):
            sz_mb = round(os.path.getsize(src) / (1024 * 1024), 2)
            found_dupes.append((dup, canon, sz_mb))
            if execute:
                dst = os.path.join(DUPES_DIR, dup)
                shutil.move(src, dst)
                print(f"  ✓ Isolado: {dup} ({sz_mb} MB) -> Duplicados_Removidos/ (Mantido: {canon})")
            else:
                print(f"  • Duplicata: {dup} ({sz_mb} MB) -> Mantém: {canon}")

    print(f"\nTotal de duplicatas confirmadas encontradas: {len(found_dupes)} arquivos.")

    if execute:
        # Atualizar loja_keryx.json e SQLite
        dupes_set = {d[0] for d in found_dupes}
        if os.path.exists(LOJA_JSON):
            with open(LOJA_JSON, "r", encoding="utf-8") as f:
                items = json.load(f)
            items = [it for it in items if it.get("nome_arquivo") not in dupes_set and it.get("id") not in dupes_set]
            with open(LOJA_JSON, "w", encoding="utf-8") as f:
                json.dump(items, f, ensure_ascii=False, indent=2)
            print(f"  ✓ loja_keryx.json atualizado. Total final: {len(items)} itens.")

        for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
            if os.path.exists(db_path):
                conn = sqlite3.connect(db_path)
                cur = conn.cursor()
                for dup in dupes_set:
                    cur.execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (dup, dup))
                conn.commit()
                total = cur.execute("SELECT count(*) FROM loja;").fetchone()[0]
                conn.close()
                print(f"  ✓ Banco {os.path.basename(db_path)} sincronizado (Total: {total} itens).")

if __name__ == "__main__":
    import sys
    run(execute="--execute" in sys.argv)
