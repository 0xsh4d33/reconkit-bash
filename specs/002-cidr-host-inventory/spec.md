# Feature Specification: CIDR Host Inventory

**Feature Branch**: `002-cidr-host-inventory`

**Created**: 2026-07-28

**Status**: Draft

**Input**: User description: "I need a separate script that will take CIDR like 192.168.0.0/16. Takes IP rage like 192.168.0.0/16, for each IP tries to resolve its Domain name -> each address is scanned using nmap with list of specified ports needed for scanning -> each host is scanned using httpx. As the output we get a csv that has columns Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, Tech Version. The domain may not be resolved. + since we'll scan /16 we should ensure that scan runs quickly"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate CIDR Host Inventory (Priority: P1)

A security operator provides an authorized CIDR range and selected ports, then receives one CSV that lists discovered host services and web metadata for addresses in that range.

**Why this priority**: This is the core workflow and produces the host-based inventory the user needs from an IP range rather than from known subdomains.

**Independent Test**: Can be fully tested with a small controlled CIDR range containing known reachable and unreachable IPs, known open services, and known web metadata, then confirming the CSV contains the required columns and expected rows.

**Acceptance Scenarios**:

1. **Given** a valid CIDR range and selected ports, **When** the user runs the host inventory, **Then** the output CSV includes Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, and Tech Version for discovered findings.
2. **Given** an address has no resolvable domain name, **When** a service or web endpoint is discovered on that address, **Then** the CSV includes the IP with an empty Domain field.
3. **Given** an address has multiple open services, **When** the inventory is generated, **Then** each open service is represented independently in the CSV.
4. **Given** a web endpoint exposes multiple detectable technologies, **When** the inventory is generated, **Then** each technology is represented in the CSV while preserving the same IP, port, status, and title context.

---

### User Story 2 - Complete Large Range Scans Efficiently (Priority: P2)

A security operator scans a large authorized network such as a `/16` and needs the run to avoid wasting time on inactive hosts or unbounded per-address work.

**Why this priority**: A `/16` can contain 65,536 addresses, so performance and progress behavior determine whether the separate script is usable in practice.

**Independent Test**: Can be tested with a generated large-range fixture and controlled responder set, then confirming inactive addresses are skipped after host discovery and the run completes within the configured performance budget.

**Acceptance Scenarios**:

1. **Given** a `/16` CIDR range, **When** the inventory starts, **Then** the system discovers responsive hosts before running detailed service and web checks.
2. **Given** many inactive addresses, **When** the scan runs, **Then** inactive addresses do not receive detailed port or web probing.
3. **Given** a long-running scan, **When** the user reviews progress or diagnostics, **Then** they can tell that work is advancing and which stage is running.

---

### User Story 3 - Preserve Review-Ready Output Under Partial Data (Priority: P3)

A reviewer opens the generated CSV after a mixed scan where some names did not resolve, some services lacked versions, and some web probes lacked technologies, while still being able to sort and filter the output without cleanup.

**Why this priority**: Range scans commonly have incomplete host metadata, but the report must remain accurate and usable.

**Independent Test**: Can be tested with fixtures containing unresolved names, non-web services, missing service versions, blank technologies, duplicate findings, commas, quotes, and line breaks in field values.

**Acceptance Scenarios**:

1. **Given** reverse name resolution fails for an IP, **When** the CSV is produced, **Then** the Domain field is empty and the row still includes discovered IP and service data.
2. **Given** a non-web service is detected, **When** the CSV is produced, **Then** HTTP-specific columns are empty for that row.
3. **Given** values contain commas, quotes, or line breaks, **When** the CSV is generated, **Then** the file remains valid and spreadsheet-compatible.
4. **Given** identical findings are observed more than once, **When** the CSV is produced, **Then** duplicate rows are removed.

### Edge Cases

- CIDR input is malformed, outside supported address families, or expands to no usable host addresses.
- The user provides a very large range such as `/16`.
- Network discovery finds no responsive hosts.
- Reverse name resolution fails, times out, or returns multiple names for one IP.
- An address responds to host discovery but selected ports are closed or filtered.
- A port is open but the service name or version cannot be identified.
- A web endpoint returns status and title but no technology details.
- A web endpoint redirects, times out, or returns an error status.
- CSV values contain delimiters, quotes, or newline characters.
- The scan is interrupted before completion.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a user-provided CIDR range as the scan target.
- **FR-002**: The system MUST validate the CIDR input before scanning and report invalid ranges without starting discovery.
- **FR-003**: The system MUST accept a user-provided list of ports that defines the service scan scope.
- **FR-004**: The system MUST enumerate candidate IP addresses from the CIDR range.
- **FR-005**: The system MUST perform host discovery to identify responsive addresses before detailed service and web checks.
- **FR-006**: The system MUST skip detailed service and web checks for addresses that are not responsive during host discovery.
- **FR-007**: The system MUST attempt reverse name resolution for each responsive IP address.
- **FR-008**: The system MUST allow report rows where Domain is empty when reverse name resolution is unavailable.
- **FR-009**: The system MUST scan responsive addresses only against the user-specified ports.
- **FR-010**: The system MUST identify open services with protocol, service name, and service version when that information is available.
- **FR-011**: The system MUST collect web response metadata for responsive hosts when web endpoints are available, including status, title, detected technology names, and detected technology versions when available.
- **FR-012**: The system MUST produce a CSV with this exact column order: Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, Tech Version.
- **FR-013**: The system MUST create one CSV row for each unique combination of domain, IP, open port, service, and detected web technology.
- **FR-014**: The system MUST create a service row with empty HTTP-specific fields when an open non-web service is found.
- **FR-015**: The system MUST leave unavailable values empty rather than inventing placeholder values.
- **FR-016**: The system MUST report invalid input, discovery failures, reverse-resolution failures, scan failures, probe failures, and interrupted execution in diagnostics separate from the CSV data.
- **FR-017**: The system MUST preserve valid partial results when individual addresses, ports, reverse lookups, service scans, or web probes fail.
- **FR-018**: The system MUST generate standards-compatible CSV output with correct escaping for commas, quotes, and line breaks in field values.
- **FR-019**: The system MUST avoid duplicate CSV rows that represent the same domain, IP, port, service, web status, title, technology, and technology version.
- **FR-020**: The system MUST provide progress or stage diagnostics for large scans so users can distinguish discovery, service scanning, web probing, and report writing.
- **FR-021**: The system MUST provide configurable performance controls for large ranges, including limits for concurrent work and per-host or per-probe time spent.

### Key Entities

- **CIDR Target**: A user-provided network range; key attributes include CIDR text, validation status, address family, and total candidate address count.
- **Candidate Address**: An IP address derived from the CIDR target; key attributes include IP, discovery status, reverse-resolution status, and resolved domain name if available.
- **Port Selection**: The user-defined set of ports included in service discovery; key attributes include port number and scan inclusion status.
- **Service Finding**: An open service detected on a responsive address; key attributes include domain, IP, port, protocol, service name, and service version.
- **Web Finding**: Web metadata associated with an IP and service context; key attributes include HTTP status, page title, technology name, and technology version.
- **Inventory Report**: The generated CSV deliverable; key attributes include required header order, data rows, empty fields for unavailable values, and uniqueness rules.
- **Scan Run Diagnostics**: Non-CSV status and error information; key attributes include stage, target context, severity, and message.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can scan a valid `/16` range with a selected port list and receive a completed CSV without manually expanding the address range.
- **SC-002**: 100% of CSV files include the exact required headers in the required order.
- **SC-003**: For controlled targets with known responsive hosts, open services, and web metadata, at least 95% of expected reportable fields are populated accurately when targets respond within normal network conditions.
- **SC-004**: Inactive addresses discovered during the host discovery stage do not receive detailed service or web checks.
- **SC-005**: A `/16` scan with no more than 1,000 responsive hosts completes the discovery-to-report workflow within 60 minutes under normal local network conditions and default performance settings.
- **SC-006**: Failures for individual addresses, reverse lookups, service scans, or web probes do not prevent results from other valid hosts from appearing in the CSV.
- **SC-007**: A reviewer can open the generated CSV in common spreadsheet software and correctly sort or filter by Domain, IP, Port, Service, HTTP Status, and HTTP Tech without repairing delimiters or headers.

## Assumptions

- The user has authorization to scan the provided CIDR range and selected ports.
- The separate script is intended for command-line use by security or operations staff.
- The first version focuses on IPv4 CIDR input because the motivating example is IPv4 and `/16`-scale performance is central to the request.
- Reverse name resolution is best-effort and may legitimately produce an empty Domain field.
- The first version focuses on generating a local CSV report rather than uploading results to another system.
- Empty fields are acceptable for data that cannot be detected reliably.
- Performance targets assume a local or internal network and are affected by network latency, host responsiveness, selected port count, and configured concurrency.
