#!/usr/bin/env bash
# speedtest-mock.sh — generate fake speedtest entries for testing
# Usage: ./speedtest-mock.sh [COUNT] [DELAY_SECONDS]
#   COUNT         number of entries to generate (default: 30)
#   DELAY_SECONDS seconds between entries (default: 1)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SPEEDTEST_LOG:-$SCRIPT_DIR/data/results.csv}"
COUNT="${1:-30}"
DELAY="${2:-1}"

mkdir -p "$(dirname "$LOG_FILE")"

if [[ ! -s "$LOG_FILE" ]]; then
  echo "timestamp,server_name,server_location,latency_ms,jitter_ms,download_mbps,upload_mbps,packet_loss,result_url" > "$LOG_FILE"
fi

echo "Generating $COUNT mock entries (${DELAY}s apart)…"

python3 - "$LOG_FILE" "$COUNT" "$DELAY" <<'PYEOF'
import sys, time, random, math
from datetime import datetime, timezone, timedelta

log_file = sys.argv[1]
count    = int(sys.argv[2])
delay    = float(sys.argv[3])

# Simulate realistic variation with a slow sine wave drift
base_dl = random.uniform(220, 320)
base_ul = random.uniform(230, 290)
base_ping = random.uniform(3, 8)

for i in range(count):
    now = datetime.now(timezone.utc)
    ts  = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    # add slow oscillation + noise
    wave = math.sin(i / 5.0) * 30
    dl   = round(max(10, base_dl + wave + random.gauss(0, 10)), 2)
    ul   = round(max(10, base_ul + wave * 0.7 + random.gauss(0, 8)), 2)
    ping = round(max(1, base_ping + random.gauss(0, 1.5)), 2)
    jitter = round(abs(random.gauss(0.8, 0.4)), 2)
    loss   = round(max(0, random.gauss(0, 0.2)), 2)

    line = f"{ts},Chief Telecom,Taipei,{ping},{jitter},{dl},{ul},{loss},"
    with open(log_file, "a") as f:
        f.write(line + "\n")

    print(f"[{i+1:2}/{count}] {ts}  ↓ {dl:6.1f}  ↑ {ul:6.1f}  ping {ping}ms")
    sys.stdout.flush()

    if i < count - 1:
        time.sleep(delay)

print("Done.")
PYEOF
