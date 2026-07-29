# Quickstart: CIDR Host Inventory

## Prerequisites

- Linux shell with Bash 4.4 or newer.
- `nmap` installed and available on `PATH`.
- ProjectDiscovery `httpx` installed and available on `PATH`.
- `jq` installed and available on `PATH`.
- XML parser support through `xmllint` or `xmlstarlet`.
- Authorization to scan the target CIDR and selected ports.

## Run A Small Validation Scan

Use a small authorized range first:

```bash
./cidr-scanner.sh --cidr 192.168.1.0/24 --ports 22,80,443 --output cidr-inventory.csv --log cidr-inventory.log
```

Expected outcome:

- `cidr-inventory.csv` exists.
- First row is exactly `Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version`.
- Responsive hosts may have populated Domain values when reverse name resolution succeeds.
- Hosts without reverse names appear with an empty Domain field.
- `cidr-inventory.log` identifies discovery, reverse DNS, service scan, web probe, and report stages.

## Run A Large Range Scan

Use performance controls for a `/16`:

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

Expected outcome:

- Discovery runs before detailed service and web checks.
- Inactive hosts do not receive detailed checks.
- Diagnostics show responsive host counts and current stage.
- The CSV contains rows only for discovered findings.

## Validate CSV Shape

```bash
head -n 1 cidr-inventory.csv
```

Expected output:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

Open the CSV with spreadsheet software or parse it with a CSV-aware tool to confirm empty Domain fields and titles or technologies containing commas or quotes remain in the correct columns.

## Validate Invalid CIDR Handling

```bash
./cidr-scanner.sh --cidr 192.168.0.0/not-a-prefix --ports 80 --output cidr-inventory.csv --log cidr-inventory.log
```

Expected outcome:

- The command exits with the invalid argument exit code from the CLI contract.
- Discovery does not start.
- The diagnostic log identifies the CIDR as invalid.

## Validate No Responsive Hosts Behavior

Run against an authorized range fixture or controlled network segment with no responsive hosts:

```bash
./cidr-scanner.sh --cidr 192.0.2.0/30 --ports 80 --output cidr-inventory.csv --log cidr-inventory.log
```

Expected outcome:

- The command reports zero responsive hosts in diagnostics.
- Detailed service and web checks are skipped.
- The command follows the CLI contract for the no-responsive-host condition.

## Validate With Fixtures

When implementation tasks add tests, use fixture outputs under `tests/fixtures/` to verify:

- CIDR validation and candidate count calculations.
- Host discovery output creates responsive and inactive Candidate Addresses.
- Reverse DNS failures leave Domain empty.
- Scanner XML parsing creates expected Service Findings.
- Web JSONL parsing creates expected Web Findings.
- Inactive hosts are not sent to service scanning or web probing.
- CSV escaping handles commas, quotes, and line breaks.
- Deduplication removes identical report rows.

See [CLI contract](./contracts/cli.md) and [data model](./data-model.md) for the expected behavior each validation scenario must prove.
