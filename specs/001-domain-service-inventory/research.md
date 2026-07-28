# Research: Domain Service Inventory

## Decision: Use Bash as the implementation language

**Rationale**: The requested deliverable is a Bash script, and the workflow is command orchestration around DNS resolution, service scanning, web probing, and file generation. Bash keeps the tool easy to run in the intended environment.

**Alternatives considered**: Python or Go would simplify structured parsing and concurrency, but they would move away from the requested script format and add runtime or build expectations not required for the first version.

## Decision: Treat `nmap` as the source of service findings

**Rationale**: The feature explicitly requires scanning each resolved address with `nmap` against a specified port list. `nmap` can report protocol, service name, and service version in structured XML output, which maps directly to the CSV service columns.

**Alternatives considered**: Raw socket checks or `nc` would detect open ports but would not provide comparable service/version metadata. Other scanners would not match the requested toolchain.

## Decision: Parse structured scanner output, not human-readable text

**Rationale**: XML output from service scans avoids brittle parsing of localized or spacing-sensitive terminal output. This supports reliable extraction of port, protocol, service name, product, and version fields.

**Alternatives considered**: Grepping normal scanner output is simpler initially but likely to break across versions, services, and formatting changes.

## Decision: Treat ProjectDiscovery `httpx` JSONL as the source of web findings

**Rationale**: The feature explicitly requires web probing with `httpx`. JSONL output can include status code, title, web server, detected technologies, and technology versions where available. It is better suited for a script pipeline than parsing terminal table output.

**Alternatives considered**: Browser automation or direct HTTP requests would add complexity and would not provide the requested technology fingerprinting behavior.

## Decision: Use `jq` for web metadata extraction

**Rationale**: `jq` is widely available in command-line security workflows and provides reliable parsing of JSONL records and nested technology metadata without hand-written shell JSON parsing.

**Alternatives considered**: Shell string manipulation is too error-prone for JSON. A custom parser would add complexity without value.

## Decision: Keep CSV generation inside the script with a dedicated escaping helper

**Rationale**: The output format is central to the feature. A dedicated CSV function can consistently quote fields containing commas, quotes, carriage returns, or newlines while leaving unavailable values empty.

**Alternatives considered**: Passing rows through external spreadsheet tools would add unnecessary dependencies. Simple comma concatenation would fail for page titles and technology names containing delimiters.

## Decision: Preserve partial results and write diagnostics outside the CSV

**Rationale**: The CSV should remain review-ready data, while unresolved domains, command failures, timeouts, and interruptions should be visible in a separate diagnostic stream or log. This matches the requirement to preserve successful findings without polluting report rows.

**Alternatives considered**: Adding error rows to the CSV would complicate downstream sorting and violate the required report shape.

## Decision: Use fixture-based tests for scanner and prober output

**Rationale**: Real network scans are slow, environment-dependent, and may require permissions. Fixtures allow repeatable tests for parsing, row merging, deduplication, and CSV formatting, while separate integration tests can validate the live command path when dependencies are installed.

**Alternatives considered**: Only live tests would be unreliable in CI and local development. Only unit tests would miss end-to-end row assembly behavior.

## Decision: Use an explicit resolver path when the user provides a DNS server

**Rationale**: Some internal networks require resolving target subdomains through a specific DNS server that is not configured as the host default. Using an explicit resolver-aware DNS query path for that mode lets the inventory run without changing system resolver settings and makes the selected resolver behavior auditable.

**Alternatives considered**: Rewriting host resolver configuration would be invasive and risky for a local script. Always using the system resolver would fail in networks where the needed resolver must be selected manually. Running all resolution through explicit public resolvers would be inappropriate for internal target names.

## Decision: Validate resolver syntax before resolution and report resolver failures separately

**Rationale**: Invalid, unreachable, or non-responsive resolver addresses should not create misleading unresolved-domain results. Distinguishing resolver failure from a domain not existing helps the user correct network configuration before trusting report coverage.

**Alternatives considered**: Treating resolver errors as normal unresolved domains is simpler, but it hides an environment problem that can invalidate the scan. Failing the whole run for one resolver issue is appropriate only when no target can be resolved through the selected resolver; otherwise diagnostics and partial results preserve useful work.
