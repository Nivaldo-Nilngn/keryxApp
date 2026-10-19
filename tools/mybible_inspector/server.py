#!/usr/bin/env python3
import http.server
import socketserver
import os
import json
import sqlite3
import urllib.parse
import re
import hashlib
from collections import defaultdict

PORT = 5055
BASE_DIR = "/home/nivaldo/Área de trabalho/B2_Downloads"
DICT_DIR = os.path.join(BASE_DIR, "Dicionarios")
BOOKS_DIR = os.path.join(BASE_DIR, "Livros")
COMMENTS_DIR = os.path.join(BASE_DIR, "Comentarios")
BIBLES_DIR = os.path.join(BASE_DIR, "Biblias")
DUPES_DIR = os.path.join(BASE_DIR, "Duplicados_Removidos")

CLASSIFICATION_FILE = os.path.join(BASE_DIR, "classificacao_modulos.json")
LOJA_JSON_FILE = os.path.join(BASE_DIR, "loja_keryx.json")
LOJA_DB_B2 = os.path.join(BASE_DIR, "loja_keryx.db")
LOJA_DB_APP = "/home/nivaldo/Área de trabalho/Biblia/assets/data/loja_keryx.db"

LAST_OPENED_FILE = None
LAST_OPENED_CATEGORY = "comentarios"

BIBLE_BOOKS = {
    1: "Gênesis", 2: "Êxodo", 3: "Levítico", 4: "Números", 5: "Deuteronômio",
    6: "Josué", 7: "Juízes", 8: "Rute", 9: "1 Samuel", 10: "2 Samuel",
    11: "1 Reis", 12: "2 Reis", 13: "1 Crônicas", 14: "2 Crônicas", 15: "Esdras",
    16: "Neemias", 17: "Ester", 18: "Jó", 19: "Salmos", 20: "Provérbios",
    21: "Eclesiastes", 22: "Cantares", 23: "Isaías", 24: "Jeremias", 25: "Lamentações",
    26: "Ezequiel", 27: "Daniel", 28: "Oseias", 29: "Joel", 30: "Amós",
    31: "Obadias", 32: "Jonas", 33: "Miqueias", 34: "Naum", 35: "Habacuque",
    36: "Sofonias", 37: "Ageu", 38: "Zacarias", 39: "Malaquias",
    40: "Mateus", 41: "Marcos", 42: "Lucas", 43: "João", 44: "Atos",
    45: "Romanos", 46: "1 Coríntios", 47: "2 Coríntios", 48: "Gálatas", 49: "Efésios",
    50: "Filipenses", 51: "Colossenses", 52: "1 Tessalonicenses", 53: "2 Tessalonicenses",
    54: "1 Timóteo", 55: "2 Timóteo", 56: "Tito", 57: "Filemom", 58: "Hebreus",
    59: "Tiago", 60: "1 Pedro", 61: "2 Pedro", 62: "1 João", 63: "2 João",
    64: "3 João", 65: "Judas", 66: "Apocalipse"
}

def load_classifications():
    if os.path.exists(CLASSIFICATION_FILE):
        try:
            with open(CLASSIFICATION_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_classifications(data):
    with open(CLASSIFICATION_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_commentary_table(tables):
    for t in ["commentary", "Commentary", "moody1"]:
        if t in tables:
            return t
    return None

def get_details_table(tables):
    for t in ["details", "Details", "info"]:
        if t in tables:
            return t
    return None

def get_commentary_summary(filepath):
    filename = os.path.basename(filepath)
    sz = os.path.getsize(filepath)
    size_mb = round(sz / (1024 * 1024), 2)
    
    if sz == 0:
        return {
            "filename": filename,
            "category": "comentarios",
            "title": filename,
            "author": "",
            "description": "Arquivo vazio (0 bytes)",
            "size_mb": 0,
            "total_entries": 0,
            "books_count": 0,
            "books_list": [],
            "suggested_type": "empty",
            "suggested_reason": "Arquivo vazio (0 bytes) - corrompido",
            "sample_words": []
        }

    conn = sqlite3.connect(filepath)
    cur = conn.cursor()
    tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
    c_table = get_commentary_table(tables)

    if not c_table:
        conn.close()
        return {
            "filename": filename,
            "category": "comentarios",
            "title": filename,
            "author": "",
            "description": f"Sem tabela de comentários (tabelas: {tables})",
            "size_mb": size_mb,
            "total_entries": 0,
            "books_count": 0,
            "books_list": [],
            "suggested_type": "error",
            "suggested_reason": "Sem tabela commentary",
            "sample_words": []
        }

    total = cur.execute(f'SELECT count(*) FROM "{c_table}";').fetchone()[0]

    # Details
    details = {"title": filename.replace(".cmt.mybible", ""), "author": "", "description": ""}
    dt = get_details_table(tables)
    if dt:
        try:
            dcols = [c[1].lower() for c in cur.execute(f'PRAGMA table_info("{dt}");').fetchall()]
            r = cur.execute(f'SELECT * FROM "{dt}" LIMIT 1;').fetchone()
            if r:
                rd = dict(zip(dcols, r))
                details["title"] = rd.get("title") or rd.get("description") or details["title"]
                details["author"] = rd.get("author") or rd.get("creator") or ""
                details["description"] = rd.get("description") or ""
        except Exception:
            pass

    # Books list
    book_rows = cur.execute(f'SELECT book, count(*) FROM "{c_table}" WHERE book IS NOT NULL GROUP BY book ORDER BY book;').fetchall()
    books_list = [
        {"id": b[0], "name": BIBLE_BOOKS.get(b[0], f"Livro {b[0]}"), "count": b[1]}
        for b in book_rows
    ]
    books_count = len(books_list)

    # Sample entries for display
    sample_rows = cur.execute(f'SELECT book, chapter, fromverse, toverse FROM "{c_table}" LIMIT 10;').fetchall()
    sample_words = []
    for sr in sample_rows:
        b_name = BIBLE_BOOKS.get(sr[0], f"Livro {sr[0]}")
        sample_words.append(f"{b_name} {sr[1]}:{sr[2]}")

    conn.close()

    # Heuristics
    suggested_type = "commentary"
    reason = "Comentário Bíblico"
    if books_count >= 50:
        suggested_type = "full_bible"
        reason = f"Bíblia Completa ({books_count} livros comentados)"
    elif books_count >= 15 and all(b["id"] >= 40 for b in books_list):
        suggested_type = "nt"
        reason = f"Novo Testamento ({books_count} livros comentados)"
    elif books_count >= 20 and all(b["id"] <= 39 for b in books_list):
        suggested_type = "ot"
        reason = f"Antigo Testamento ({books_count} livros comentados)"
    elif books_count <= 2:
        b_name = books_list[0]["name"] if books_list else ""
        suggested_type = "monograph"
        reason = f"Monografia / Livro Único ({b_name})"

    return {
        "filename": filename,
        "category": "comentarios",
        "title": details["title"],
        "author": details["author"],
        "description": details["description"],
        "size_mb": size_mb,
        "total_entries": total,
        "books_count": books_count,
        "books_list": books_list,
        "suggested_type": suggested_type,
        "suggested_reason": reason,
        "sample_words": sample_words[:6]
    }

def get_dict_summary(filepath, is_book=False):
    filename = os.path.basename(filepath)
    size_mb = round(os.path.getsize(filepath) / (1024 * 1024), 2)
    conn = sqlite3.connect(filepath)
    cur = conn.cursor()

    details = {"title": filename.replace(".dct.mybible", ""), "author": "", "description": ""}
    try:
        r = cur.execute("SELECT title, author, description FROM details;").fetchone()
        if r:
            details["title"] = r[0] or details["title"]
            details["author"] = r[1] or ""
            details["description"] = r[2] or ""
    except Exception:
        pass

    cols = [c[1] for c in cur.execute("PRAGMA table_info(dictionary);").fetchall()]
    has_relorder = "relativeorder" in cols
    total = cur.execute("SELECT count(*) FROM dictionary;").fetchone()[0]

    if has_relorder:
        sample_rows = cur.execute("SELECT word FROM dictionary ORDER BY relativeorder LIMIT 20;").fetchall()
    else:
        sample_rows = cur.execute("SELECT word FROM dictionary LIMIT 20;").fetchall()
    sample_words = [str(r[0]) for r in sample_rows]

    conn.close()

    suggested_type = "book" if is_book else "dict"
    reason = "Livro / Tratado Teológico" if is_book else "Dicionário de Verbetes A-Z"

    return {
        "filename": filename,
        "category": "livros" if is_book else "dicionarios",
        "title": details["title"],
        "author": details["author"],
        "description": details["description"],
        "size_mb": size_mb,
        "total_entries": total,
        "has_relorder": has_relorder,
        "sample_words": sample_words[:6],
        "suggested_type": suggested_type,
        "suggested_reason": reason,
    }

class MyBibleHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        global LAST_OPENED_FILE, LAST_OPENED_CATEGORY
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        query = urllib.parse.parse_qs(parsed.query)

        if path == "/api/modules":
            category = query.get("category", ["comentarios"])[0].lower()
            self.handle_api_modules(category)
        elif path == "/api/module_details":
            filename = query.get("file", [""])[0]
            category = query.get("category", [""])[0]
            if filename:
                LAST_OPENED_FILE = filename
            self.handle_api_module_details(filename, category)
        elif path == "/api/entry":
            filename = query.get("file", [""])[0]
            if filename:
                LAST_OPENED_FILE = filename
            category = query.get("category", [""])[0]
            book = query.get("book", [None])[0]
            chapter = query.get("chapter", [None])[0]
            verse = query.get("verse", [None])[0]
            rowid = query.get("rowid", [None])[0]
            idx = int(query.get("index", ["0"])[0])
            word = query.get("word", [None])[0]
            self.handle_api_entry(filename, category, idx, word, book, chapter, verse, rowid)
        elif path == "/api/image":
            filename = query.get("file", [LAST_OPENED_FILE])[0]
            img_name = query.get("name", [""])[0]
            self.handle_api_image(filename, img_name)
        elif path == "/" or path == "/index.html":
            html_path = os.path.join(os.path.dirname(__file__), "index.html")
            if os.path.exists(html_path):
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.end_headers()
                with open(html_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404, "index.html not found")
        elif re.search(r"\.(jpe?g|png|gif|webp|bmp)$", path, re.I):
            img_name = os.path.basename(path)
            self.handle_api_image(LAST_OPENED_FILE, img_name)
        else:
            super().do_GET()

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length > 0 else b"{}"
        try:
            payload = json.loads(body.decode("utf-8"))
        except Exception:
            payload = {}

        if path == "/api/classify":
            self.handle_api_classify(payload)
        elif path == "/api/action":
            self.handle_api_action(payload)
        elif path == "/api/apply_to_loja":
            self.handle_api_apply_to_loja(payload)
        else:
            self.send_error(404, "Endpoint not found")

    def find_file_path(self, filename, category=None):
        search_dirs = []
        if category == "comentarios":
            search_dirs = [COMMENTS_DIR, BOOKS_DIR, DUPES_DIR]
        elif category == "dicionarios":
            search_dirs = [DICT_DIR, BOOKS_DIR, DUPES_DIR]
        elif category == "livros":
            search_dirs = [BOOKS_DIR, DICT_DIR, COMMENTS_DIR, DUPES_DIR]
        elif category == "biblias":
            search_dirs = [BIBLES_DIR, DUPES_DIR]
        else:
            search_dirs = [COMMENTS_DIR, DICT_DIR, BOOKS_DIR, BIBLES_DIR, DUPES_DIR]

        for d in search_dirs:
            fp = os.path.join(d, filename)
            if os.path.exists(fp):
                return fp
        return None

    def handle_api_image(self, filename, img_name):
        if not img_name:
            self.send_error(404, "Image name required")
            return

        search_dirs = [COMMENTS_DIR, DICT_DIR, BOOKS_DIR, BIBLES_DIR]
        content = None

        if filename:
            fp = self.find_file_path(filename)
            if fp:
                try:
                    conn = sqlite3.connect(fp)
                    cur = conn.cursor()
                    row = cur.execute("SELECT content FROM data WHERE id = ? OR filename = ? LIMIT 1;", (img_name, img_name)).fetchone()
                    conn.close()
                    if row and row[0]:
                        content = row[0]
                except Exception:
                    pass

        if not content:
            # Fallback search
            for d in [COMMENTS_DIR, DICT_DIR]:
                for fn in os.listdir(d):
                    fp = os.path.join(d, fn)
                    try:
                        conn = sqlite3.connect(fp)
                        row = conn.cursor().execute("SELECT content FROM data WHERE id = ? OR filename = ? LIMIT 1;", (img_name, img_name)).fetchone()
                        conn.close()
                        if row and row[0]:
                            content = row[0]
                            break
                    except Exception:
                        pass
                if content:
                    break

        if content:
            content_type = "image/jpeg"
            if img_name.lower().endswith(".png"):
                content_type = "image/png"
            elif img_name.lower().endswith(".gif"):
                content_type = "image/gif"
            elif img_name.lower().endswith(".webp"):
                content_type = "image/webp"

            self.send_response(200)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "public, max-age=86400")
            self.end_headers()
            self.wfile.write(content)
        else:
            self.send_error(404, f"Image {img_name} not found")

    def handle_api_modules(self, category="comentarios"):
        modules = []
        classifications = load_classifications()

        if category == "comentarios":
            files = sorted([f for f in os.listdir(COMMENTS_DIR) if f.endswith(".cmt.mybible")], key=lambda s: s.lower())
            
            # Find duplicate hashes
            titles_seen = {}
            for f in files:
                fp = os.path.join(COMMENTS_DIR, f)
                if not os.path.exists(fp):
                    continue
                try:
                    mod = get_commentary_summary(fp)
                    user_c = classifications.get(f, {})
                    mod["user_category"] = user_c.get("category", "")
                    mod["user_notes"] = user_c.get("notes", "")

                    norm_title = re.sub(r"[^a-zA-Z0-9áéíóúãõâêîôûç]", "", mod["title"].lower())
                    if norm_title in titles_seen:
                        mod["is_duplicate_of"] = titles_seen[norm_title]
                    else:
                        titles_seen[norm_title] = f

                    modules.append(mod)
                except Exception as e:
                    sz = round(os.path.getsize(fp) / (1024*1024), 2) if os.path.exists(fp) else 0
                    modules.append({
                        "filename": f,
                        "category": "comentarios",
                        "title": f,
                        "error": str(e),
                        "size_mb": sz,
                        "suggested_type": "error"
                    })

        elif category == "dicionarios":
            files = sorted([f for f in os.listdir(DICT_DIR) if f.endswith(".dct.mybible")], key=lambda s: s.lower())
            for f in files:
                fp = os.path.join(DICT_DIR, f)
                if not os.path.exists(fp):
                    continue
                try:
                    mod = get_dict_summary(fp, is_book=False)
                    user_c = classifications.get(f, {})
                    mod["user_category"] = user_c.get("category", "")
                    mod["user_notes"] = user_c.get("notes", "")
                    modules.append(mod)
                except Exception as e:
                    modules.append({"filename": f, "category": "dicionarios", "title": f, "error": str(e)})

        elif category == "livros":
            files = sorted([f for f in os.listdir(BOOKS_DIR) if f.endswith(".mybible") or f.endswith(".sqlite3")], key=lambda s: s.lower())
            for f in files:
                fp = os.path.join(BOOKS_DIR, f)
                if not os.path.exists(fp):
                    continue
                try:
                    mod = get_dict_summary(fp, is_book=True)
                    user_c = classifications.get(f, {})
                    mod["user_category"] = user_c.get("category", "")
                    mod["user_notes"] = user_c.get("notes", "")
                    modules.append(mod)
                except Exception as e:
                    modules.append({"filename": f, "category": "livros", "title": f, "error": str(e)})

        elif category == "biblias":
            files = sorted([f for f in os.listdir(BIBLES_DIR) if f.endswith(".bbl.mybible")], key=lambda s: s.lower())
            for f in files:
                fp = os.path.join(BIBLES_DIR, f)
                if not os.path.exists(fp):
                    continue
                sz_mb = round(os.path.getsize(fp) / (1024*1024), 2)
                modules.append({
                    "filename": f,
                    "category": "biblias",
                    "title": f.replace(".bbl.mybible", ""),
                    "size_mb": sz_mb,
                    "suggested_type": "bible",
                    "suggested_reason": "Bíblia Sagrada"
                })

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(modules, ensure_ascii=False).encode("utf-8"))

    def handle_api_module_details(self, filename, category=None):
        filepath = self.find_file_path(filename, category)
        if not filepath:
            self.send_error(404, "File not found")
            return

        conn = sqlite3.connect(filepath)
        cur = conn.cursor()
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
        c_table = get_commentary_table(tables)

        details = {"title": filename, "author": "", "description": "", "customcss": ""}
        dt = get_details_table(tables)
        if dt:
            try:
                dcols = [c[1].lower() for c in cur.execute(f'PRAGMA table_info("{dt}");').fetchall()]
                r = cur.execute(f'SELECT * FROM "{dt}" LIMIT 1;').fetchone()
                if r:
                    rd = dict(zip(dcols, r))
                    details["title"] = rd.get("title") or rd.get("description") or details["title"]
                    details["author"] = rd.get("author") or rd.get("creator") or ""
                    details["description"] = rd.get("description") or ""
                    details["customcss"] = rd.get("customcss") or ""
            except Exception:
                pass

        if c_table:
            # It's a commentary!
            book_rows = cur.execute(f'SELECT book, count(*) FROM "{c_table}" WHERE book IS NOT NULL GROUP BY book ORDER BY book;').fetchall()
            books_list = [
                {"id": b[0], "name": BIBLE_BOOKS.get(b[0], f"Livro {b[0]}"), "count": b[1]}
                for b in book_rows
            ]

            # Return list of entries for first book, or overview
            first_book = books_list[0]["id"] if books_list else 1
            entry_rows = cur.execute(f'SELECT rowid, book, chapter, fromverse, toverse, length(data) FROM "{c_table}" ORDER BY book, chapter, fromverse LIMIT 200;').fetchall()
            entries = []
            for i, r in enumerate(entry_rows):
                b_name = BIBLE_BOOKS.get(r[1], f"Livro {r[1]}")
                verse_str = f"{r[3]}" if r[3] == r[4] or r[4] == 0 else f"{r[3]}-{r[4]}"
                word = f"{b_name} {r[2]}:{verse_str}"
                entries.append({
                    "index": i,
                    "rowid": r[0],
                    "book": r[1],
                    "chapter": r[2],
                    "fromverse": r[3],
                    "toverse": r[4],
                    "word": word,
                    "size": r[5]
                })

            total_entries = cur.execute(f'SELECT count(*) FROM "{c_table}";').fetchone()[0]
            conn.close()

            res = {
                "filename": filename,
                "type": "commentary",
                "details": details,
                "books": books_list,
                "total_entries": total_entries,
                "entries": entries,
            }

        elif "dictionary" in tables:
            # It's a dictionary / book
            cols = [c[1] for c in cur.execute("PRAGMA table_info(dictionary);").fetchall()]
            has_relorder = "relativeorder" in cols
            order_clause = "ORDER BY relativeorder ASC" if has_relorder else "ORDER BY rowid ASC"
            rows = cur.execute(f"SELECT rowid, word, length(data) FROM dictionary {order_clause} LIMIT 2000;").fetchall()
            entries = [{"index": i, "rowid": r[0], "word": str(r[1]), "size": r[2]} for i, r in enumerate(rows)]
            total = cur.execute("SELECT count(*) FROM dictionary;").fetchone()[0]
            conn.close()

            res = {
                "filename": filename,
                "type": "dictionary",
                "details": details,
                "total_entries": total,
                "entries": entries,
            }
        else:
            conn.close()
            res = {"filename": filename, "type": "unknown", "details": details, "total_entries": 0, "entries": []}

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))

    def handle_api_entry(self, filename, category, idx, word=None, book=None, chapter=None, verse=None, rowid=None):
        filepath = self.find_file_path(filename, category)
        if not filepath:
            self.send_error(404, "File not found")
            return

        conn = sqlite3.connect(filepath)
        cur = conn.cursor()
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table';").fetchall()]
        c_table = get_commentary_table(tables)

        if c_table:
            # Query commentary
            if rowid:
                row = cur.execute(f'SELECT rowid, book, chapter, fromverse, toverse, data FROM "{c_table}" WHERE rowid = ?;', (rowid,)).fetchone()
            elif book is not None and chapter is not None and verse is not None:
                row = cur.execute(f'SELECT rowid, book, chapter, fromverse, toverse, data FROM "{c_table}" WHERE book = ? AND chapter = ? AND fromverse = ? LIMIT 1;', (book, chapter, verse)).fetchone()
            else:
                row = cur.execute(f'SELECT rowid, book, chapter, fromverse, toverse, data FROM "{c_table}" ORDER BY book, chapter, fromverse LIMIT 1 OFFSET ?;', (idx,)).fetchone()

            total = cur.execute(f'SELECT count(*) FROM "{c_table}";').fetchone()[0]
            conn.close()

            if not row:
                self.send_error(404, "Commentary entry not found")
                return

            b_name = BIBLE_BOOKS.get(row[1], f"Livro {row[1]}")
            verse_str = f"{row[3]}" if row[3] == row[4] or row[4] == 0 else f"{row[3]}-{row[4]}"
            entry_title = f"{b_name} {row[2]}:{verse_str}"
            raw_content = row[5] or ""

        elif "dictionary" in tables:
            cols = [c[1] for c in cur.execute("PRAGMA table_info(dictionary);").fetchall()]
            has_relorder = "relativeorder" in cols
            order_clause = "ORDER BY relativeorder ASC" if has_relorder else "ORDER BY rowid ASC"
            total = cur.execute("SELECT count(*) FROM dictionary;").fetchone()[0]

            if word:
                row = cur.execute("SELECT rowid, word, data FROM dictionary WHERE word = ? LIMIT 1;", (word,)).fetchone()
                if not row:
                    row = cur.execute("SELECT rowid, word, data FROM dictionary WHERE word LIKE ? LIMIT 1;", (f"%{word}%",)).fetchone()
            else:
                if idx < 0: idx = 0
                if idx >= total: idx = total - 1
                row = cur.execute(f"SELECT rowid, word, data FROM dictionary {order_clause} LIMIT 1 OFFSET ?;", (idx,)).fetchone()

            conn.close()
            if not row:
                self.send_error(404, "Dictionary entry not found")
                return

            entry_title = str(row[1])
            raw_content = row[2] or ""
        else:
            conn.close()
            self.send_error(404, "Unsupported module schema")
            return

        def rewrite_img(match):
            img_src = match.group(1)
            if not img_src.startswith("http") and not img_src.startswith("/api/"):
                enc_f = urllib.parse.quote(filename)
                enc_n = urllib.parse.quote(img_src)
                return f'src="/api/image?file={enc_f}&name={enc_n}"'
            return match.group(0)

        cleaned_content = re.sub(r'src=["\']([^"\']+)["\']', rewrite_img, raw_content)

        res = {
            "filename": filename,
            "index": idx,
            "total": total,
            "has_prev": idx > 0,
            "has_next": idx < total - 1,
            "word": entry_title,
            "content": cleaned_content,
        }

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(res, ensure_ascii=False).encode("utf-8"))

    def handle_api_classify(self, payload):
        filename = payload.get("filename")
        category = payload.get("category")
        notes = payload.get("notes", "")

        if not filename or not category:
            self.send_error(400, "Missing filename or category")
            return

        data = load_classifications()
        data[filename] = {"category": category, "notes": notes}
        save_classifications(data)

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps({"success": True, "saved": data[filename]}).encode("utf-8"))

    def handle_api_action(self, payload):
        action = payload.get("action")
        filename = payload.get("filename")
        if not action or not filename:
            self.send_error(400, "Action and filename required")
            return

        os.makedirs(DUPES_DIR, exist_ok=True)
        os.makedirs(BOOKS_DIR, exist_ok=True)

        src = self.find_file_path(filename)
        if not src:
            self.send_error(404, f"File {filename} not found")
            return

        result = {"success": True, "action": action, "filename": filename}

        if action == "move_to_duplicates":
            dst = os.path.join(DUPES_DIR, filename)
            shutil.move(src, dst)
            result["message"] = f"Arquivo isolado em Duplicados_Removidos/"
            # update loja_keryx.json
            self.remove_from_loja(filename)

        elif action == "move_to_books":
            dst = os.path.join(BOOKS_DIR, filename)
            shutil.move(src, dst)
            result["message"] = f"Arquivo movido para Livros/"
            self.update_loja_category(filename, "Livros")

        elif action == "delete_empty":
            if os.path.getsize(src) == 0:
                os.remove(src)
                result["message"] = f"Arquivo vazio de 0 bytes excluído."
                self.remove_from_loja(filename)
            else:
                dst = os.path.join(DUPES_DIR, filename)
                shutil.move(src, dst)
                result["message"] = f"Arquivo movido para Duplicados_Removidos/."
                self.remove_from_loja(filename)

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))

    def remove_from_loja(self, filename):
        if os.path.exists(LOJA_JSON_FILE):
            try:
                with open(LOJA_JSON_FILE, "r", encoding="utf-8") as f:
                    items = json.load(f)
                items = [it for it in items if it.get("nome_arquivo") != filename and it.get("id") != filename]
                with open(LOJA_JSON_FILE, "w", encoding="utf-8") as f:
                    json.dump(items, f, ensure_ascii=False, indent=2)
            except Exception:
                pass

        for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
            if os.path.exists(db_path):
                try:
                    conn = sqlite3.connect(db_path)
                    conn.cursor().execute("DELETE FROM loja WHERE nome_arquivo = ? OR id = ?;", (filename, filename))
                    conn.commit()
                    conn.close()
                except Exception:
                    pass

    def update_loja_category(self, filename, new_category):
        if os.path.exists(LOJA_JSON_FILE):
            try:
                with open(LOJA_JSON_FILE, "r", encoding="utf-8") as f:
                    items = json.load(f)
                for it in items:
                    if it.get("nome_arquivo") == filename or it.get("id") == filename:
                        it["categoria"] = new_category
                with open(LOJA_JSON_FILE, "w", encoding="utf-8") as f:
                    json.dump(items, f, ensure_ascii=False, indent=2)
            except Exception:
                pass

        for db_path in [LOJA_DB_B2, LOJA_DB_APP]:
            if os.path.exists(db_path):
                try:
                    conn = sqlite3.connect(db_path)
                    conn.cursor().execute("UPDATE loja SET categoria = ? WHERE nome_arquivo = ? OR id = ?;", (new_category, filename, filename))
                    conn.commit()
                    conn.close()
                except Exception:
                    pass

    def handle_api_apply_to_loja(self, payload):
        if not os.path.exists(LOJA_JSON_FILE):
            self.send_error(404, "loja_keryx.json not found")
            return

        classifications = load_classifications()
        with open(LOJA_JSON_FILE, "r", encoding="utf-8") as f:
            loja_items = json.load(f)

        updated_count = 0
        for item in loja_items:
            fname = item.get("nome_arquivo", "")
            if fname in classifications:
                cat = classifications[fname].get("category")
                if cat == "book" and item.get("categoria") in ["Dicionarios", "Comentarios"]:
                    item["categoria"] = "Livros"
                    updated_count += 1
                elif cat == "dict" and item.get("categoria") == "Livros":
                    item["categoria"] = "Dicionarios"
                    updated_count += 1
                elif cat == "commentary" and item.get("categoria") == "Livros":
                    item["categoria"] = "Comentarios"
                    updated_count += 1

        with open(LOJA_JSON_FILE, "w", encoding="utf-8") as f:
            json.dump(loja_items, f, ensure_ascii=False, indent=2)

        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps({"success": True, "updated_count": updated_count}).encode("utf-8"))

if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), MyBibleHandler) as httpd:
        print(f"============================================================")
        print(f" Keryx MyBible Inspector rodando em: http://localhost:{PORT}")
        print(f" Pastas: Comentarios ({len(os.listdir(COMMENTS_DIR))}), Dicionarios ({len(os.listdir(DICT_DIR))}), Livros ({len(os.listdir(BOOKS_DIR))})")
        print(f"============================================================")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServidor encerrado.")
