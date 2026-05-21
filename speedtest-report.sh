#!/usr/bin/env bash
# speedtest-report.sh — print a summary of collected speedtest results
#
# Usage:
#   ./speedtest-report.sh              # summary of all results
#   ./speedtest-report.sh --last N     # last N results
#   ./speedtest-report.sh --today      # today's results only
#   ./speedtest-report.sh --tail       # live-tail the CSV log

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SPEEDTEST_LOG:-$SCRIPT_DIR/data/results.csv}"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "No data yet. Run ./speedtest-run.sh first, or wait for the cron job."
  exit 0
fi

mode="${1:-}"
arg="${2:-10}"

case "$mode" in
  --tail)
    echo "Tailing $LOG_FILE (Ctrl-C to stop)…"
    tail -f "$LOG_FILE"
    exit 0
    ;;
  --last)
    rows=$(tail -n "$arg" "$LOG_FILE" | grep -v "^timestamp")
    label="Last $arg results"
    ;;
  --today)
    today=$(date +"%Y-%m-%d")
    rows=$(grep "^${today}" "$LOG_FILE" || true)
    label="Results for $today"
    ;;
  *)
    rows=$(tail -n +2 "$LOG_FILE")   # skip header
    label="All results"
    ;;
esac

if [[ -z "$rows" ]]; then
  echo "No results found for: $label"
  exit 0
fi

# Use python3 for nice tabular output + stats
python3 - "$LOG_FILE" "$mode" "$arg" <<'PYEOF'
import sys, csv, os
from datetime import datetime, timezone

log_file = sys.argv[1]
mode     = sys.argv[2] if len(sys.argv) > 2 else ""
arg      = int(sys.argv[3]) if len(sys.argv) > 3 else 10
today    = datetime.now().strftime("%Y-%m-%d")

rows = []
with open(log_file) as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row.get("download_mbps") in ("", "ERROR", None):
            continue
        if mode == "--today" and not row["timestamp"].startswith(today):
            continue
        rows.append(row)

if mode == "--last":
    rows = rows[-arg:]

if not rows:
    print("No valid rows found.")
    sys.exit(0)

def fmt_ts(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.astimezone().strftime("%m-%d %H:%M")
    except:
        return ts[:16]

def safe_float(v, default=0.0):
    try:
        return float(v)
    except:
        return default

# Table
header = f"{'Time':<14} {'↓ Mbps':>8} {'↑ Mbps':>8} {'Ping ms':>8} {'Jitter':>7} {'Loss%':>6}"
print()
print(header)
print("-" * len(header))
for r in rows:
    print(f"{fmt_ts(r['timestamp']):<14} "
          f"{safe_float(r['download_mbps']):>8.1f} "
          f"{safe_float(r['upload_mbps']):>8.1f} "
          f"{safe_float(r['latency_ms']):>8.1f} "
          f"{safe_float(r['jitter_ms']):>7.1f} "
          f"{safe_float(r['packet_loss']):>6.1f}")

# Stats
downloads = [safe_float(r["download_mbps"]) for r in rows]
uploads   = [safe_float(r["upload_mbps"])   for r in rows]
pings     = [safe_float(r["latency_ms"])     for r in rows]

print()
print(f"{'':14} {'↓ Mbps':>8} {'↑ Mbps':>8} {'Ping ms':>8}")
print(f"{'avg':<14} {sum(downloads)/len(downloads):>8.1f} {sum(uploads)/len(uploads):>8.1f} {sum(pings)/len(pings):>8.1f}")
print(f"{'min':<14} {min(downloads):>8.1f} {min(uploads):>8.1f} {min(pings):>8.1f}")
print(f"{'max':<14} {max(downloads):>8.1f} {max(uploads):>8.1f} {max(pings):>8.1f}")
print(f"\nTotal samples: {len(rows)}")
PYEOF
