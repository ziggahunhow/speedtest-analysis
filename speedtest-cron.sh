#!/usr/bin/env bash
# speedtest-cron.sh — install, remove, or show the cron job for speedtest-analysis
#
# Usage:
#   ./speedtest-cron.sh install [INTERVAL_MINUTES]   # default: 30
#   ./speedtest-cron.sh remove
#   ./speedtest-cron.sh status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$SCRIPT_DIR/speedtest-run.sh"
CRON_TAG="# speedtest-analysis"
DEFAULT_INTERVAL=30

cmd="${1:-status}"
interval="${2:-$DEFAULT_INTERVAL}"

# Validate interval is a positive integer
if [[ "$cmd" == "install" ]]; then
  if ! [[ "$interval" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: interval must be a positive integer (minutes). Got: $interval" >&2
    exit 1
  fi
  if (( interval < 5 )); then
    echo "Warning: interval < 5 minutes may get rate-limited by Ookla's servers."
  fi
fi

current_cron() {
  crontab -l 2>/dev/null || true
}

case "$cmd" in
  install)
    # Build cron schedule
    if (( interval == 60 )); then
      schedule="0 * * * *"
    elif (( interval < 60 )); then
      schedule="*/${interval} * * * *"
    else
      hours=$(( interval / 60 ))
      mins=$(( interval % 60 ))
      if (( mins == 0 )); then
        schedule="0 */${hours} * * *"
      else
        schedule="${mins} */${hours} * * *"
      fi
    fi

    log_dir="$SCRIPT_DIR/data"
    log_file="$log_dir/results.csv"
    cron_line="${schedule} SPEEDTEST_LOG=${log_file} ${RUN_SCRIPT} >> ${log_dir}/cron.log 2>&1 ${CRON_TAG}"

    # Remove any existing speedtest-analysis entry, then add new one
    new_crontab=$(current_cron | grep -v "$CRON_TAG"; echo "$cron_line")
    echo "$new_crontab" | crontab -

    echo "✅ Cron job installed — runs every ${interval} minute(s)"
    echo "   Schedule : $schedule"
    echo "   Log file : $log_file"
    echo "   Cron log : ${log_dir}/cron.log"
    echo ""
    echo "Run now to verify: $RUN_SCRIPT"
    ;;

  remove)
    new_crontab=$(current_cron | grep -v "$CRON_TAG")
    echo "$new_crontab" | crontab -
    echo "🗑  Cron job removed."
    ;;

  status)
    entry=$(current_cron | grep "$CRON_TAG" || true)
    if [[ -n "$entry" ]]; then
      echo "✅ Speedtest cron is active:"
      echo "   $entry"
    else
      echo "❌ No speedtest cron job found."
      echo "   Install with: $0 install [INTERVAL_MINUTES]"
    fi
    ;;

  *)
    echo "Usage: $0 {install [minutes]|remove|status}"
    exit 1
    ;;
esac
