# CLI Contract: Domain Service Inventory

## Command

```text
./end-scanner.sh --domains <path> --ports <ports> --output <path> [options]
```

## Required Arguments

| Argument | Description | Validation |
|----------|-------------|------------|
| `--domains <path>` | File containing one subdomain per line. | File must exist and be readable. |
| `--ports <ports>` | Comma-separated ports or path to a file containing ports. | Each port must be an integer from 1 through 65535. |
| `--output <path>` | CSV report destination. | Parent directory must exist and be writable. |

## Optional Arguments

| Argument | Description | Default |
|----------|-------------|---------|
| `--log <path>` | Diagnostic log destination for unresolved domains, scan failures, probe failures, and interruptions. | Standard error |
| `--dns-server <ip>` | DNS resolver address to use for all subdomain resolution in this run. | Environment default resolver |
| `--tmp-dir <path>` | Directory for temporary scanner/prober outputs. | System temporary directory |
| `--timeout <seconds>` | Per-target command timeout where supported by dependencies. | Tool default |
| `--help` | Show usage and exit. | None |

## DNS Resolution

Default form:

```text
./end-scanner.sh --domains domains.txt --ports 80,443 --output inventory.csv
```

Explicit resolver form:

```text
./end-scanner.sh --domains domains.txt --ports 80,443 --dns-server 10.10.10.53 --output inventory.csv
```

Rules:

- When `--dns-server` is omitted, use the environment's normal resolver behavior.
- When `--dns-server` is present, use that resolver for every subdomain resolution in the run.
- Accept syntactically valid IPv4 and IPv6 resolver addresses.
- Reject invalid resolver address syntax before scanning starts.
- Report unreachable or non-responsive resolver behavior in diagnostics.
- Do not create resolved-address records from failed resolver responses.

## Input Domain File

```text
sub1.example.com
sub2.example.com
# comments are ignored
sub3.example.com
```

Rules:

- Trim surrounding whitespace.
- Ignore blank lines.
- Ignore lines beginning with `#` after trimming.
- Process duplicate normalized domains once.

## Port Input

Inline form:

```text
80,443,8080,8443
```

File form:

```text
80
443
8080
8443
```

Rules:

- Ignore blank lines in port files.
- Ignore duplicate ports.
- Reject invalid, empty, or out-of-range values.

## CSV Output

The first row must be exactly:

```csv
Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version
```

Rows use this field order:

| Column | Required | Empty When |
|--------|----------|------------|
| Domain | Yes | Never for exported findings |
| IP | Yes | Never for service findings |
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
| `1` | Invalid command arguments, invalid resolver address syntax, or unreadable/unwritable paths. |
| `2` | Required dependency is missing. |
| `3` | No valid scan targets or no valid ports were provided. |
| `4` | Execution failed before a CSV could be written. |
| `130` | Interrupted by the user. Partial results may exist if the CSV was already being written. |

## Diagnostics

Diagnostics are written to the configured log destination or standard error. They must include enough context for review:

- Unresolved domain name.
- Invalid, unreachable, or non-responsive DNS resolver.
- Dependency command failure.
- Scan or probe timeout.
- Output parsing failure.
- Interrupted execution.

Diagnostics must not change the CSV header or add non-data rows to the CSV.
