# speedtest-analysis skill

Use this skill when the user wants to run a WiFi speed test, schedule automated speed tests, view speed history, or visualize network performance over time.

## Project layout

All scripts live in the project root. Data is written to `data/` (auto-created).

```
speedtest-run.sh       # run one test → appends to data/results.csv
speedtest-cron.sh      # manage the cron job
speedtest-report.sh    # terminal stats table
speedtest-viz.py       # generate + open data/report.html (Chart.js)
speedtest-mock.sh      # generate fake data for testing
```

## Common tasks

### Run a single test
```bash
./speedtest-run.sh
```
Prints: `[HH:MM:SS] ↓ XXX Mbps  ↑ XXX Mbps  ping Xms`

### Schedule automatic tests (cron)
```bash
./speedtest-cron.sh install [INTERVAL_MINUTES]   # default: 30
./speedtest-cron.sh status
./speedtest-cron.sh remove
```

### View results in the browser
```bash
python3 speedtest-viz.py                  # all data
python3 speedtest-viz.py --last 48        # last 48 entries
python3 speedtest-viz.py --today          # today only
python3 speedtest-viz.py --no-open        # write HTML, don't open browser
```

### Terminal stats
```bash
./speedtest-report.sh
./speedtest-report.sh --last 20
./speedtest-report.sh --today
./speedtest-report.sh --tail              # live-tail CSV
```

### Generate mock data (for testing the chart)
```bash
./speedtest-mock.sh                       # 30 entries, 1 s apart
./speedtest-mock.sh [COUNT] [DELAY_SEC]
```

## Data schema

`data/results.csv` columns:
```
timestamp, server_name, server_location, latency_ms, jitter_ms,
download_mbps, upload_mbps, packet_loss, result_url
```

Error rows have `ERROR` in server_name and a message in result_url.

## Requirements

- macOS **or** Linux (Ubuntu)
- `speedtest` (Ookla CLI):
  - **macOS:** `brew install speedtest`
  - **Ubuntu (jammy / 22.04):** follow [Ookla's apt install guide](https://www.speedtest.net/apps/cli), then `sudo apt install speedtest`
  - **Ubuntu noble (24.04):** Ookla's repo doesn't publish noble packages yet — after adding the repo, patch the sources list to use jammy and then install:
    ```bash
    sudo sed -i 's/noble/jammy/g' /etc/apt/sources.list.d/ookla_speedtest-cli.list
    sudo apt update
    sudo apt install speedtest
    ```
- Python 3 (pre-installed on macOS; `sudo apt install python3` on Ubuntu)

## First-time setup

```bash
chmod +x speedtest-run.sh speedtest-cron.sh speedtest-report.sh speedtest-mock.sh
./speedtest-run.sh           # verify it works
./speedtest-cron.sh install  # start collecting
```
