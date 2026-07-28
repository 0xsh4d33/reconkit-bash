# Feature Specification: Domain Service Inventory

**Feature Branch**: `001-domain-service-inventory`

**Created**: 2026-07-25

**Status**: Draft

**Input**: User description: "I need a bash script that will do next. take a list of subdomains -> for each domain we resolve IP address -> each address is scanned using nmap with list of specified ports needed for scanning -> each subdomain is scanned using httpx. As the output we get a csv that has columns Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, Tech Version. We should also ensure that we can specify DNS server for name resolution, because we'll run the script from within a network that may require for us to manually specify DNS server ip."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Consolidated Inventory (Priority: P1)

A security operator provides a list of subdomains and a list of ports, then receives one CSV that combines each domain's resolved addresses, detected open services, and web application details.

**Why this priority**: This is the primary workflow and produces the report needed for service inventory and review.

**Independent Test**: Can be fully tested by scanning a small controlled set of subdomains with known address, service, and web metadata expectations, then confirming the CSV contains the required columns and matching rows.

**Acceptance Scenarios**:

1. **Given** an input list with reachable subdomains and specified ports, **When** the user runs the inventory, **Then** the output CSV includes rows with Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, and Tech Version values where discovered.
2. **Given** a subdomain resolves to more than one address, **When** the inventory is generated, **Then** each resolved address is represented independently in the output for the applicable discovered services.
3. **Given** a web endpoint exposes multiple detectable technologies, **When** the inventory is generated, **Then** each technology is represented in the CSV while preserving the same domain, IP, port, status, and title context.
4. **Given** the user provides a specific DNS resolver address, **When** the inventory resolves subdomains, **Then** resolution uses that resolver for the run instead of relying on the environment default.

---

### User Story 2 - Preserve Partial Results (Priority: P2)

A security operator scans mixed-quality input where some subdomains do not resolve, some ports are closed, and some web probes return no metadata, while still receiving a useful CSV for all discovered data.

**Why this priority**: Real target lists often include stale or unavailable hosts, and the inventory remains valuable only if successful findings are not blocked by failures elsewhere.

**Independent Test**: Can be tested with a list containing one resolvable host, one unresolvable host, one open service, and one closed or filtered port, then confirming successful findings are still exported and failures are reported clearly.

**Acceptance Scenarios**:

1. **Given** a subdomain cannot be resolved, **When** the inventory runs, **Then** that failure is reported without stopping scans for other subdomains.
2. **Given** a service has no detected version, **When** the CSV is produced, **Then** the Service Version field is left empty rather than filled with misleading data.
3. **Given** a non-web service is detected, **When** the CSV is produced, **Then** HTTP-specific columns are left empty for that row.

---

### User Story 3 - Produce Review-Ready CSV (Priority: P3)

A reviewer opens the generated CSV in spreadsheet or analysis tooling and can sort, filter, and compare domains, addresses, services, and technologies without manual cleanup.

**Why this priority**: The output must be immediately usable for investigation, reporting, and follow-up prioritization.

**Independent Test**: Can be tested by opening the CSV in a spreadsheet-compatible reader and validating the header order, escaping, blank fields, and row consistency.

**Acceptance Scenarios**:

1. **Given** service names, titles, or technology values contain spaces, commas, or quotes, **When** the CSV is generated, **Then** fields are escaped so the file remains valid.
2. **Given** no open services are found for a resolved address on the selected ports, **When** the CSV is produced, **Then** no false service rows are created for that address.
3. **Given** the same technology is detected once for a web endpoint, **When** the CSV is produced, **Then** the report does not duplicate identical rows for that endpoint and technology.

### Edge Cases

- Input contains blank lines, surrounding whitespace, comments, or duplicate subdomains.
- A subdomain resolves to IPv4 and IPv6 addresses.
- A user-provided DNS resolver address is unreachable, invalid, or refuses responses.
- A subdomain resolves successfully but none of the selected ports are open.
- A port is detected as open but the service name or version cannot be identified.
- A web endpoint returns an HTTP status and title but no technology details.
- A web endpoint redirects, times out, or returns an error status.
- Detected technology has a name but no version.
- CSV values contain delimiter, quote, or newline characters.
- The scan is interrupted before completion.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept a user-provided list of subdomains as scan targets.
- **FR-002**: The system MUST accept a user-provided list of ports that defines the service scan scope.
- **FR-003**: The system MUST normalize the subdomain list by ignoring empty entries and preventing duplicate target processing.
- **FR-004**: The system MUST resolve each subdomain to its available network addresses before service inventory is attempted.
- **FR-005**: The system MUST allow the user to optionally specify a DNS resolver address for subdomain name resolution.
- **FR-006**: When a DNS resolver address is specified, the system MUST use that resolver for all subdomain resolution performed during the run.
- **FR-007**: When no DNS resolver address is specified, the system MUST use the environment's default name resolution behavior.
- **FR-008**: The system MUST report invalid, unreachable, or non-responsive user-specified DNS resolvers in diagnostics without producing misleading resolved-address data.
- **FR-009**: The system MUST scan each resolved address only against the user-specified ports.
- **FR-010**: The system MUST identify open services with protocol, service name, and service version when that information is available.
- **FR-011**: The system MUST collect web response metadata for each subdomain when web endpoints are available, including status, title, detected technology names, and detected technology versions when available.
- **FR-012**: The system MUST produce a CSV with this exact column order: Domain, IP, Port, Protocol, Service, Service Version, HTTP Status, HTTP Title, HTTP Tech, Tech Version.
- **FR-013**: The system MUST create one CSV row for each unique combination of domain, resolved address, open port, service, and detected web technology.
- **FR-014**: The system MUST create a service row with empty HTTP-specific fields when an open non-web service is found.
- **FR-015**: The system MUST leave unavailable values empty rather than inventing placeholder values.
- **FR-016**: The system MUST report unresolved domains, scan failures, probe failures, resolver failures, and interrupted execution in a way the user can review separately from the CSV data.
- **FR-017**: The system MUST preserve valid partial results when individual domains, addresses, ports, resolvers, or web probes fail.
- **FR-018**: The system MUST generate standards-compatible CSV output with correct escaping for commas, quotes, and line breaks in field values.
- **FR-019**: The system MUST avoid duplicate CSV rows that represent the same domain, address, port, service, web status, title, technology, and technology version.

### Key Entities

- **Scan Target**: A subdomain supplied by the user; key attributes include original domain text, normalized domain text, resolution status, and resolved addresses.
- **Resolver Configuration**: Optional user-provided DNS resolver settings for a run; key attributes include resolver address, validation status, and whether default environment resolution or explicit resolver resolution is used.
- **Resolved Address**: A network address associated with a scan target; key attributes include address value and address family.
- **Port Selection**: The user-defined set of ports included in service discovery; key attributes include port number and scan inclusion status.
- **Service Finding**: An open service detected on a resolved address; key attributes include domain, address, port, protocol, service name, and service version.
- **Web Finding**: Web metadata associated with a domain and service context; key attributes include HTTP status, page title, technology name, and technology version.
- **Inventory Report**: The generated CSV deliverable; key attributes include required header order, data rows, empty fields for unavailable values, and uniqueness rules.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can run an inventory for at least 100 subdomains and 20 selected ports and receive a completed CSV without manual post-processing of the file format.
- **SC-002**: 100% of CSV files include the exact required headers in the required order.
- **SC-003**: For controlled targets with known open services and web metadata, at least 95% of expected reportable fields are populated accurately when the target responds within normal network conditions.
- **SC-004**: Failures for individual subdomains or probes do not prevent results from other valid targets from appearing in the CSV.
- **SC-005**: A reviewer can open the generated CSV in common spreadsheet software and correctly sort or filter by Domain, IP, Port, Service, HTTP Status, and HTTP Tech without repairing delimiters or headers.
- **SC-006**: In a controlled network where target domains resolve only through a specified resolver, the user can provide that resolver and complete the inventory without changing host-level DNS settings.

## Assumptions

- The user has authorization to scan all provided subdomains and ports.
- The feature is intended for command-line use by security or operations staff.
- The first version focuses on generating a local CSV report rather than uploading results to another system.
- Web metadata is associated with detected web endpoints for the subdomain and included only when available.
- Empty fields are acceptable for data that cannot be detected reliably.
- If the user does not specify a DNS resolver, the environment's normal resolver configuration is acceptable.
- Operational dependencies for resolving addresses, scanning selected ports, and collecting web metadata are available in the user's environment.
