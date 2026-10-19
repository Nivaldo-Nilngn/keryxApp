#!/usr/bin/env python3
import os
import shutil
import sqlite3
import json

BASE_DIR = "/home/nivaldo/Área de trabalho/B2_Downloads"
BIBLES_DIR = os.path.join(BASE_DIR, "Biblias")
DUPES_DIR = os.path.join(BASE_DIR, "Duplicados_Removidos")

LOJA_JSON = os.path.join(BASE_DIR, "loja_keryx.json")
LOJA_DB_B2 = os.path.join(BASE_DIR, "loja_keryx.db")
LOJA_DB_APP = "/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db"

# 1. Duplicatas a mover para Duplicados_Removidos
BIBLE_DUPLICATES = [
    ("[NTLH].bbl.mybible", "[NTLH] (linguagem De Hoje).bbl.mybible"),
    ("[KJA] King James.bbl.mybible", "[KJA] (king James Atualizada).bbl.mybible"),
    ("Jfa Ra(br).bbl.mybible", "Jfa Ra (almeida Atualizada).bbl.mybible"),
    ("Rvp (reina Valera).bbl.mybible", "Rvp (reina Valera Português).bbl.mybible"),
    ("Vfl Versão Fácil De Ler.bbl.mybible", "Vfl (versão Fácil De Ler).bbl.mybible"),
    ("[ACF] 2011 (fiel 2011).bbl.mybible", "[ACF] 2011 (almeida Corrigida Fiel 2011).bbl.mybible"),
    ("Arc1969.bbl.mybible", "[ARC] 1969 (corrigida 1969).bbl.mybible"),
    ("Blivre.bbl.mybible", "Biblialivre.bbl.mybible"),
    ("Bíblia De Jerusalem.bbl.mybible", "Bj N (bíblia De Jerusálem Com Notas).bbl.mybible"),
    ("Acf2007.bbl.mybible", "[ACF] 2007 (almeida Corrigida Fiel 2007).bbl.mybible"),
    ("Ltt2009 Literal.bbl.mybible", "Ltt 2009 (literal 2009).bbl.mybible"),
    ("Tnm Tradução Do Novo Mundo.bbl.mybible", "Tnm 1986 (tradução Do Novo Mundo 1986).bbl.mybible"),
    ("Msg (a Mensagem).bbl.mybible", "Biblia0 Msg Amensagem.bbl.mybible"),
    ("Jfarastrong.bbl.mybible", "[ARA] Strong Atualizada Strong.bbl.mybible"),
    ("Viva (bíblia Viva).bbl.mybible", "Viva.bbl.mybible"),
]

# 2. Mapeamento de renomeação padronizada: Nome Real Completo (SIGLA)
RENAME_MAP = {
    # Almeidas
    "[ARA].bbl.mybible": "Almeida Revista e Atualizada (ARA).bbl.mybible",
    "[ARA] Is (ara Com Interlinear E Strong).bbl.mybible": "Almeida Revista e Atualizada Interlinear e Strong (ARA-IS).bbl.mybible",
    "[ARA] Strong Atualizada Strong.bbl.mybible": "Almeida Revista e Atualizada com Números de Strong (ARA-S).bbl.mybible",
    "[ACF] 1994 (almeida Corrigida Fiel 1994).bbl.mybible": "Almeida Corrigida Fiel 1994 (ACF).bbl.mybible",
    "[ACF] 2007 (almeida Corrigida Fiel 2007).bbl.mybible": "Almeida Corrigida Fiel 2007 (ACF).bbl.mybible",
    "[ACF] 2011 (almeida Corrigida Fiel 2011).bbl.mybible": "Almeida Corrigida Fiel 2011 (ACF).bbl.mybible",
    "[ARC] 1911 (corrigida 1911).bbl.mybible": "Almeida Revista e Corrigida 1911 (ARC).bbl.mybible",
    "[ARC] 1969 (corrigida 1969).bbl.mybible": "Almeida Revista e Corrigida 1969 (ARC).bbl.mybible",
    "[ARC] 1995 (corrigida 1995).bbl.mybible": "Almeida Revista e Corrigida 1995 (ARC).bbl.mybible",
    "[ARC] 2001 (corrigida Portugal).bbl.mybible": "Almeida Revista e Corrigida Portugal 2001 (ARC).bbl.mybible",
    "[ARC] 2009 Sbb (corrigida 2009).bbl.mybible": "Almeida Revista e Corrigida 2009 SBB (ARC).bbl.mybible",
    "A21 (almeida Século 21).bbl.mybible": "Almeida Século 21 (A21).bbl.mybible",
    "Aec V (almeida Edição Contemporânea).bbl.mybible": "Almeida Edição Contemporânea (AEC).bbl.mybible",
    "Arm1967.bbl.mybible": "Almeida Revisada Imprensa Bíblica 1967 (ARM).bbl.mybible",
    "Corrigida Fiel (1753 1995).bbl.mybible": "Almeida Corrigida Fiel 1753-1995 (ACF).bbl.mybible",
    "Jfa 1819 (almeida 1819).bbl.mybible": "Almeida Tradução Original 1819 (JFA-1819).bbl.mybible",
    "Jfa Ra (almeida Atualizada).bbl.mybible": "Almeida Revista e Atualizada Clássica (JFA-RA).bbl.mybible",
    "Jfa Rc(pt).bbl.mybible": "Almeida Revista e Corrigida Portugal (JFA-RC).bbl.mybible",

    # Bíblias de Estudo
    "Beacf (bíblia De Estudo Acf).bbl.mybible": "Bíblia de Estudo ACF (BEACF).bbl.mybible",
    "Bedf (biblia De Estudo Defesa Da Fe).bbl.mybible": "Bíblia de Estudo Defesa da Fé (BEDF).bbl.mybible",
    "Bemh (bíblia De Estudo Mathew Henry).bbl.mybible": "Bíblia de Estudo Matthew Henry (BEMH).bbl.mybible",
    "Bep (bíblia De Estudo Pentecostal).bbl.mybible": "Bíblia de Estudo Pentecostal (BEP).bbl.mybible",
    "Bevt (biblia De Estudo Variantes Textuais).bbl.mybible": "Bíblia de Estudo Variantes Textuais (BEVT).bbl.mybible",
    "Bevt Hg.bbl.mybible": "Bíblia de Estudo Variantes Textuais Hebraico e Grego (BEVT-HG).bbl.mybible",
    "Exp (biblia Do Expositor).bbl.mybible": "Bíblia de Estudo do Expositor Jimmy Swaggart (EXP).bbl.mybible",
    "Palavra Chave [ARC].bbl.mybible": "Bíblia de Estudo Palavra-Chave ARC (BEPC).bbl.mybible",
    "Thompsonbr.bbl.mybible": "Bíblia de Referência Thompson em Português (THOMPSON).bbl.mybible",
    "Nvtmulher.bbl.mybible": "Bíblia de Estudo Desafios de Todo Homem e Mulher (NVT).bbl.mybible",
    "Nva Estudos Vbeta2.bbl.mybible": "Nova Versão de Acesso Livre - Estudo (NVA).bbl.mybible",

    # Versões Modernas e Tradicionais
    "Amp (ampliada).bbl.mybible": "Bíblia Amplificada (AMP).bbl.mybible",
    "Biblia0 Msg Amensagem.bbl.mybible": "A Mensagem (MSG).bbl.mybible",
    "Biblialivre.bbl.mybible": "Bíblia Livre (BLIVRE).bbl.mybible",
    "Bpt Bíblia Para Todos.bbl.mybible": "A Bíblia para Todos (BPT).bbl.mybible",
    "Btx (bíblia Textual).bbl.mybible": "Bíblia Textual (BTX).bbl.mybible",
    "Edição Pastoral.bbl.mybible": "Bíblia Edição Pastoral (EP).bbl.mybible",
    "Past (pastoral).bbl.mybible": "Bíblia Sagrada Edição Pastoral com Notas (EP).bbl.mybible",
    "La (linguagem Atual).bbl.mybible": "Bíblia na Linguagem Atual (LA).bbl.mybible",
    "[NTLH] (linguagem De Hoje).bbl.mybible": "Nova Tradução na Linguagem de Hoje (NTLH).bbl.mybible",
    "[NVI].bbl.mybible": "Nova Versão Internacional (NVI).bbl.mybible",
    "[NVT] (nova Versão Transformadora).bbl.mybible": "Nova Versão Transformadora (NVT).bbl.mybible",
    "Ol (o Livro).bbl.mybible": "O Livro - Bíblia para Hoje (OL).bbl.mybible",
    "Tb (tradução Brasileira Edição 2010).bbl.mybible": "Tradução Brasileira Edição 2010 (TB).bbl.mybible",
    "Vfl (versão Fácil De Ler).bbl.mybible": "Versão Fácil de Ler (VFL).bbl.mybible",
    "Viva.bbl.mybible": "Bíblia Viva (VIVA).bbl.mybible",

    # King James
    "[KJA] (king James Atualizada).bbl.mybible": "King James Atualizada (KJA).bbl.mybible",
    "[KJA] C Notas Novo Testamento.bbl.mybible": "King James Atualizada com Notas do NT (KJA).bbl.mybible",
    "Kj Fiel (king James Fiel 1611).bbl.mybible": "King James Fiel 1611 (KJF).bbl.mybible",

    # Católicas / Com Apócrifos
    "5catolicas.bbl.mybible": "Bíblia Comparativa 5 Católicas (5CAT).bbl.mybible",
    "7versões.bbl.mybible": "Bíblia Paralela 7 Versões (7VER).bbl.mybible",
    "Ave Maria Notas.bbl.mybible": "Bíblia Ave Maria com Notas (AVM).bbl.mybible",
    "Bj N (bíblia De Jerusálem Com Notas).bbl.mybible": "Bíblia de Jerusalém com Notas (BJ).bbl.mybible",
    "Bjp.bbl.mybible": "Bíblia de Jerusalém Edição Pastoral (BJP).bbl.mybible",
    "Bpf (biblia Do Padre Antonio Pereira De Figueiredo).bbl.mybible": "Bíblia Padre Antonio Pereira de Figueiredo (BPF).bbl.mybible",
    "Catolica.bbl.mybible": "Bíblia Católica com Livros Deuterocanônicos (CAT).bbl.mybible",
    "Cnbb.bbl.mybible": "Bíblia Pastoral da CNBB (CNBB).bbl.mybible",

    # Hebraico / Aramaico / Judaica
    "Bh (biblia Hebraica Sefer).bbl.mybible": "Bíblia Hebraica Sefer (BH).bbl.mybible",
    "Bhs Sttutigardense.bbl.mybible": "Biblia Hebraica Stuttgartensia (BHS).bbl.mybible",
    "Bijn (biblia Israelita Judaica Nazarena).bbl.mybible": "Bíblia Israelita Judaica Nazarena (BIJN).bbl.mybible",
    "Ehr (escritura Hebraica Restaurada).bbl.mybible": "Escritura Hebraica Restaurada (EHR).bbl.mybible",
    "Hisb.bbl.mybible": "Bíblia Hebraica Interlinear HiSB (HiSB).bbl.mybible",
    "Hsb.bbl.mybible": "Hebrew Study Bible Interlinear (HSB).bbl.mybible",
    "Novo Testamento Hebraico.bbl.mybible": "Novo Testamento em Hebraico (NTH).bbl.mybible",
    "Novo Testamento Paralelo Hebraico Interlinear V0001.bbl.mybible": "Novo Testamento Hebraico Interlinear (NTH-INT).bbl.mybible",
    "Ntj (novo Testamento Judaico).bbl.mybible": "Novo Testamento Judaico David Stern (NTJ).bbl.mybible",
    "Psh (biblia Peshitta).bbl.mybible": "Bíblia Sagrada Peshitta Aramaica (PSH).bbl.mybible",
    "Tanakh.bbl.mybible": "Tanakh - Bíblia Hebraica Completa (TANAKH).bbl.mybible",
    "Trg (targum De Jesusalem).bbl.mybible": "Targum de Jerusalém Aramaico (TRG).bbl.mybible",
    "Whm.bbl.mybible": "Westminster Hebrew Morphology - AT Hebraico (WHM).bbl.mybible",

    # Grego / Originais / Interlinear
    "Bl N4 (texto Critico Nestle 1904).bbl.mybible": "Bíblia Livre com Texto Crítico Nestlé 1904 (BL-N4).bbl.mybible",
    "Bl Tr (texto Recebido).bbl.mybible": "Bíblia Livre com Textus Receptus (BL-TR).bbl.mybible",
    "Byz2005.bbl.mybible": "Novo Testamento Grego Bizantino 2005 (BYZ).bbl.mybible",
    "F35 Gism (família 35).bbl.mybible": "Novo Testamento Família 35 Grego Interlinear (F35).bbl.mybible",
    "F35 Ntn (f35 Texto Português Com Notas).bbl.mybible": "Novo Testamento Família 35 com Notas em Português (F35).bbl.mybible",
    "Gr En Bib Berean.bbl.mybible": "Bíblia Interlinear Grego-Inglês Berean (BIB).bbl.mybible",
    "Gr Na28 Koine.bbl.mybible": "Novo Testamento Grego Nestlé-Aland 28 (NA28).bbl.mybible",
    "Grego (tr).bbl.mybible": "Novo Testamento Grego Textus Receptus Stephanus (TR).bbl.mybible",
    "Hebraico E Grego Interlinear E Trasnliterado.bbl.mybible": "Antigo e Novo Testamento Interlinear e Transliterado (INT).bbl.mybible",
    "Lxx (septuaginta).bbl.mybible": "Septuaginta Grega do Antigo Testamento (LXX).bbl.mybible",
    "Nt2 F35 Wp.bbl.mybible": "Novo Testamento Família 35 Wilbur Pickering (F35-WP).bbl.mybible",
    "Nt2ftrans (2ª Transliterado).bbl.mybible": "Novo Testamento 2ª Edição Transliterada (NT2TRANS).bbl.mybible",
    "Nt3ftrans (3ª Transliterado).bbl.mybible": "Novo Testamento 3ª Edição Transliterada (NT3TRANS).bbl.mybible",
    "Open Gntotal.bbl.mybible": "Open Greek New Testament com Anotações (OGNT).bbl.mybible",
    "Open Hb Vt Novo Testamento Br Gram Trans.bbl.mybible": "Bíblia Interlinear Hebraico e Grego com Gramática (INT-GR).bbl.mybible",
    "Opengnt Br.bbl.mybible": "Open Greek New Testament Interlinear em Português (OGNT).bbl.mybible",
    "Variantes.bbl.mybible": "Novo Testamento Grego com Variantes Textuais (GNT-VAR).bbl.mybible",

    # Literais e Outras
    "Ltt 2009 (literal 2009).bbl.mybible": "Bíblia Literal do Texto Tradicional 2009 (LTT).bbl.mybible",
    "Ltt 2015 (literal 2015).bbl.mybible": "Bíblia Literal do Texto Tradicional 2015 (LTT).bbl.mybible",
    "Ltt 2018 (hélio Menezes).bbl.mybible": "Bíblia Literal do Texto Tradicional 2018 Hélio de Menezes (LTT).bbl.mybible",
    "Rvp (reina Valera Português).bbl.mybible": "Reina-Valera em Português (RVP).bbl.mybible",
    "Tnm 1986 (tradução Do Novo Mundo 1986).bbl.mybible": "Tradução do Novo Mundo 1986 (TNM).bbl.mybible",
    "Tnm 2015 (tradução Do Novo Mundo 2015).bbl.mybible": "Tradução do Novo Mundo Revisada 2015 (TNM).bbl.mybible",
}

def run():
    print("="*65)
    print(" ORGANIZAÇÃO E PADRONIZAÇÃO DE NOMES DAS BÍBLIAS")
    print("="*65)

    os.makedirs(DUPES_DIR, exist_ok=True)

    # 1. Mover duplicatas para Duplicados_Removidos
    print("\n[1/3] Movendo duplicatas redundantes para Duplicados_Removidos/...")
    removed_dupes = []
    for dup, canon in BIBLE_DUPLICATES:
        src = os.path.join(BIBLES_DIR, dup)
        dst = os.path.join(DUPES_DIR, dup)
        if os.path.exists(src):
            shutil.move(src, dst)
            print(f"  ✓ Isolado: {dup} -> Duplicados_Removidos/ (Mantido: {canon})")
            removed_dupes.append(dup)
        else:
            print(f"  - Já não existe em Biblias: {dup}")

    # 2. Renomear arquivos para Nome Real (SIGLA)
    print("\n[2/3] Renomeando arquivos para nomes reais limpos (com sigla no final)...")
    renamed_count = 0
    rename_audit = {}  # old_name -> new_name

    for old_name, new_name in RENAME_MAP.items():
        src = os.path.join(BIBLES_DIR, old_name)
        dst = os.path.join(BIBLES_DIR, new_name)

        if os.path.exists(src) and old_name != new_name:
            if os.path.exists(dst):
                print(f"  ⚠️ Destino já existe: {new_name}")
            else:
                shutil.move(src, dst)
                print(f"  ✓ {old_name}\n     ➔ {new_name}")
                renamed_count += 1
                rename_audit[old_name] = new_name

    # 3. Atualizar loja_keryx.json e bancos SQLite
    print("\n[3/3] Sincronizando catálogo loja_keryx.json e bancos SQLite...")
    dupes_set = set(removed_dupes)

    if os.path.exists(LOJA_JSON):
        with open(LOJA_JSON, "r", encoding="utf-8") as f:
            items = json.load(f)

        new_items = []
        for it in items:
            fn = it.get("nome_arquivo", "")
            if fn in dupes_set:
                continue

            if fn in rename_audit:
                new_fn = rename_audit[fn]
                it["nome_arquivo"] = new_fn
                it["id"] = new_fn
                it["titulo"] = new_fn.replace(".bbl.mybible", "")
                if "download_url" in it:
                    it["download_url"] = it["download_url"].rsplit("/", 1)[0] + "/" + new_fn

            new_items.append(it)

        with open(LOJA_JSON, "w", encoding="utf-8") as f:
            json.dump(new_items, f, ensure_ascii=False, indent=2)
        print(f"  ✓ loja_keryx.json atualizado: {len(removed_dupes)} duplicatas removidas, {renamed_count} renomeados. Total final: {len(new_items)} itens.")

    # Atualizar SQLite
    for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
        if os.path.exists(db_path):
            conn = sqlite3.connect(db_path)
            cur = conn.cursor()

            for dup in removed_dupes:
                cur.execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (dup, dup))

            for old_fn, new_fn in rename_audit.items():
                new_title = new_fn.replace(".bbl.mybible", "")
                cur.execute("""
                    UPDATE loja
                    SET id = ?,
                        nome_arquivo = ?,
                        titulo = ?
                    WHERE nome_arquivo = ? OR id = ?;
                """, (new_fn, new_fn, new_title, old_fn, old_fn))

            conn.commit()
            total = cur.execute("SELECT count(*) FROM loja;").fetchone()[0]
            conn.close()
            print(f"  ✓ Banco sincronizado: {db_path} (Total itens: {total})")

    print("\n🎉 Limpeza e renomeação das Bíblias concluída com sucesso!")

if __name__ == "__main__":
    run()
