#!/usr/bin/env python3
"""
Upload automatizado dos 640 hinos da Harpa Cristã para o canal do Telegram (@HinosHarpa)
Gera o catálogo indexado assets/data/harpa_telegram_index.json com file_id e message_id.
"""

import os
import sys
import json
import time
import re
import sqlite3
import urllib.request
import urllib.error
import urllib.parse

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "8551530107:AAEWOCnU8MP1n1XFheuUNwR9ASUyT_sJH-M")
CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID", "-1003981083510") # @HinosHarpa
MP3_DIR = "/home/nivaldo/Área de trabalho/Projetos/B2_Downloads/HarpaHinos"
MYBIBLE_PATH = "/home/nivaldo/Área de trabalho/B2_Downloads/Livros/Harpa.bok.mybible"
INDEX_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "data", "harpa_telegram_index.json"))

def get_hymn_titles():
    """Lê os 640 títulos da Harpa diretamente do banco MyBible SQLite."""
    titles = {}
    if os.path.exists(MYBIBLE_PATH):
        try:
            conn = sqlite3.connect(MYBIBLE_PATH)
            cur = conn.cursor()
            cur.execute("SELECT rowid, title FROM journal ORDER BY rowid")
            for rowid, raw_title in cur.fetchall():
                # Remove numeração inicial e formata como Title Case
                clean = re.sub(r"^\d+[\.\s\-]+", "", raw_title).strip()
                titles[rowid] = clean
            conn.close()
        except Exception as e:
            print(f"Aviso: Não foi possível ler {MYBIBLE_PATH}: {e}")
    return titles

def load_existing_index():
    if os.path.exists(INDEX_PATH):
        try:
            with open(INDEX_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "channel": "@HinosHarpa",
        "chat_id": int(CHAT_ID) if CHAT_ID.startswith("-") or CHAT_ID.isdigit() else CHAT_ID,
        "total_hymns": 640,
        "updated_at": "",
        "hymns": {}
    }

def save_index(data):
    os.makedirs(os.path.dirname(INDEX_PATH), exist_ok=True)
    data["updated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    with open(INDEX_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def encode_multipart_formdata(fields, files):
    boundary = "----TelegramHarpaUploadBoundary" + str(int(time.time() * 1000))
    body = bytearray()
    
    for key, value in fields.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{key}"\r\n\r\n'.encode("utf-8"))
        body.extend(f"{value}\r\n".encode("utf-8"))
        
    for key, (filename, filedata, content_type) in files.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{key}"; filename="{filename}"\r\n'.encode("utf-8"))
        body.extend(f"Content-Type: {content_type}\r\n\r\n".encode("utf-8"))
        body.extend(filedata)
        body.extend(b"\r\n")
        
    body.extend(f"--{boundary}--\r\n".encode("utf-8"))
    content_type_header = f"multipart/form-data; boundary={boundary}"
    return body, content_type_header

def upload_audio(file_path, num_int, title, max_retries=5):
    num_str = f"{num_int:03d}"
    formatted_title = f"{num_str} - {title.title()}"
    caption = f"🎵 Hino {num_str} - {title.title()}"
    
    fields = {
        "chat_id": CHAT_ID,
        "title": formatted_title,
        "performer": "Harpa Cristã",
        "caption": caption
    }
    
    with open(file_path, "rb") as f:
        audio_bytes = f.read()
        
    files = {
        "audio": (f"{num_str}.mp3", audio_bytes, "audio/mpeg")
    }
    
    body, content_type = encode_multipart_formdata(fields, files)
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendAudio"
    
    for attempt in range(1, max_retries + 1):
        try:
            req = urllib.request.Request(url, data=bytes(body), headers={"Content-Type": content_type})
            with urllib.request.urlopen(req, timeout=90) as resp:
                resp_json = json.loads(resp.read().decode("utf-8"))
                if resp_json.get("ok"):
                    res = resp_json["result"]
                    audio_info = res.get("audio", {})
                    return {
                        "number": num_str,
                        "title": title.title(),
                        "message_id": res.get("message_id"),
                        "file_id": audio_info.get("file_id"),
                        "file_unique_id": audio_info.get("file_unique_id"),
                        "duration": audio_info.get("duration", 0),
                        "file_size": audio_info.get("file_size", len(audio_bytes)),
                    }
                else:
                    print(f"  ❌ Erro da API Telegram: {resp_json}")
        except urllib.error.HTTPError as he:
            err_body = he.read().decode("utf-8", errors="ignore")
            if he.code == 429: # Rate limit / flood control
                retry_after = 30
                try:
                    err_json = json.loads(err_body)
                    retry_after = err_json.get("parameters", {}).get("retry_after", 30)
                except Exception:
                    pass
                print(f"  ⏳ Rate limit do Telegram (429). Aguardando {retry_after + 2}s...")
                time.sleep(retry_after + 2)
                continue
            else:
                print(f"  ❌ Erro HTTP {he.code}: {err_body}")
        except Exception as e:
            print(f"  ⚠️ Tentativa {attempt}/{max_retries} falhou: {e}")
            time.sleep(3 * attempt)
            
    return None

def main():
    print("=" * 60)
    print("🎵 SINCRONIZADOR HARPA CRISTÃ -> TELEGRAM (@HinosHarpa)")
    print("=" * 60)
    
    if not os.path.isdir(MP3_DIR):
        print(f"❌ Diretório local de MP3 não encontrado: {MP3_DIR}")
        sys.exit(1)
        
    titles = get_hymn_titles()
    index_data = load_existing_index()
    hymns_map = index_data.get("hymns", {})
    
    # Se Hino 1 já foi enviado no teste, preserva
    if "1" not in hymns_map and "CQACAgEAAyEGAATtSoN2AAMDav9R2r4ZrTKZaeNJF0KSKSYa8yoAAicKAAJ4RPlH1HhH4d0ZGyg9BA" != "":
        hymns_map["1"] = {
            "number": "001",
            "title": titles.get(1, "Chuvas De Graça").title(),
            "message_id": 3,
            "file_id": "CQACAgEAAyEGAATtSoN2AAMDav9R2r4ZrTKZaeNJF0KSKSYa8yoAAicKAAJ4RPlH1HhH4d0ZGyg9BA",
            "file_unique_id": "AgADJwoAAnhE-Uc",
            "duration": 154,
            "file_size": 4891628
        }
        index_data["hymns"] = hymns_map
        save_index(index_data)

    print(f"📁 Pasta de arquivos: {MP3_DIR}")
    print(f"📑 Destino do Índice: {INDEX_PATH}")
    print(f"📊 Hinos já indexados: {len(hymns_map)} de 640")
    
    total_to_upload = 640 - len(hymns_map)
    print(f"🚀 Restantes para envio: {total_to_upload}")
    print("-" * 60)

    for i in range(1, 641):
        key = str(i)
        num_str = f"{i:03d}"
        mp3_file = os.path.join(MP3_DIR, f"{num_str}.mp3")
        
        if key in hymns_map and hymns_map[key].get("file_id"):
            continue # Já enviado com sucesso
            
        if not os.path.isfile(mp3_file):
            print(f"⚠️ Hino {num_str}.mp3 não encontrado no disco!")
            continue
            
        title = titles.get(i, f"Hino {num_str}")
        print(f"Enviando [{i}/640] - {num_str} - {title}...", end="", flush=True)
        
        info = upload_audio(mp3_file, i, title)
        if info:
            hymns_map[key] = info
            index_data["hymns"] = hymns_map
            save_index(index_data)
            print(" ✅ OK (file_id salvo)")
            # Pausa de segurança anti-flood
            time.sleep(2.5)
        else:
            print(" ❌ FALHOU")
            time.sleep(5)

    print("=" * 60)
    print(f"🎉 Processo concluído! {len(hymns_map)}/640 hinos indexados no Telegram.")
    print(f"📄 Arquivo salvo: {INDEX_PATH}")
    print("=" * 60)

if __name__ == "__main__":
    main()
