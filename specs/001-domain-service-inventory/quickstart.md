# Quickstart: Domain Service Inventory

## Prerequisites

- Linux shell with Bash 4.4 or newer.
- `nmap` installed and available on `PATH`.
- ProjectDiscovery `httpx` installed and available on `PATH`.
- `jq` installed and available on `PATH`.
- XML parser support through `xmllint` or `xmlstarlet`.
- Authorization to scan every target in the input list.

## Prepare Sample Inputs

Create a domain list:

```bash
printf '%s\n' \
  'sub1.example.com' \
  'sub2.example.com' \
  '# ignored comment' \
  'sub1.example.com' \
  > domains.txt
```

Choose a port list:

```bash
printf '%s\n' '22' '80' '443' > ports.txt
```

## Run Inventory

```bash
./end-scanner.sh --domains domains.txt --ports ports.txt --output inventory.csv --log inventory.log
```

Expected outcome:

- `inventory.csv` exists.
- First row is exactly `Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version`.
- Duplicate input domains are processed once.
- Open non-web services have empty HTTP fields.
- Web endpoints with multiple detected technologies produce one row per technology.
- `inventory.log` contains unresolved domain or probe failure diagnostics, if any.

## Run Inventory With Explicit DNS Resolver

Use this form when target names resolve only through a specific network resolver:

```bash
./end-scanner.sh --domains domains.txt --ports ports.txt --dns-server 10.10.10.53 --output inventory.csv --log inventory.log
```

Expected outcome:

- Resolution uses `10.10.10.53` for every subdomain in the run.
- The command does not require changing host-level DNS settings.
- Invalid, unreachable, or non-responsive resolver behavior is written to `inventory.log`.
- The CSV does not include rows based on failed resolver responses.

## Validate CSV Shape

```bash
head -n 1 inventory.csv
```

Expected output:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

Open the CSV with spreadsheet software or parse it with a CSV-aware tool to confirm titles and technologies containing commas or quotes remain in the correct columns.

## Validate Partial Failure Behavior

Add an intentionally invalid domain to the input:

```bash
printf '%s\n' 'does-not-resolve.invalid' >> domains.txt
./end-scanner.sh --domains domains.txt --ports ports.txt --output inventory.csv --log inventory.log
```

Expected outcome:

- The command completes if at least one valid target can be processed.
- Valid findings remain in `inventory.csv`.
- The unresolved domain is reported in `inventory.log`.

## Validate Resolver Failure Behavior

Run with an intentionally invalid resolver value:

```bash
./end-scanner.sh --domains domains.txt --ports ports.txt --dns-server not-an-ip --output inventory.csv --log inventory.log
```

Expected outcome:

- The command exits with the invalid argument exit code from the CLI contract.
- The diagnostic log identifies the resolver value as invalid.
- No misleading resolved-address rows are written from the invalid resolver configuration.

## Validate With Fixtures

When implementation tasks add tests, use fixture outputs under `tests/fixtures/` to verify:

- Scanner XML parsing creates expected Service Findings.
- Web JSONL parsing creates expected Web Findings.
- Explicit DNS resolver handling uses the configured resolver and reports resolver failures separately from unresolved domains.
- CSV escaping handles commas, quotes, and line breaks.
- Deduplication removes identical report rows.

See [CLI contract](./contracts/cli.md) and [data model](./data-model.md) for the expected behavior each validation scenario must prove.
