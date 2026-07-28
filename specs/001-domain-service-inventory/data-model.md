# Data Model: Domain Service Inventory

## Scan Target

Represents one normalized subdomain from user input.

**Fields**:

- `original_domain`: Raw input value before trimming.
- `domain`: Normalized subdomain used for resolution and reporting.
- `status`: One of `pending`, `resolved`, `unresolved`, `failed`.
- `addresses`: Zero or more resolved addresses.

**Validation Rules**:

- Blank lines and comment-only lines are ignored.
- Duplicate normalized domains are processed once.
- Domain value must be non-empty after trimming.

**Relationships**:

- Has many Resolved Addresses.
- Uses one Resolver Configuration for name resolution during a run.
- Has zero or more Web Findings.

## Resolver Configuration

Represents the DNS resolver behavior selected for one inventory run.

**Fields**:

- `mode`: `default` when using environment name resolution, or `explicit` when the user provides a resolver address.
- `resolver_address`: User-provided resolver IP address, empty in `default` mode.
- `validation_status`: One of `not_required`, `valid`, `invalid`, `unreachable`, `non_responsive`.
- `diagnostic_message`: Human-readable resolver validation or failure detail, empty when no issue is detected.

**Validation Rules**:

- Explicit resolver address must be syntactically valid as an IPv4 or IPv6 address.
- Default mode does not require resolver address validation.
- Resolver failures are reported as diagnostics and must not create resolved-address records.

**Relationships**:

- Applies to all Scan Targets in a run.
- Influences whether Scan Targets transition to `resolved`, `unresolved`, or `failed`.

## Resolved Address

Represents one IP address for a scan target.

**Fields**:

- `domain`: Associated scan target.
- `ip`: Resolved IPv4 or IPv6 address.
- `address_family`: `ipv4` or `ipv6`.
- `status`: One of `pending`, `scanned`, `failed`.

**Validation Rules**:

- Address must be syntactically valid for its address family.
- Duplicate domain/address pairs are processed once.

**Relationships**:

- Belongs to one Scan Target.
- Has zero or more Service Findings.

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

- Applies to all Resolved Addresses in the run.

## Service Finding

Represents an open service discovered on a resolved address.

**Fields**:

- `domain`: Report domain.
- `ip`: Report address.
- `port`: Open port number.
- `protocol`: Transport protocol, usually `tcp`.
- `service`: Service name, optionally including detected product when useful for reporting.
- `service_version`: Detected service version, empty when unavailable.

**Validation Rules**:

- Port must be part of the Port Selection.
- Protocol must be populated when reported by the scanner.
- Service version remains empty when unavailable.
- Closed and filtered ports do not create Service Findings.

**Relationships**:

- Belongs to one Resolved Address.
- May be associated with zero or more Web Findings.

## Web Finding

Represents HTTP response and technology metadata discovered for a domain endpoint.

**Fields**:

- `domain`: Report domain.
- `ip`: Associated resolved address when it can be correlated.
- `port`: Associated service port when it can be correlated.
- `http_status`: Numeric response status, empty when unavailable.
- `http_title`: Page title, empty when unavailable.
- `http_tech`: Detected technology name, empty when unavailable.
- `tech_version`: Detected technology version, empty when unavailable.

**Validation Rules**:

- HTTP status must be numeric when present.
- Title, technology, and version values must be CSV-escaped when exported.
- Multiple detected technologies for one endpoint produce multiple report rows.
- Duplicate endpoint/technology/version rows are collapsed.

**Relationships**:

- Belongs to one Scan Target.
- May enrich one Service Finding when endpoint port and domain context match.

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
- Empty values are represented as empty CSV fields.
- Values containing commas, quotes, carriage returns, or line breaks are quoted and escaped.
- Rows are unique by all output columns.

## State Transitions

```text
Resolver Configuration: default -> not_required
Resolver Configuration: explicit -> valid
Resolver Configuration: explicit -> invalid
Resolver Configuration: explicit -> unreachable
Resolver Configuration: explicit -> non_responsive

Scan Target: pending -> resolved -> scanned
Scan Target: pending -> unresolved
Scan Target: pending -> failed
Scan Target: pending/resolved -> failed

Resolved Address: pending -> scanned
Resolved Address: pending -> failed

Service Finding: discovered -> exported
Web Finding: discovered -> correlated -> exported
Inventory Report Row: assembled -> deduplicated -> written
```
