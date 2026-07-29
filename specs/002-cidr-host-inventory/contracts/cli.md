# CLI Contract: CIDR Host Inventory

## Command

```text
./cidr-scanner.sh --cidr <cidr> --ports <ports> --output <path> [options]
```

## Required Arguments

| Argument | Description | Validation |
|----------|-------------|------------|
| `--cidr <cidr>` | IPv4 CIDR range to inventory, such as `192.168.0.0/16`. | Must be a valid IPv4 CIDR with at least one usable candidate address. |
| `--ports <ports>` | Comma-separated ports or path to a file containing ports. | Each port must be an integer from 1 through 65535. |
| `--output <path>` | CSV report destination. | Parent directory must exist and be writable. |

## Optional Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--log <path>` | Diagnostic and progress log destination. | Standard error |
| `--tmp-dir <path>` | Directory for temporary discovery, scanner, and prober outputs. | System temporary directory |
| `--max-discovery-jobs <count>` | Maximum concurrent discovery work where applicable. | Conservative internal-network default |
| `--max-scan-jobs <count>` | Maximum concurrent service scan work. | Conservative internal-network default |
| `--max-probe-jobs <count>` | Maximum concurrent web probe work. | Conservative internal-network default |
| `--host-timeout <seconds>` | Per-host or per-host-stage timeout where supported. | Tool default chosen for `/16` usability |
| `--probe-timeout <seconds>` | Per-web-probe timeout where supported. | Tool default chosen for `/16` usability |
| `--help` | Show usage and exit. | None |

## CIDR Input

Valid example:

```text
192.168.0.0/16
```

Rules:

- Accept IPv4 CIDR notation.
- Reject malformed ranges before discovery starts.
- Reject unsupported address families before discovery starts.
- Report the number of candidate addresses in diagnostics.

## Port Input

Inline form:

```text
22,80,443,8080,8443
```

File form:

```text
22
80
443
8080
8443
```

Rules:

- Ignore blank lines in port files.
- Ignore duplicate ports.
- Reject invalid, empty, or out-of-range values.

## Execution Behavior

Required stage order:

1. Validate CIDR, ports, output path, and performance controls.
2. Discover responsive hosts in the CIDR range.
3. Attempt reverse name resolution for responsive hosts.
4. Scan selected ports only on responsive hosts.
5. Probe web endpoints only for responsive hosts and relevant web services.
6. Write the CSV report.

Rules:

- Inactive hosts must not receive detailed service or web checks.
- Reverse name resolution is best-effort; unresolved names produce empty Domain fields.
- Progress diagnostics must identify the active stage for long scans.
- Invalid input exits before network discovery starts.

## CSV Output

The first row must be exactly:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

Rows use this field order:

| Column | Required | Empty When |
|--------|----------|------------|
| Domain | No | Reverse name resolution is unavailable |
| IP | Yes | Never for exported findings |
| Port | Yes | Never for service findings |
| Protocol | Yes | Never when reported by service scan |
| Service | Yes | Never when an open service is detected |
| Service Version | No | Version cannot be detected |
| HTTP Status | No | No web response metadata is available |
| HTTP Title | No | No page title is available |
| HTTP Tech | No | No technology is detected |
| Tech Version | No | No technology version is detected |

CSV escaping rules:

- Quote fields containing comma, quote, carriage return, or line break.
- Escape embedded quotes by doubling them.
- Preserve empty fields as empty CSV fields.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Completed and wrote the CSV. Individual target failures may still be present in diagnostics. |
| `1` | Invalid command arguments, invalid CIDR, invalid performance controls, or unreadable/unwritable paths. |
| `2` | Required dependency is missing. |
| `3` | No valid candidate hosts, no responsive hosts, or no valid ports were available for detailed scanning. |
| `4` | Execution failed before a CSV could be written. |
| `130` | Interrupted by the user. Partial results may exist if the CSV was already being written. |

## Diagnostics

Diagnostics are written to the configured log destination or standard error. They must include enough context for review:

- CIDR validation status and candidate address count.
- Discovery stage start, progress, and responsive host count.
- Reverse name resolution failures or timeouts.
- Service scan failures.
- Web probe failures or timeouts.
- Report writing status.
- Interrupted execution.

Diagnostics must not change the CSV header or add non-data rows to the CSV.
