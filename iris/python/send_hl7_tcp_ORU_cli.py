#!/usr/bin/env python3
"""
send_hl7_tcp_ORU_cli.py — Headless CLI version of the HL7 ORU sender.
Reads obx_rp/obx_ed strings from send_hl7_tcp_ORU.py to avoid duplicating 111KB of base64.

Usage:
  python3 send_hl7_tcp_ORU_cli.py [options]

Examples:
  python3 send_hl7_tcp_ORU_cli.py
  python3 send_hl7_tcp_ORU_cli.py --nb-messages 100 --nb-threads 20
  python3 send_hl7_tcp_ORU_cli.py --nb-messages 10 --include-pdf
  python3 send_hl7_tcp_ORU_cli.py --patient-id 12345678 --first-name Anne --last-name VERSAIRE --dob 24/01/1985 --gender F --sodium 140
"""

import argparse
import ast
import logging
import pathlib
import random
import re
import socket
import string
import threading
import time
from datetime import datetime

# --- Constants ---
DEFAULT_SERVER_IP   = 'ec2-63-177-72-122.eu-central-1.compute.amazonaws.com'
DEFAULT_SERVER_PORT = 9001
START_BLOCK         = '\x0b'
END_BLOCK           = '\x1c'
CARRIAGE_RETURN     = '\x0d'
MAX_RETRIES         = 3
RETRY_DELAY         = 2  # seconds between retries

FIRST_NAMES = ["Delphine", "Danmark", "Marck-Augustus", "Carl-Jamie", "Francois",
               "Rochelle", "Neil", "Adrian", "Philippe", "Jean-Michel", "Olivier",
               "Michael", "Sophie", "Frederic"]
LAST_NAMES  = ["CRUZ", "NOVIANT", "MATEO", "GARDET", "MOZO", "LEYNES", "DROUHIN",
               "RAULT", "NACARIO", "LAMARRE", "BAYLE", "CARLI BACHER", "ELISAN", "ROMAN"]

# --- Load OBX strings from the GUI script (avoids duplicating 111KB of base64) ---
def _load_obx_strings():
    gui_script = pathlib.Path(__file__).parent / "send_hl7_tcp_ORU.py"
    try:
        src = gui_script.read_text()
        tree = ast.parse(src)
        obx = {}
        for node in ast.walk(tree):
            if isinstance(node, ast.Assign):
                for t in node.targets:
                    if isinstance(t, ast.Name) and t.id in ('obx_rp', 'obx_ed'):
                        obx[t.id] = ast.literal_eval(node.value)
                        if len(obx) == 2:
                            return obx['obx_rp'], obx['obx_ed']
    except Exception as e:
        print(f"Warning: could not load OBX strings from send_hl7_tcp_ORU.py: {e}")
    # Fallback: minimal RP reference only
    return (
        "OBX|1|RP|PDFREPORT^LABORATORY REPORT^L|1|file:////data/pdf/Report.pdf^DGLab^AP^PDF|||N|||P|||||||DOC",
        ""
    )

OBX_RP, OBX_ED = _load_obx_strings()

# --- Message generation ---
message_control_id   = 0
message_control_lock = threading.Lock()

def generate_random_dob():
    year  = random.randint(1950, 2004)
    month = random.randint(1, 12)
    day   = random.randint(1, 28)
    return f"{day:02d}/{month:02d}/{year}"

def build_hl7_message(patient_id, first_name, last_name, dob, gender, sodium, include_pdf):
    global message_control_id
    with message_control_lock:
        message_control_id += 1
        msg_id = f"{message_control_id:09d}"

    try:
        dob_formatted = datetime.strptime(dob, "%d/%m/%Y").strftime("%Y%m%d")
    except ValueError:
        print(f"ERROR: Invalid date format '{dob}'. Use DD/MM/YYYY.")
        return None

    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")

    hl7 = f"""MSH|^~\\&|DGLab|LAB|OpenMedical|KIS|{timestamp}||ORU^R01|{msg_id}|P|2.3|||||CH|8859/1|de
PID|1||18^^^LAB^PI~{patient_id}^^^ASIP-SANTE-INS-NIA&1.2.250.1.213.1.4.9&ISO^INS-NIA||{last_name}^{first_name}^^^^^L||{dob_formatted}|{gender}|||^^^^^^H||||F|||||||||||||||||VALI
PV1|1|I|^^^||||||||||||||||0|||||||||||||||||||||||||202605280000|190001010000|||||17
ORC|SC|||6100130|IP||||20260610144322|||3|||{timestamp}
OBR|1|||296^S-Sodium^L|||{timestamp}|20260610141505||||||||3|||||||||F
OBX|1|TX|296^S-Sodium^L|1|{sodium}||||||F||
OBR|2||6100130|PDFREPORT^LABORATORY REPORT^L|||{timestamp}|||||||||||||||20260610144322|||P
"""
    hl7 += (OBX_ED if include_pdf else OBX_RP) + "\n"
    return hl7


# --- Send logic ---
def send_messages(messages, server_ip, server_port, nb_threads, silent=False):
    nb           = len(messages)
    ok_count     = [0]
    fail_count   = [0]
    sent_count   = [0]
    done_threads = [0]
    lock         = threading.Lock()
    start_time   = time.time()

    chunks = [messages[i::nb_threads] for i in range(nb_threads)]

    def _worker(chunk):
        for hl7_message in chunk:
            hl7_mllp    = hl7_message.replace("\n", "\r")
            hl7_wrapped = (START_BLOCK.encode() + hl7_mllp.encode() +
                           END_BLOCK.encode() + CARRIAGE_RETURN.encode())

            for attempt in range(1, MAX_RETRIES + 1):
                try:
                    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                        s.setsockopt(socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1)
                        s.settimeout(5)
                        s.connect((server_ip, server_port))
                        s.settimeout(None)
                        s.sendall(hl7_wrapped)
                        response       = s.recv(1024).decode()
                        response_clean = re.sub(r'[^\x20-\x7E\r\n\t]', '\n', response)
                        with lock:
                            ok_count[0]   += 1
                            sent_count[0] += 1
                            n_sent = sent_count[0]
                        elapsed = time.time() - start_time
                        if nb == 1:
                            msg = f"Response: {response_clean[:120].strip()}"
                        else:
                            msg = f"[{n_sent}/{nb}] OK ({elapsed:.1f}s) - {response_clean[:60].strip()}"
                        logging.info(msg)
                        if not silent:
                            print(msg)
                        break  # success

                except Exception as e:
                    if attempt < MAX_RETRIES:
                        time.sleep(RETRY_DELAY)
                    else:
                        with lock:
                            fail_count[0] += 1
                            sent_count[0] += 1
                            n_sent = sent_count[0]
                        elapsed = time.time() - start_time
                        err = f"[{n_sent}/{nb}] FAILED: {e}"
                        logging.error(err)
                        if not silent:
                            print(err)

        with lock:
            done_threads[0] += 1
            if done_threads[0] == nb_threads and nb > 1:
                elapsed = time.time() - start_time
                rate    = ok_count[0] / elapsed if elapsed > 0 else 0
                summary = (f"Load test done: {ok_count[0]}/{nb} OK, "
                           f"{fail_count[0]} failed \u2014 {elapsed:.2f}s "
                           f"({rate:.1f} msg/s) [{nb_threads} thread(s)]")
                logging.info(summary)
                print(summary)  # always printed, even in silent mode

    threads = [threading.Thread(target=_worker, args=(chunk,), daemon=True)
               for chunk in chunks if chunk]
    for t in threads:
        t.start()
    for t in threads:
        t.join()


# --- Entry point ---
def main():
    parser = argparse.ArgumentParser(
        description='Send HL7 ORU messages via MLLP TCP — headless CLI',
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--server-ip',   default=DEFAULT_SERVER_IP,  help='IRIS server IP or hostname')
    parser.add_argument('--server-port', default=DEFAULT_SERVER_PORT, type=int, help='TCP port')
    parser.add_argument('--nb-messages', default=1,  type=int, help='Number of messages to send')
    parser.add_argument('--nb-threads',  default=1,  type=int, help='Parallel sender threads (max 20)')
    parser.add_argument('--silent',      action='store_true', help='Suppress per-message output; show only final summary')
    parser.add_argument('--include-pdf', action='store_true', help='Embed base64 PDF in OBX|ED (default: OBX|RP file reference)')
    parser.add_argument('--patient-id',  default=None, help='Patient ID (random 8 digits if omitted)')
    parser.add_argument('--first-name',  default=None, help='First name (random if omitted)')
    parser.add_argument('--last-name',   default=None, help='Last name (random if omitted)')
    parser.add_argument('--dob',         default=None, help='Date of birth DD/MM/YYYY (random if omitted)')
    parser.add_argument('--gender',      default=None, choices=['M', 'F', 'X'], help='Gender (random M/F if omitted)')
    parser.add_argument('--sodium',      default=None, type=int, help='Sodium mmol/L (random 135-145 if omitted)')
    args = parser.parse_args()

    nb_threads = max(1, min(args.nb_threads, 20))

    logging.basicConfig(
        filename='send_hl7_tcp.log',
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S')

    if not args.silent:
        print(f"Generating {args.nb_messages} message(s)...")
    messages = []
    for _ in range(args.nb_messages):
        patient_id = args.patient_id  or ''.join(random.choices(string.digits, k=8))
        first_name = args.first_name  or random.choice(FIRST_NAMES)
        last_name  = args.last_name   or random.choice(LAST_NAMES)
        dob        = args.dob         or generate_random_dob()
        gender     = args.gender      or random.choice(['M', 'F'])
        sodium     = str(args.sodium) if args.sodium else str(random.randint(135, 145))
        msg = build_hl7_message(patient_id, first_name, last_name, dob, gender, sodium, args.include_pdf)
        if msg is None:
            return
        messages.append(msg)

    if not args.silent:
        print(f"Sending to {args.server_ip}:{args.server_port} "
              f"[{nb_threads} thread(s), include_pdf={args.include_pdf}]...")
    send_messages(messages, args.server_ip, args.server_port, nb_threads, silent=args.silent)


if __name__ == '__main__':
    main()
