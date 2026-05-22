#!/usr/bin/env python3
"""
speedtest-viz.py — generate an HTML chart from speedtest results CSV and open it.

Usage:
    python3 speedtest-viz.py                  # all data
    python3 speedtest-viz.py --last 50        # last N rows
    python3 speedtest-viz.py --today          # today only
    python3 speedtest-viz.py --no-open        # generate HTML but don't open browser
"""

import sys, os, csv, json, argparse, subprocess, webbrowser
from datetime import datetime, timezone

# ── args ──────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser()
parser.add_argument("--last",    type=int, default=None)
parser.add_argument("--today",   action="store_true")
parser.add_argument("--no-open", action="store_true")
parser.add_argument("--log",     default=None)
args = parser.parse_args()

script_dir = os.path.dirname(os.path.abspath(__file__))
log_file   = args.log or os.path.join(script_dir, "data", "results.csv")

if not os.path.exists(log_file):
    print(f"No data file found at {log_file}")
    sys.exit(1)

# ── load data ─────────────────────────────────────────────────────────────────
today = datetime.now().strftime("%Y-%m-%d")
rows  = []
with open(log_file) as f:
    for row in csv.DictReader(f):
        if row.get("download_mbps") in ("", "ERROR", None):
            continue
        if args.today and not row["timestamp"].startswith(today):
            continue
        try:
            rows.append({
                "ts":       row["timestamp"],
                "dl":       float(row["download_mbps"]),
                "ul":       float(row["upload_mbps"]),
                "ping":     float(row["latency_ms"]),
                "jitter":   float(row["jitter_ms"]),
                "loss":     float(row.get("packet_loss") or 0),
                "server":   row.get("server_name", ""),
                "url":      row.get("result_url", ""),
            })
        except (ValueError, KeyError):
            pass

if args.last:
    rows = rows[-args.last:]

if not rows:
    print("No valid rows to chart.")
    sys.exit(0)

def fmt_ts(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        return dt.astimezone().strftime("%m/%d %H:%M")
    except:
        return ts[:16]

labels   = [fmt_ts(r["ts"]) for r in rows]
dl_data  = [r["dl"]   for r in rows]
ul_data  = [r["ul"]   for r in rows]
ping_data= [r["ping"] for r in rows]
jitter_data = [r["jitter"] for r in rows]
loss_data= [r["loss"] for r in rows]

avg_dl   = sum(dl_data) / len(dl_data)
avg_ul   = sum(ul_data) / len(ul_data)
avg_ping = sum(ping_data) / len(ping_data)
min_dl   = min(dl_data);  max_dl  = max(dl_data)
min_ul   = min(ul_data);  max_ul  = max(ul_data)
min_ping = min(ping_data);max_ping= max(ping_data)
last     = rows[-1]

title_suffix = f"— Last {args.last}" if args.last else ("— Today" if args.today else "— All time")

# ── HTML ──────────────────────────────────────────────────────────────────────
html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Speedtest Analysis</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation@3.0.1/dist/chartjs-plugin-annotation.min.js"></script>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          background: #0f1117; color: #e2e8f0; padding: 24px; }}
  h1   {{ font-size: 1.4rem; font-weight: 600; margin-bottom: 4px; }}
  .sub {{ color: #64748b; font-size: 0.85rem; margin-bottom: 24px; }}
  .stat-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
                gap: 12px; margin-bottom: 28px; }}
  .stat {{ background: #1e2130; border-radius: 10px; padding: 14px 18px; }}
  .stat .label {{ font-size: 0.72rem; color: #64748b; text-transform: uppercase;
                  letter-spacing: .05em; margin-bottom: 4px; }}
  .stat .value {{ font-size: 1.6rem; font-weight: 700; }}
  .stat .sub2  {{ font-size: 0.75rem; color: #94a3b8; margin-top: 2px; }}
  .dl  {{ color: #38bdf8; }}
  .ul  {{ color: #34d399; }}
  .png {{ color: #f59e0b; }}
  .chart-wrap {{ background: #1e2130; border-radius: 12px; padding: 20px;
                 margin-bottom: 20px; }}
  .chart-wrap h2 {{ font-size: 0.9rem; color: #94a3b8; margin-bottom: 16px; font-weight: 500; }}
  canvas {{ max-height: 260px; }}
</style>
</head>
<body>

<h1>📶 Speedtest Analysis {title_suffix}</h1>
<p class="sub">{len(rows)} samples · last run {fmt_ts(last["ts"])} · {last["server"] or "unknown server"}</p>

<div class="stat-grid">
  <div class="stat">
    <div class="label">Download avg</div>
    <div class="value dl">{avg_dl:.0f}</div>
    <div class="sub2">Mbps &nbsp;·&nbsp; min {min_dl:.0f} / max {max_dl:.0f}</div>
  </div>
  <div class="stat">
    <div class="label">Upload avg</div>
    <div class="value ul">{avg_ul:.0f}</div>
    <div class="sub2">Mbps &nbsp;·&nbsp; min {min_ul:.0f} / max {max_ul:.0f}</div>
  </div>
  <div class="stat">
    <div class="label">Ping avg</div>
    <div class="value png">{avg_ping:.1f}</div>
    <div class="sub2">ms &nbsp;·&nbsp; min {min_ping:.1f} / max {max_ping:.1f}</div>
  </div>
  <div class="stat">
    <div class="label">Last download</div>
    <div class="value dl">{last["dl"]:.0f}</div>
    <div class="sub2">Mbps</div>
  </div>
  <div class="stat">
    <div class="label">Last upload</div>
    <div class="value ul">{last["ul"]:.0f}</div>
    <div class="sub2">Mbps</div>
  </div>
  <div class="stat">
    <div class="label">Last ping</div>
    <div class="value png">{last["ping"]:.1f}</div>
    <div class="sub2">ms</div>
  </div>
</div>

<!-- Throughput chart -->
<div class="chart-wrap">
  <h2>Download &amp; Upload (Mbps)</h2>
  <canvas id="throughput"></canvas>
</div>

<!-- Ping / jitter chart -->
<div class="chart-wrap">
  <h2>Ping &amp; Jitter (ms)</h2>
  <canvas id="latency"></canvas>
</div>

<!-- Packet loss chart -->
<div class="chart-wrap">
  <h2>Packet Loss (%)</h2>
  <canvas id="loss"></canvas>
</div>

<script>
const labels  = {json.dumps(labels)};
const dlData  = {json.dumps(dl_data)};
const ulData  = {json.dumps(ul_data)};
const pingData= {json.dumps(ping_data)};
const jitterData = {json.dumps(jitter_data)};
const lossData= {json.dumps(loss_data)};

const avgDl   = {avg_dl:.2f};
const avgUl   = {avg_ul:.2f};
const avgPing = {avg_ping:.2f};

const gridColor  = 'rgba(255,255,255,0.06)';
const tickColor  = '#64748b';
const baseOpts   = (yLabel) => ({{
  responsive: true,
  interaction: {{ mode: 'index', intersect: false }},
  plugins: {{
    legend: {{ labels: {{ color: '#94a3b8', boxWidth: 12, font: {{ size: 11 }} }} }},
    annotation: {{}}
  }},
  scales: {{
    x: {{
      ticks: {{ color: tickColor, maxTicksLimit: 10, maxRotation: 0, font: {{ size: 10 }} }},
      grid:  {{ color: gridColor }}
    }},
    y: {{
      title: {{ display: true, text: yLabel, color: tickColor, font: {{ size: 10 }} }},
      ticks: {{ color: tickColor, font: {{ size: 10 }} }},
      grid:  {{ color: gridColor }}
    }}
  }}
}});

// Throughput
const tpOpts = baseOpts('Mbps');
tpOpts.plugins.annotation = {{
  annotations: {{
    avgDlLine: {{
      type: 'line', yMin: avgDl, yMax: avgDl,
      borderColor: 'rgba(56,189,248,0.4)', borderWidth: 1, borderDash: [4,3],
      label: {{ content: `avg ↓ ${{avgDl.toFixed(0)}}`, display: true,
                position: 'start', color: '#38bdf8', font: {{ size: 9 }}, backgroundColor: 'transparent' }}
    }},
    avgUlLine: {{
      type: 'line', yMin: avgUl, yMax: avgUl,
      borderColor: 'rgba(52,211,153,0.4)', borderWidth: 1, borderDash: [4,3],
      label: {{ content: `avg ↑ ${{avgUl.toFixed(0)}}`, display: true,
                position: 'end', color: '#34d399', font: {{ size: 9 }}, backgroundColor: 'transparent' }}
    }}
  }}
}};
new Chart(document.getElementById('throughput'), {{
  type: 'line',
  data: {{
    labels,
    datasets: [
      {{ label: '↓ Download', data: dlData,   borderColor: '#38bdf8', backgroundColor: 'rgba(56,189,248,0.12)',
         fill: true, tension: 0.3, pointRadius: labels.length > 60 ? 0 : 2, borderWidth: 2 }},
      {{ label: '↑ Upload',   data: ulData,   borderColor: '#34d399', backgroundColor: 'rgba(52,211,153,0.08)',
         fill: true, tension: 0.3, pointRadius: labels.length > 60 ? 0 : 2, borderWidth: 2 }},
    ]
  }},
  options: tpOpts
}});

// Latency
const latOpts = baseOpts('ms');
latOpts.plugins.annotation = {{
  annotations: {{
    avgPingLine: {{
      type: 'line', yMin: avgPing, yMax: avgPing,
      borderColor: 'rgba(245,158,11,0.4)', borderWidth: 1, borderDash: [4,3],
      label: {{ content: `avg ${{avgPing.toFixed(1)}}ms`, display: true,
                position: 'start', color: '#f59e0b', font: {{ size: 9 }}, backgroundColor: 'transparent' }}
    }}
  }}
}};
new Chart(document.getElementById('latency'), {{
  type: 'line',
  data: {{
    labels,
    datasets: [
      {{ label: 'Ping',   data: pingData,   borderColor: '#f59e0b', backgroundColor: 'rgba(245,158,11,0.10)',
         fill: true, tension: 0.3, pointRadius: labels.length > 60 ? 0 : 2, borderWidth: 2 }},
      {{ label: 'Jitter', data: jitterData, borderColor: '#c084fc', backgroundColor: 'rgba(192,132,252,0.08)',
         fill: false, tension: 0.3, pointRadius: labels.length > 60 ? 0 : 2, borderWidth: 1.5, borderDash: [3,2] }},
    ]
  }},
  options: latOpts
}});

// Packet loss
new Chart(document.getElementById('loss'), {{
  type: 'bar',
  data: {{
    labels,
    datasets: [
      {{ label: 'Packet Loss %', data: lossData, backgroundColor: 'rgba(248,113,113,0.7)',
         borderColor: '#f87171', borderWidth: 1 }}
    ]
  }},
  options: baseOpts('%')
}});
</script>
</body>
</html>
"""

# ── write & open ──────────────────────────────────────────────────────────────
out_file = os.path.join(script_dir, "data", "report.html")
with open(out_file, "w") as f:
    f.write(html)

print(f"Chart written → {out_file}")

if not args.no_open:
    url = f"file://{os.path.abspath(out_file)}"
    opened = webbrowser.open(url)
    if not opened:
        print(f"Could not open browser automatically (no display?).")
        print(f"Open this file in your browser:\n  {url}")
