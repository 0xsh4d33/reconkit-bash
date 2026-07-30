# Service Inventory Scanners

`end-scanner.sh` resolves authorized subdomains, scans selected ports with `nmap`, probes web services with ProjectDiscovery `httpx`, and writes a review-ready CSV inventory.

`cidr-scanner.sh` inventories authorized IPv4 CIDR ranges. It discovers responsive hosts first, attempts reverse DNS for responsive IPs, scans only selected ports on responsive hosts, probes web endpoints, and writes the same CSV shape as the domain workflow.

## Prerequisites

- Bash 4.4 or newer on Linux
- `nmap`
- ProjectDiscovery `httpx`
- `jq`
- `dig` or `host`
- `xmllint` or `xmlstarlet`
- Authorization to scan every target

## Domain Usage

```bash
./end-scanner.sh --domains domains.txt --ports 80,443 --output inventory.csv --log inventory.log
```

Ports may also be supplied as a file:

```bash
./end-scanner.sh --domains domains.txt --ports ports.txt --output inventory.csv
```

Use `--dns-server` when internal names must resolve through a specific resolver:

```bash
./end-scanner.sh --domains domains.txt --ports ports.txt --dns-server 10.10.10.53 --output inventory.csv --log inventory.log
```

When `--dns-server` is present, every domain resolution query uses that resolver. Invalid resolver syntax exits with code `1`; resolver and target failures are written to diagnostics without adding error rows to the CSV.

## CIDR Usage

Use `cidr-scanner.sh` when the starting point is an IPv4 range rather than a domain list:

```bash
./cidr-scanner.sh --cidr 192.168.1.0/24 --ports 22,80,443 --output cidr-inventory.csv --log cidr-inventory.log
```

For larger authorized ranges, tune bounded work and per-stage timeouts:

```bash
./cidr-scanner.sh \
  --cidr 192.168.0.0/16 \
  --ports 22,80,443 \
  --max-discovery-jobs 256 \
  --max-scan-jobs 64 \
  --max-probe-jobs 64 \
  --host-timeout 3 \
  --probe-timeout 5 \
  --output cidr-inventory.csv \
  --log cidr-inventory.log
```

The CIDR scanner supports IPv4 CIDR ranges from `/16` through `/32`. It rejects invalid CIDR input before discovery, preserves empty `Domain` values when reverse DNS is unavailable, and logs `input`, `discovery`, `reverse_dns`, `service_scan`, `web_probe`, and `report` stages outside the CSV.

## Input

Domain files contain one domain per line. Blank lines and lines beginning with `#` are ignored, surrounding whitespace is trimmed, and duplicate normalized domains are processed once.

CIDR runs require `--cidr`, `--ports`, and `--output`. Ports may be supplied as a comma-separated list or as a file with one port per line; blanks are ignored, duplicates are removed, and values must be `1` through `65535`.

## Output Columns

The CSV header is always:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

Unavailable values are emitted as empty CSV fields. HTTP technologies reported by `httpx` as inline `name:version` values are split into `HTTP Tech` and `Tech Version` columns when the suffix looks version-like. Fields containing commas, quotes, carriage returns, or line breaks are quoted according to CSV rules, and exact duplicate rows are removed before writing the report.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Completed and wrote the CSV. Individual target failures may be present in diagnostics. |
| `1` | Invalid command arguments, resolver syntax, or unreadable/unwritable paths. |
| `2` | Required dependency is missing. |
| `3` | No valid scan targets, no responsive CIDR hosts, or no valid ports were provided. |
| `4` | Execution failed before a CSV could be written. |
| `130` | Interrupted by the user. |

## Quickstart Sample

```bash
printf '%s\n' \
  'sub1.example.com' \
  'sub2.example.com' \
  '# ignored comment' \
  'sub1.example.com' \
  > domains.txt

printf '%s\n' '22' '80' '443' > ports.txt

./end-scanner.sh --domains domains.txt --ports ports.txt --output inventory.csv --log inventory.log
head -n 1 inventory.csv
```

See [specs/001-domain-service-inventory/quickstart.md](specs/001-domain-service-inventory/quickstart.md) and [specs/001-domain-service-inventory/contracts/cli.md](specs/001-domain-service-inventory/contracts/cli.md) for the validation scenarios and full CLI contract.

## CIDR Quickstart Sample

```bash
./cidr-scanner.sh --cidr 192.168.1.0/24 --ports 22,80,443 --output cidr-inventory.csv --log cidr-inventory.log
head -n 1 cidr-inventory.csv
```

The first row must be:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

See [specs/002-cidr-host-inventory/quickstart.md](specs/002-cidr-host-inventory/quickstart.md) and [specs/002-cidr-host-inventory/contracts/cli.md](specs/002-cidr-host-inventory/contracts/cli.md) for CIDR validation scenarios and the full CLI contract.
