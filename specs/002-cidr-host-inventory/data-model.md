# Data Model: CIDR Host Inventory

## CIDR Target

Represents the user-provided IPv4 network range.

**Fields**:

- `cidr`: Raw CIDR input.
- `network_address`: Normalized network address.
- `prefix_length`: Numeric prefix length.
- `address_family`: `ipv4`.
- `candidate_count`: Number of usable candidate addresses.
- `validation_status`: One of `valid`, `invalid`, `unsupported`, `empty`.

**Validation Rules**:

- CIDR must be syntactically valid IPv4 CIDR.
- Prefix length must produce at least one usable candidate address.
- Unsupported address families are rejected before discovery starts.

**Relationships**:

- Has many Candidate Addresses.
- Has one Scan Run Diagnostics stream.

## Candidate Address

Represents one IP address derived from the CIDR target.

**Fields**:

- `ip`: IPv4 address.
- `discovery_status`: One of `pending`, `responsive`, `inactive`, `failed`.
- `reverse_resolution_status`: One of `not_attempted`, `resolved`, `unresolved`, `failed`, `timeout`.
- `domain`: Reverse-resolved domain name, empty when unavailable.

**Validation Rules**:

- IP must belong to the CIDR Target.
- Detailed service and web checks run only when `discovery_status` is `responsive`.
- Domain remains empty when reverse resolution is unavailable.

**Relationships**:

- Belongs to one CIDR Target.
- Has zero or more Service Findings.
- Has zero or more Web Findings through detected web endpoints.

## Port Selection

Represents the user-defined service scan scope.

**Fields**:

- `port`: Numeric port value.
- `included`: Whether the port is part of this run.

**Validation Rules**:

- Port values must be integers from 1 through 65535.
- Duplicate ports are scanned once.
- Empty port selection is invalid.

**Relationships**:

- Applies to all responsive Candidate Addresses.

## Performance Controls

Represents user-configurable limits for large scans.

**Fields**:

- `discovery_concurrency`: Maximum concurrent discovery work where applicable.
- `scan_concurrency`: Maximum concurrent service scan work.
- `probe_concurrency`: Maximum concurrent web probe work.
- `host_timeout`: Maximum time spent per host or per host-stage operation.
- `probe_timeout`: Maximum time spent per web probe.

**Validation Rules**:

- Concurrency values must be positive integers.
- Timeout values must be positive durations.
- Defaults must allow a `/16` with no more than 1,000 responsive hosts to meet the success criteria under normal local network conditions.

**Relationships**:

- Applies to discovery, service scanning, reverse resolution, and web probing stages.

## Service Finding

Represents an open service discovered on a responsive address.

**Fields**:

- `domain`: Reverse-resolved domain, empty when unavailable.
- `ip`: Responsive address.
- `port`: Open port number.
- `protocol`: Transport protocol, usually `tcp`.
- `service`: Service name, optionally including detected product when useful for reporting.
- `service_version`: Detected service version, empty when unavailable.

**Validation Rules**:

- Port must be part of the Port Selection.
- Closed and filtered ports do not create Service Findings.
- Service version remains empty when unavailable.

**Relationships**:

- Belongs to one Candidate Address.
- May be associated with zero or more Web Findings.

## Web Finding

Represents HTTP response and technology metadata discovered for a responsive host endpoint.

**Fields**:

- `domain`: Reverse-resolved domain, empty when unavailable.
- `ip`: Responsive address.
- `port`: Associated service port when it can be correlated.
- `http_status`: Numeric response status, empty when unavailable.
- `http_title`: Page title, empty when unavailable.
- `http_tech`: Detected technology name, empty when unavailable.
- `tech_version`: Detected technology version, empty when unavailable.

**Validation Rules**:

- HTTP status must be numeric when present.
- Multiple detected technologies for one endpoint produce multiple report rows.
- Duplicate endpoint/technology/version rows are collapsed.

**Relationships**:

- Belongs to one Candidate Address.
- May enrich one Service Finding when endpoint port and IP context match.

## Inventory Report Row

Represents one row in the final CSV.

**Fields**:

- `Domain`
- `IP`
- `Port`
- `Protocol`
- `Service`
- `Service Version`
- `HTTP Status`
- `HTTP Title`
- `HTTP Tech`
- `Tech Version`

**Validation Rules**:

- Header order must exactly match the required field order.
- Domain may be empty.
- Empty values are represented as empty CSV fields.
- Values containing commas, quotes, carriage returns, or line breaks are quoted and escaped.
- Rows are unique by all output columns.

## Scan Run Diagnostics

Represents progress, warning, and error output outside the CSV.

**Fields**:

- `stage`: `input`, `discovery`, `reverse_dns`, `service_scan`, `web_probe`, `report`.
- `target`: CIDR, IP, port, or endpoint context.
- `severity`: `info`, `warning`, `error`.
- `message`: Human-readable status or failure detail.

**Validation Rules**:

- Diagnostics must not be written as CSV rows.
- Large scans must emit enough stage information for users to identify current progress.

## State Transitions

```text
CIDR Target: raw -> valid
CIDR Target: raw -> invalid
CIDR Target: raw -> unsupported

Candidate Address: pending -> responsive
Candidate Address: pending -> inactive
Candidate Address: pending -> failed

Reverse Resolution: not_attempted -> resolved
Reverse Resolution: not_attempted -> unresolved
Reverse Resolution: not_attempted -> timeout
Reverse Resolution: not_attempted -> failed

Service Finding: discovered -> exported
Web Finding: discovered -> correlated -> exported
Inventory Report Row: assembled -> deduplicated -> written
```
