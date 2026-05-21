# speedtest-analysis

Automated WiFi speed logger + visualizer using [Speedtest by Ookla](https://www.speedtest.net/apps/cli).  
Runs on a cron schedule (default every 30 min), appends results to a CSV, and renders an interactive HTML chart.

## Requirements

- **macOS** or **Linux (Ubuntu)**
- **`speedtest`** (Ookla CLI):
  - **macOS:**
    ```bash
    brew install speedtest
    ```
  - **Ubuntu (jammy / 22.04):** follow [Ookla's apt install guide](https://www.speedtest.net/apps/cli), then:
    ```bash
    sudo apt install speedtest
    ```
  - **Ubuntu noble (24.04):** Ookla's repo doesn't publish noble packages yet. After adding the repo per the guide above, patch the sources list to fall back to jammy, then install:
    ```bash
    sudo sed -i 's/noble/jammy/g' /etc/apt/sources.list.d/ookla_speedtest-cli.list
    sudo apt update
    sudo apt install speedtest
    ```
- **Python 3** — pre-installed on macOS; `sudo apt install python3` on Ubuntu

---

## Quick start

```bash
# 1. Clone / copy this folder anywhere you like, then cd into it
cd speedtest-analysis

# 2. Make scripts executable (first time only)
chmod +x speedtest-run.sh speedtest-cron.sh speedtest-report.sh speedtest-mock.sh

# 3. Run one test to verify everything works
./speedtest-run.sh

# 4. Open the chart
python3 speedtest-viz.py

# 5. Install the cron job so it runs automatically every 30 minutes
./speedtest-cron.sh install
```

That's it. Results accumulate in `data/results.csv`; re-run `speedtest-viz.py` any time to refresh the chart.

---

## Scripts

| Script | Purpose |
|---|---|
| `speedtest-run.sh` | Run one speedtest, append result to CSV |
| `speedtest-cron.sh` | Install / remove / check the cron job |
| `speedtest-report.sh` | Print a stats table in the terminal |
| `speedtest-viz.py` | Generate `data/report.html` and open it in the browser |
| `speedtest-mock.sh` | Generate fake data (useful for testing the chart) |

---

## Cron management

```bash
./speedtest-cron.sh install         # every 30 min (default)
./speedtest-cron.sh install 15      # every 15 min
./speedtest-cron.sh install 60      # every hour
./speedtest-cron.sh install 5       # every 5 min ⚠ may get rate-limited
./speedtest-cron.sh status          # show current schedule
./speedtest-cron.sh remove          # uninstall cron job
```

---

## Visualization

```bash
python3 speedtest-viz.py                # all data
python3 speedtest-viz.py --last 48      # last 48 entries (~24 hrs at 30-min intervals)
python3 speedtest-viz.py --today        # today only
python3 speedtest-viz.py --no-open      # write HTML without opening browser
```

The chart opens as `data/report.html` in your default browser. It shows:
- **Download & Upload (Mbps)** — line chart with average reference lines
- **Ping & Jitter (ms)** — line chart
- **Packet Loss (%)** — bar chart
- Summary stat cards (avg / min / max / last reading) at the top

---

## Terminal report

```bash
./speedtest-report.sh               # all results + avg/min/max
./speedtest-report.sh --last 20     # last 20 entries
./speedtest-report.sh --today       # today only
./speedtest-report.sh --tail        # live-tail the CSV as new results come in
```

---

## Testing the chart without waiting for data

```bash
./speedtest-mock.sh                 # generate 30 fake entries, 1 second apart
./speedtest-mock.sh 100 0.5         # 100 entries, 0.5 s apart
python3 speedtest-viz.py            # view them
```

---

## Data format

Results are stored in `data/results.csv`:

```
timestamp, server_name, server_location, latency_ms, jitter_ms,
download_mbps, upload_mbps, packet_loss, result_url
```

Cron stdout/stderr goes to `data/cron.log`.

---

## File layout

```
speedtest-analysis/
├── speedtest-run.sh       # single test runner
├── speedtest-cron.sh      # cron installer
├── speedtest-report.sh    # terminal stats
├── speedtest-viz.py       # HTML chart generator
├── speedtest-mock.sh      # fake data generator (testing)
├── README.md
└── data/                  # auto-created on first run
    ├── results.csv
    ├── report.html
    └── cron.log
```
