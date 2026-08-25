#!/usr/bin/env python3
"""
cidr_report.py — Parse a CIDR/network scan inventory CSV and generate
a self-contained HTML report, then update a shared index.html.

Usage:
    python3 cidr_report.py [input.csv] [output.html]

Defaults:
    input  → cidrinventory.csv
    output → cidr_report.html

Each run also updates reports_index.json and index.html in the same
directory as the output file so all reports are browseable from one page.

CSV expected columns (order matters for auto-detect, but header names are used):
    Domain, IP, Port, Protocol, Service, Service Version,
    HTTP Status, HTTP Title, HTTP Tech, Tech Version
"""

import csv
import sys
import os
import json
import html
from collections import defaultdict
from datetime import datetime

# ── Column name aliases (lowercase) ─────────────────────────────────────────
COL = {
    "domain":          ["domain"],
    "ip":              ["ip", "ip address", "ipaddress"],
    "port":            ["port"],
    "protocol":        ["protocol", "proto"],
    "service":         ["service", "svc"],
    "service_version": ["service version", "serviceversion", "version"],
    "http_status":     ["http status", "httpstatus", "status code", "statuscode"],
    "http_title":      ["http title", "httptitle", "title"],
    "http_tech":       ["http tech", "httptech", "technology", "tech"],
    "tech_version":    ["tech version", "techversion"],
}


def normalize_header(h):
    return h.strip().lower().replace("-", " ").replace("_", " ")


def map_columns(header_row):
    """Return dict {canonical_key: csv_column_index} from a header row."""
    norm = [normalize_header(h) for h in header_row]
    mapping = {}
    for key, aliases in COL.items():
        for alias in aliases:
            if alias in norm:
                mapping[key] = norm.index(alias)
                break
    return mapping


def get(row, mapping, key, default=""):
    idx = mapping.get(key)
    if idx is None or idx >= len(row):
        return default
    return row[idx].strip()


def status_class(code):
    """CSS class for an HTTP status code string."""
    if not code:
        return "status-none"
    try:
        n = int(code)
        if n < 300:
            return "status-2xx"
        if n < 400:
            return "status-3xx"
        if n < 500:
            return "status-4xx"
        return "status-5xx"
    except ValueError:
        return "status-none"


def load_csv(path):
    """Return list of dicts with canonical keys."""
    rows = []
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.reader(f)
        header = next(reader)
        mapping = map_columns(header)
        for row in reader:
            if not any(c.strip() for c in row):
                continue
            rows.append({
                "domain":          get(row, mapping, "domain"),
                "ip":              get(row, mapping, "ip"),
                "port":            get(row, mapping, "port"),
                "protocol":        get(row, mapping, "protocol"),
                "service":         get(row, mapping, "service"),
                "service_version": get(row, mapping, "service_version"),
                "http_status":     get(row, mapping, "http_status"),
                "http_title":      get(row, mapping, "http_title"),
                "http_tech":       get(row, mapping, "http_tech"),
                "tech_version":    get(row, mapping, "tech_version"),
            })
    return rows


def build_stats(rows):
    unique_ips     = len({r["ip"] for r in rows if r["ip"]})
    unique_domains = len({r["domain"] for r in rows if r["domain"]})
    total_ports    = len(rows)
    services       = defaultdict(int)
    statuses       = defaultdict(int)
    for r in rows:
        if r["service"]:
            services[r["service"].lower()] += 1
        if r["http_status"]:
            statuses[r["http_status"]] += 1
    return {
        "unique_ips":     unique_ips,
        "unique_domains": unique_domains,
        "total_ports":    total_ports,
        "services":       dict(sorted(services.items(), key=lambda x: -x[1])),
        "statuses":       dict(sorted(statuses.items())),
    }


def group_by_ip(rows):
    """Return OrderedDict: ip → list of rows (sorted by port)."""
    groups = defaultdict(list)
    for r in rows:
        groups[r["ip"]].append(r)
    for ip in groups:
        groups[ip].sort(key=lambda r: int(r["port"]) if r["port"].isdigit() else 0)
    return dict(sorted(groups.items()))


# ── HTML generation ──────────────────────────────────────────────────────────

HTML_HEAD = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CIDR Inventory Report</title>
<style>
  /* ── Reset & base ── */
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  :root {
    --bg:        #0f1117;
    --surface:   #1a1d27;
    --surface2:  #22263a;
    --border:    #2d3148;
    --accent:    #5b8aff;
    --accent2:   #7c4dff;
    --text:      #e2e8f0;
    --muted:     #8892a4;
    --green:     #34d399;
    --yellow:    #fbbf24;
    --red:       #f87171;
    --purple:    #a78bfa;
    --cyan:      #22d3ee;
    --radius:    8px;
    --shadow:    0 4px 24px rgba(0,0,0,.4);
  }
  body {
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
    padding: 24px 16px 60px;
  }

  /* ── Layout ── */
  .container { max-width: 1200px; margin: 0 auto; }

  /* ── Header ── */
  .page-header {
    display: flex; align-items: center; justify-content: space-between;
    flex-wrap: wrap; gap: 12px;
    padding: 20px 28px;
    background: linear-gradient(135deg, var(--surface) 0%, var(--surface2) 100%);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    margin-bottom: 24px;
    box-shadow: var(--shadow);
  }
  .page-header h1 {
    font-size: 1.45rem; font-weight: 700; letter-spacing: -.3px;
    background: linear-gradient(90deg, var(--accent), var(--accent2));
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .page-header .meta { font-size: .8rem; color: var(--muted); }

  /* ── Search bar ── */
  .search-row {
    display: flex; align-items: center; gap: 10px;
    margin-bottom: 20px;
  }
  .search-row input {
    flex: 1; padding: 10px 16px;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); color: var(--text);
    font-size: .9rem; outline: none; transition: border-color .2s;
  }
  .search-row input:focus { border-color: var(--accent); }
  .search-row input::placeholder { color: var(--muted); }

  /* ── Stat cards ── */
  .stats-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
    gap: 12px;
    margin-bottom: 24px;
  }
  .stat-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 18px 20px;
    text-align: center;
    transition: border-color .2s;
  }
  .stat-card:hover { border-color: var(--accent); }
  .stat-card .val {
    font-size: 2rem; font-weight: 800; line-height: 1.1;
    background: linear-gradient(135deg, var(--accent), var(--cyan));
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .stat-card .lbl { font-size: .78rem; color: var(--muted); margin-top: 4px; text-transform: uppercase; letter-spacing: .6px; }

  /* ── Service + Status pills ── */
  .pills-row { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 24px; }
  .pill {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 5px 12px;
    border-radius: 99px;
    font-size: .78rem; font-weight: 600;
    border: 1px solid transparent;
  }
  .pill-svc  { background: rgba(91,138,255,.12); border-color: rgba(91,138,255,.3); color: var(--accent); }
  .pill-http { background: rgba(52,211,153,.1);  border-color: rgba(52,211,153,.3); color: var(--green); }
  .pill-cnt  { background: rgba(255,255,255,.07); border-radius: 99px; padding: 2px 7px; font-size: .72rem; color: var(--muted); }

  /* ── IP group cards ── */
  .ip-group {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    margin-bottom: 16px;
    overflow: hidden;
    transition: border-color .2s;
  }
  .ip-group:hover { border-color: rgba(91,138,255,.4); }
  .ip-group-header {
    display: flex; align-items: center; justify-content: space-between;
    padding: 14px 20px;
    background: var(--surface2);
    cursor: pointer; user-select: none;
    gap: 12px; flex-wrap: wrap;
  }
  .ip-group-header .ip-label {
    font-family: 'Cascadia Code', 'Fira Code', 'Consolas', monospace;
    font-size: 1.05rem; font-weight: 700; color: var(--cyan);
  }
  .ip-group-header .domain-label {
    font-size: .82rem; color: var(--muted); margin-left: 4px;
  }
  .ip-group-header .port-count {
    font-size: .8rem; color: var(--muted);
    background: rgba(255,255,255,.06); padding: 3px 10px; border-radius: 99px;
  }
  .toggle-icon { color: var(--muted); font-size: .9rem; transition: transform .2s; }
  .ip-group.collapsed .toggle-icon { transform: rotate(-90deg); }
  .ip-group.collapsed .ip-table-wrap { display: none; }

  /* ── Port table ── */
  .ip-table-wrap { overflow-x: auto; }
  table {
    width: 100%; border-collapse: collapse;
    font-size: .85rem;
  }
  thead th {
    padding: 10px 14px;
    text-align: left;
    font-size: .75rem; font-weight: 600;
    text-transform: uppercase; letter-spacing: .5px;
    color: var(--muted);
    border-bottom: 1px solid var(--border);
    white-space: nowrap;
    background: rgba(0,0,0,.15);
  }
  tbody tr { border-bottom: 1px solid rgba(45,49,72,.5); transition: background .15s; }
  tbody tr:last-child { border-bottom: none; }
  tbody tr:hover { background: rgba(91,138,255,.06); }
  tbody td { padding: 10px 14px; vertical-align: middle; }

  /* Port badge */
  .port-badge {
    display: inline-block;
    font-family: 'Cascadia Code', 'Fira Code', monospace;
    font-size: .82rem; font-weight: 700;
    padding: 3px 9px; border-radius: 6px;
    background: rgba(124,77,255,.15); color: var(--purple);
    border: 1px solid rgba(124,77,255,.25);
  }
  /* Protocol */
  .proto-badge {
    font-size: .72rem; font-weight: 600; text-transform: uppercase;
    padding: 2px 8px; border-radius: 4px;
    background: rgba(255,255,255,.06); color: var(--muted);
    border: 1px solid var(--border);
  }
  /* Service */
  .svc-http   { color: var(--green);  }
  .svc-https  { color: var(--cyan);   }
  .svc-ssh    { color: var(--yellow); }
  .svc-ftp    { color: var(--purple); }
  .svc-other  { color: var(--text);   }

  /* HTTP status */
  .status-badge {
    display: inline-block; font-weight: 700; padding: 2px 9px;
    border-radius: 6px; font-size: .82rem;
  }
  .status-2xx { background: rgba(52,211,153,.15); color: var(--green); border: 1px solid rgba(52,211,153,.3); }
  .status-3xx { background: rgba(251,191,36,.12);  color: var(--yellow); border: 1px solid rgba(251,191,36,.3); }
  .status-4xx { background: rgba(248,113,113,.12); color: var(--red);    border: 1px solid rgba(248,113,113,.3); }
  .status-5xx { background: rgba(248,113,113,.2);  color: var(--red);    border: 1px solid rgba(248,113,113,.4); }
  .status-none{ color: var(--muted); font-style: italic; font-size: .8rem; }

  /* Tech */
  .tech-tag {
    display: inline-block; font-size: .75rem; padding: 2px 8px;
    border-radius: 4px; border: 1px solid var(--border);
    background: rgba(255,255,255,.04); color: var(--muted); margin-right: 4px;
  }

  /* no-data */
  .no-results {
    text-align: center; padding: 48px; color: var(--muted);
    font-size: 1rem;
  }

  /* ── Footer ── */
  .page-footer {
    text-align: center; margin-top: 36px;
    font-size: .78rem; color: var(--muted);
  }
</style>
</head>
<body>
<div class="container">
"""

HTML_FOOT = """\
</div>
<script>
// ── Collapse/expand IP groups ──────────────────────────────────────────────
document.querySelectorAll('.ip-group-header').forEach(hdr => {
  hdr.addEventListener('click', () => {
    hdr.closest('.ip-group').classList.toggle('collapsed');
  });
});

// ── Live search ────────────────────────────────────────────────────────────
const searchInput = document.getElementById('search');
const groups      = document.querySelectorAll('.ip-group');

searchInput.addEventListener('input', () => {
  const q = searchInput.value.trim().toLowerCase();
  groups.forEach(grp => {
    const text = grp.textContent.toLowerCase();
    const match = !q || text.includes(q);
    grp.style.display = match ? '' : 'none';
    if (match && q) grp.classList.remove('collapsed');
  });
  document.getElementById('no-results').style.display =
    [...groups].every(g => g.style.display === 'none') ? '' : 'none';
});
</script>
</body>
</html>
"""


def svc_class(svc):
    s = svc.lower()
    if s in ("https", "ssl/https"):
        return "svc-https"
    if s in ("http",):
        return "svc-http"
    if "ssh" in s:
        return "svc-ssh"
    if "ftp" in s:
        return "svc-ftp"
    return "svc-other"


def e(s):
    """HTML-escape a string."""
    return html.escape(s or "")


def render_tech(tech, ver):
    parts = [t.strip() for t in tech.split(",") if t.strip()] if tech else []
    if not parts:
        return '<span class="status-none">—</span>'
    tags = "".join(
        f'<span class="tech-tag">{e(t)}{(" " + e(ver)) if ver and i == 0 else ""}</span>'
        for i, t in enumerate(parts)
    )
    return tags


def generate_html(rows, source_file):
    stats  = build_stats(rows)
    groups = group_by_ip(rows)
    gen_ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    parts  = [HTML_HEAD]

    # ── Page header ──
    parts.append(f"""
  <div class="page-header">
    <div>
      <h1>&#128202; CIDR Inventory Report</h1>
      <div class="meta">Source: <code>{e(os.path.basename(source_file))}</code></div>
    </div>
    <div class="meta" style="text-align:right">
      Generated<br><strong>{gen_ts}</strong>
    </div>
  </div>
""")

    # ── Stats ──
    parts.append('<div class="stats-grid">')
    for val, lbl in [
        (stats["unique_ips"],     "Unique IPs"),
        (stats["unique_domains"], "Domains"),
        (stats["total_ports"],    "Open Ports"),
        (len(stats["services"]),  "Services"),
        (sum(stats["statuses"].values()), "HTTP Endpoints"),
    ]:
        parts.append(f"""
  <div class="stat-card">
    <div class="val">{val}</div>
    <div class="lbl">{lbl}</div>
  </div>""")
    parts.append("</div>\n")

    # ── Service + HTTP status pills ──
    parts.append('<div class="pills-row">')
    for svc, cnt in list(stats["services"].items())[:12]:
        parts.append(f'<span class="pill pill-svc">{e(svc)}<span class="pill-cnt">{cnt}</span></span>')
    for code, cnt in stats["statuses"].items():
        parts.append(f'<span class="pill pill-http">HTTP {e(code)}<span class="pill-cnt">{cnt}</span></span>')
    parts.append("</div>\n")

    # ── Search ──
    parts.append("""
  <div class="search-row">
    <input id="search" type="text" placeholder="&#128269;  Filter by IP, domain, port, service, title…">
  </div>
  <div id="no-results" class="no-results" style="display:none">No matching entries found.</div>
""")

    # ── IP groups ──
    for ip, ip_rows in groups.items():
        domain = next((r["domain"] for r in ip_rows if r["domain"]), "")
        domain_html = f'<span class="domain-label">({e(domain)})</span>' if domain else ""
        parts.append(f"""
  <div class="ip-group">
    <div class="ip-group-header">
      <div>
        <span class="ip-label">{e(ip)}</span>
        {domain_html}
      </div>
      <div style="display:flex;align-items:center;gap:10px">
        <span class="port-count">{len(ip_rows)} port{'s' if len(ip_rows) != 1 else ''}</span>
        <span class="toggle-icon">&#9660;</span>
      </div>
    </div>
    <div class="ip-table-wrap">
      <table>
        <thead>
          <tr>
            <th>Port</th>
            <th>Proto</th>
            <th>Service</th>
            <th>Version</th>
            <th>HTTP Status</th>
            <th>Page Title</th>
            <th>Technology</th>
          </tr>
        </thead>
        <tbody>
""")
        for r in ip_rows:
            sc   = status_class(r["http_status"])
            sv   = e(r["service_version"])
            tech = render_tech(r["http_tech"], r["tech_version"])
            title = e(r["http_title"]) or '<span class="status-none">—</span>'
            status_html = (
                f'<span class="status-badge {sc}">{e(r["http_status"])}</span>'
                if r["http_status"]
                else '<span class="status-none">—</span>'
            )
            parts.append(f"""
          <tr>
            <td><span class="port-badge">{e(r['port'])}</span></td>
            <td><span class="proto-badge">{e(r['protocol']) or '—'}</span></td>
            <td><span class="{svc_class(r['service'])}">{e(r['service']) or '—'}</span></td>
            <td style="color:var(--muted);font-size:.8rem">{sv or '—'}</td>
            <td>{status_html}</td>
            <td style="max-width:260px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">{title}</td>
            <td>{tech}</td>
          </tr>""")
        parts.append("        </tbody>\n      </table>\n    </div>\n  </div>")

    # ── Footer ──
    parts.append(f"""
  <div class="page-footer">
    Generated by cidr_report.py &middot; {gen_ts} &middot; {len(rows)} record{'s' if len(rows) != 1 else ''}
  </div>
""")
    parts.append(HTML_FOOT)
    return "".join(parts)


# ── Index maintenance ────────────────────────────────────────────────────────

INDEX_JSON = "reports_index.json"
INDEX_HTML = "index.html"

INDEX_HEAD = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CIDR Reports Index</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  :root {
    --bg:      #0f1117;
    --surface: #1a1d27;
    --surface2:#22263a;
    --border:  #2d3148;
    --accent:  #5b8aff;
    --accent2: #7c4dff;
    --text:    #e2e8f0;
    --muted:   #8892a4;
    --green:   #34d399;
    --cyan:    #22d3ee;
    --purple:  #a78bfa;
    --radius:  8px;
    --shadow:  0 4px 24px rgba(0,0,0,.4);
  }
  body {
    font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
    background: var(--bg); color: var(--text);
    min-height: 100vh; padding: 24px 16px 60px;
  }
  .container { max-width: 960px; margin: 0 auto; }

  /* Header */
  .page-header {
    display: flex; align-items: center; justify-content: space-between;
    flex-wrap: wrap; gap: 12px;
    padding: 20px 28px;
    background: linear-gradient(135deg, var(--surface) 0%, var(--surface2) 100%);
    border: 1px solid var(--border); border-radius: var(--radius);
    margin-bottom: 24px; box-shadow: var(--shadow);
  }
  .page-header h1 {
    font-size: 1.45rem; font-weight: 700; letter-spacing: -.3px;
    background: linear-gradient(90deg, var(--accent), var(--accent2));
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .page-header .meta { font-size: .8rem; color: var(--muted); }

  /* Search */
  .search-row { display: flex; gap: 10px; margin-bottom: 20px; }
  .search-row input {
    flex: 1; padding: 10px 16px;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); color: var(--text);
    font-size: .9rem; outline: none; transition: border-color .2s;
  }
  .search-row input:focus { border-color: var(--accent); }
  .search-row input::placeholder { color: var(--muted); }

  /* Sort bar */
  .sort-bar {
    display: flex; align-items: center; gap: 8px;
    margin-bottom: 16px; font-size: .8rem; color: var(--muted);
  }
  .sort-btn {
    padding: 4px 12px; border-radius: 99px; cursor: pointer;
    background: var(--surface); border: 1px solid var(--border);
    color: var(--muted); font-size: .78rem; transition: all .15s;
  }
  .sort-btn:hover, .sort-btn.active {
    border-color: var(--accent); color: var(--accent);
    background: rgba(91,138,255,.08);
  }

  /* Report cards */
  .report-grid { display: flex; flex-direction: column; gap: 12px; }
  .report-card {
    display: flex; align-items: stretch;
    background: var(--surface); border: 1px solid var(--border);
    border-radius: var(--radius); overflow: hidden;
    text-decoration: none; color: inherit;
    transition: border-color .2s, box-shadow .2s, transform .15s;
  }
  .report-card:hover {
    border-color: rgba(91,138,255,.5);
    box-shadow: 0 0 0 1px rgba(91,138,255,.15), var(--shadow);
    transform: translateY(-1px);
  }
  .card-accent {
    width: 4px; flex-shrink: 0;
    background: linear-gradient(180deg, var(--accent), var(--accent2));
  }
  .card-body {
    flex: 1; padding: 16px 20px;
    display: flex; align-items: center; justify-content: space-between;
    flex-wrap: wrap; gap: 12px;
  }
  .card-left { min-width: 0; }
  .card-title {
    font-size: 1rem; font-weight: 700;
    font-family: 'Cascadia Code', 'Fira Code', monospace;
    color: var(--cyan); white-space: nowrap;
    overflow: hidden; text-overflow: ellipsis;
    margin-bottom: 4px;
  }
  .card-source { font-size: .78rem; color: var(--muted); }
  .card-ts { font-size: .75rem; color: var(--muted); margin-top: 2px; }
  .card-stats {
    display: flex; gap: 20px; flex-shrink: 0; flex-wrap: wrap;
  }
  .stat { text-align: center; }
  .stat .val {
    font-size: 1.35rem; font-weight: 800; line-height: 1;
    background: linear-gradient(135deg, var(--accent), var(--cyan));
    -webkit-background-clip: text; -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  .stat .lbl {
    font-size: .68rem; color: var(--muted);
    text-transform: uppercase; letter-spacing: .5px;
  }
  .card-arrow {
    align-self: center; color: var(--muted); font-size: 1.1rem;
    margin-left: 8px; transition: color .2s;
  }
  .report-card:hover .card-arrow { color: var(--accent); }

  /* Services pill row on each card */
  .card-pills { display: flex; flex-wrap: wrap; gap: 5px; margin-top: 7px; }
  .cpill {
    font-size: .7rem; padding: 2px 8px; border-radius: 99px;
    background: rgba(91,138,255,.1); color: var(--accent);
    border: 1px solid rgba(91,138,255,.25); font-weight: 600;
  }

  /* Empty state */
  .empty {
    text-align: center; padding: 60px 20px; color: var(--muted); font-size: 1rem;
  }

  /* Footer */
  .page-footer {
    text-align: center; margin-top: 36px;
    font-size: .78rem; color: var(--muted);
  }
</style>
</head>
<body>
<div class="container">
"""

INDEX_FOOT = """\
</div>
<script>
const cards   = [...document.querySelectorAll('.report-card')];
const search  = document.getElementById('search');
const noRes   = document.getElementById('no-results');

// ── Search ─────────────────────────────────────────────────────────────────
search.addEventListener('input', filter);
function filter() {
  const q = search.value.trim().toLowerCase();
  cards.forEach(c => {
    c.style.display = (!q || c.textContent.toLowerCase().includes(q)) ? '' : 'none';
  });
  noRes.style.display = cards.every(c => c.style.display === 'none') ? '' : 'none';
}

// ── Sort ───────────────────────────────────────────────────────────────────
document.querySelectorAll('.sort-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.sort-btn').forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    const key = btn.dataset.sort;
    const grid = document.getElementById('report-grid');
    const sorted = cards.slice().sort((a, b) => {
      const av = a.dataset[key], bv = b.dataset[key];
      if (key === 'ts') return bv.localeCompare(av);
      return Number(bv) - Number(av);
    });
    sorted.forEach(c => grid.appendChild(c));
    filter();
  });
});
</script>
</body>
</html>
"""


def load_index(index_dir):
    """Load existing reports_index.json or return empty list."""
    path = os.path.join(index_dir, INDEX_JSON)
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_index(index_dir, entries):
    path = os.path.join(index_dir, INDEX_JSON)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(entries, f, indent=2, ensure_ascii=False)


def update_index_entry(entries, entry):
    """Insert or replace entry by report filename."""
    for i, ex in enumerate(entries):
        if ex["file"] == entry["file"]:
            entries[i] = entry
            return entries
    entries.insert(0, entry)
    return entries


def generate_index_html(entries, index_dir):
    total = len(entries)
    ts_now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    parts = [INDEX_HEAD]

    # Header
    parts.append(f"""
  <div class="page-header">
    <div>
      <h1>&#128202; CIDR Reports Index</h1>
      <div class="meta">{total} report{'s' if total != 1 else ''} on record</div>
    </div>
    <div class="meta" style="text-align:right">Last updated<br><strong>{ts_now}</strong></div>
  </div>
""")

    # Search + sort bar
    parts.append("""
  <div class="search-row">
    <input id="search" type="text" placeholder="&#128269;  Filter by filename, source, services…">
  </div>
  <div class="sort-bar">
    Sort by:
    <button class="sort-btn active" data-sort="ts">Date ▾</button>
    <button class="sort-btn" data-sort="ports">Ports ▾</button>
    <button class="sort-btn" data-sort="ips">IPs ▾</button>
  </div>
  <div id="no-results" class="empty" style="display:none">No matching reports.</div>
""")

    # Cards
    parts.append('  <div class="report-grid" id="report-grid">\n')

    if not entries:
        parts.append('    <div class="empty">No reports generated yet. Run cidr_report.py to get started.</div>\n')
    else:
        for en in entries:
            fname      = e(en.get("file", ""))
            src_name   = e(en.get("source", ""))
            ts         = e(en.get("generated_at", ""))
            n_ips      = en.get("unique_ips", 0)
            n_ports    = en.get("total_ports", 0)
            n_domains  = en.get("unique_domains", 0)
            n_http     = en.get("http_endpoints", 0)
            services   = en.get("services", {})
            svc_pills  = "".join(
                f'<span class="cpill">{e(s)}</span>'
                for s in list(services.keys())[:6]
            )
            parts.append(f"""
    <a class="report-card" href="{fname}"
       data-ts="{ts}" data-ips="{n_ips}" data-ports="{n_ports}">
      <div class="card-accent"></div>
      <div class="card-body">
        <div class="card-left">
          <div class="card-title">&#128196; {fname}</div>
          <div class="card-source">Source: {src_name}</div>
          <div class="card-ts">Generated {ts}</div>
          <div class="card-pills">{svc_pills}</div>
        </div>
        <div class="card-stats">
          <div class="stat"><div class="val">{n_ips}</div><div class="lbl">IPs</div></div>
          <div class="stat"><div class="val">{n_ports}</div><div class="lbl">Ports</div></div>
          <div class="stat"><div class="val">{n_http}</div><div class="lbl">HTTP</div></div>
          <div class="stat"><div class="val">{n_domains}</div><div class="lbl">Domains</div></div>
        </div>
        <div class="card-arrow">&#8250;</div>
      </div>
    </a>""")

    parts.append("  </div>\n")
    parts.append(f"""
  <div class="page-footer">
    cidr_report.py index &middot; {ts_now}
  </div>
""")
    parts.append(INDEX_FOOT)
    return "".join(parts)


def write_index(rows, src, dest):
    """Update reports_index.json and regenerate index.html."""
    index_dir  = os.path.dirname(os.path.abspath(dest))
    stats      = build_stats(rows)
    entry = {
        "file":            os.path.basename(dest),
        "source":          os.path.basename(src),
        "generated_at":    datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "unique_ips":      stats["unique_ips"],
        "unique_domains":  stats["unique_domains"],
        "total_ports":     stats["total_ports"],
        "http_endpoints":  sum(stats["statuses"].values()),
        "services":        stats["services"],
    }
    entries = load_index(index_dir)
    entries = update_index_entry(entries, entry)
    save_index(index_dir, entries)

    index_html = generate_index_html(entries, index_dir)
    idx_path   = os.path.join(index_dir, INDEX_HTML)
    with open(idx_path, "w", encoding="utf-8") as f:
        f.write(index_html)
    return idx_path


def main():
    src  = sys.argv[1] if len(sys.argv) > 1 else "cidrinventory.csv"
    dest = sys.argv[2] if len(sys.argv) > 2 else "cidr_report.html"

    if not os.path.exists(src):
        print(f"[error] File not found: {src}", file=sys.stderr)
        sys.exit(1)

    rows = load_csv(src)
    if not rows:
        print("[warning] No data rows found in CSV.", file=sys.stderr)

    html_out = generate_html(rows, src)
    with open(dest, "w", encoding="utf-8") as f:
        f.write(html_out)

    idx_path = write_index(rows, src, dest)

    unique_ips = len({r["ip"] for r in rows})
    print(f"[ok] Report  → {dest}  ({len(rows)} records, {unique_ips} unique IPs)")
    print(f"[ok] Index   → {idx_path}")


if __name__ == "__main__":
    main()
