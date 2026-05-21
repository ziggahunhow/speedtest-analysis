#!/usr/bin/env bash
# speedtest-run.sh — runs a single speedtest and appends results to the log CSV
# Called by cron; safe to run manually too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SPEEDTEST_LOG:-$SCRIPT_DIR/data/results.csv}"

mkdir -p "$(dirname "$LOG_FILE")"

# Write header if file is new/empty
if [[ ! -s "$LOG_FILE" ]]; then
  echo "timestamp,server_name,server_location,latency_ms,jitter_ms,download_mbps,upload_mbps,packet_loss,result_url" > "$LOG_FILE"
fi

# Run speedtest in JSONL mode (no progress bar for cron)
# Output is multiple JSON lines; filter for the "type":"result" line.
ALL_OUTPUT=$(speedtest --format=json --progress=no 2>&1)
RAW=$(echo "$ALL_OUTPUT" | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'result':
            print(line)
            break
    except:
        pass
")

if [[ -z "$RAW" ]]; then
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"),ERROR,,,,,,,speedtest failed: $(echo "$ALL_OUTPUT" | tr '\n' ' ')" >> "$LOG_FILE"
  exit 1
fi

# Parse fields from the result JSON line
TS=$(echo "$RAW"         | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['timestamp'])" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
SERVER=$(echo "$RAW"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['server']['name'])" 2>/dev/null || echo "")
LOCATION=$(echo "$RAW"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['server']['location'])" 2>/dev/null || echo "")
LATENCY=$(echo "$RAW"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['ping']['latency'],2))" 2>/dev/null || echo "")
JITTER=$(echo "$RAW"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['ping']['jitter'],2))" 2>/dev/null || echo "")
DOWNLOAD=$(echo "$RAW"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['download']['bandwidth']*8/1_000_000,2))" 2>/dev/null || echo "")
UPLOAD=$(echo "$RAW"     | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d['upload']['bandwidth']*8/1_000_000,2))" 2>/dev/null || echo "")
LOSS=$(echo "$RAW"       | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('packetLoss',0))" 2>/dev/null || echo "0")
URL=$(echo "$RAW"        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('url',''))" 2>/dev/null || echo "")

echo "${TS},${SERVER},${LOCATION},${LATENCY},${JITTER},${DOWNLOAD},${UPLOAD},${LOSS},${URL}" >> "$LOG_FILE"
echo "[$(date '+%H:%M:%S')] ↓ ${DOWNLOAD} Mbps  ↑ ${UPLOAD} Mbps  ping ${LATENCY}ms  → $LOG_FILE"
