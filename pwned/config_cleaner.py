# -*- coding: utf-8 -*-
import os
import glob
import sys
import re
from datetime import datetime

CONFIG_DIR = "/usr/data/config"
LOG_FILE = "/usr/data/config/config_cleaner.log"

def log_message(msg, is_auto, log_fh=None):
    """Scrive a schermo se interattivo, oppure su file di log se in modalita automatica."""
    timestamp = datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    formatted_msg = f"{timestamp} {msg}"
    
    if is_auto and log_fh:
        log_fh.write(formatted_msg + "\n")
    else:
        print(msg)

def analyze_and_clean_file(filepath, is_auto, log_fh):
    fixed_actions = []
    line_reports = []
    
    try:
        with open(filepath, 'rb') as f:
            raw_content = f.read()

        # 1. Pulizia globale CRLF -> LF
        if b'\r\n' in raw_content:
            raw_content = raw_content.replace(b'\r\n', b'\n')
            fixed_actions.append("Rimossi caratteri di fine linea in stile Windows (CRLF)")
        elif b'\r' in raw_content:
            raw_content = raw_content.replace(b'\r', b'\n')
            fixed_actions.append("Rimossi caratteri CR isolati")

        # Conversione in stringa per l'analisi riga per riga
        try:
            text = raw_content.decode('utf-8')
        except UnicodeDecodeError:
            try:
                text = raw_content.decode('latin-1')
                fixed_actions.append("Convertito encoding in UTF-8 (rilevati caratteri non standard)")
            except Exception as e:
                return False, [f"ERRORE CRITICO: Impossibile decodificare il file: {e}"], []

        lines = text.split('\n')
        cleaned_lines = []
        file_has_anomalies = False

        for idx, line in enumerate(lines, start=1):
            anomaly_detected = False
            reason = ""

            # Controllo caratteri di controllo invisibili o strani
            if re.search(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', line):
                anomaly_detected = True
                reason = "Trovati caratteri di controllo non stampabili/sporchi"
                line = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', line)

            if line.endswith(' ') or line.endswith('\t'):
                line = line.rstrip()

            if anomaly_detected:
                file_has_anomalies = True
                line_reports.append(f"  -> Riga {idx}: \"{line}\" [{reason}]")

            cleaned_lines.append(line)

        new_content = "\n".join(cleaned_lines).encode('utf-8')

        if new_content != raw_content or file_has_anomalies:
            with open(filepath, 'wb') as f:
                f.write(new_content)
            if not fixed_actions and file_has_anomalies:
                fixed_actions.append("Rimossi caratteri anomali riga per riga")

        return True, fixed_actions, line_reports

    except Exception as e:
        return False, [f"ERRORE DI I/O: {e}"], []

def main():
    # Controlla se e stato passato il parametro --auto o --daemon
    is_auto = "--auto" in sys.argv or "--daemon" in sys.argv
    
    log_fh = None
    if is_auto:
        # Assicura che la cartella esista e apre il log in scrittura (sovrascrive l'ultimo boot)
        log_fh = open(LOG_FILE, 'w', encoding='utf-8')

    log_message(f"[*] Avvio scansione integrita configurazioni in: {CONFIG_DIR}", is_auto, log_fh)
    
    if not os.path.exists(CONFIG_DIR):
        log_message(f"[!] Errore: La cartella {CONFIG_DIR} non esiste.", is_auto, log_fh)
        if log_fh: log_fh.close()
        sys.exit(1)

    files = [f for f in glob.glob(os.path.join(CONFIG_DIR, "**/*"), recursive=True) if os.path.isfile(f) and f.endswith(('.cfg', '.conf', '.ini'))]

    if not files:
        log_message("[!] Nessun file di configurazione trovato.", is_auto, log_fh)
        if log_fh: log_fh.close()
        sys.exit(0)

    errors_found = 0
    fixed_count = 0

    for filepath in files:
        rel_path = os.path.relpath(filepath, CONFIG_DIR)
        success, actions, details = analyze_and_clean_file(filepath, is_auto, log_fh)

        if not success:
            log_message(f"\n[X] ERRORE BLOCCANTE su '{rel_path}':", is_auto, log_fh)
            for err in actions:
                log_message(f"    {err}", is_auto, log_fh)
            errors_found += 1
        else:
            if actions or details:
                log_message(f"\n[FIXED] Corretto file: '{rel_path}'", is_auto, log_fh)
                for act in actions:
                    log_message(f"    - {act}", is_auto, log_fh)
                for det in details:
                    log_message(det, is_auto, log_fh)
                fixed_count += 1
            else:
                log_message(f"[OK] {rel_path} - Pulito.", is_auto, log_fh)

    log_message("\n" + "="*40, is_auto, log_fh)
    if errors_found > 0:
        log_message(f"[!] COMPLETATO CON ERRORI: {errors_found} file non riparabili.", is_auto, log_fh)
        if log_fh: log_fh.close()
        sys.exit(1)
    else:
        log_message(f"[SUCCESSO] Scansione ultimata. File corretti: {fixed_count}", is_auto, log_fh)
        if log_fh: log_fh.close()
        sys.exit(0)

if __name__ == '__main__':
    main()