# Tasks: Domain Service Inventory

**Input**: Design documents from `/specs/001-domain-service-inventory/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/cli.md](./contracts/cli.md), [quickstart.md](./quickstart.md)

**Tests**: Included because the implementation plan defines ShellCheck, Bats, fixture-based integration tests, and quickstart validation.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and does not depend on incomplete tasks.
- **[Story]**: Maps task to a user story from [spec.md](./spec.md).
- Every task includes an exact file path.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the shell CLI project skeleton and test harness.

- [X] T001 Create executable CLI entrypoint with usage stub in end-scanner.sh
- [X] T002 [P] Create shell library directory and placeholder modules in lib/csv.sh, lib/dns.sh, lib/http_probe.sh, lib/logging.sh, lib/nmap_parse.sh, and lib/nmap_scan.sh
- [X] T003 [P] Create test directories in tests/unit, tests/integration, tests/fixtures/nmap, and tests/fixtures/httpx
- [X] T004 [P] Add project ignore rules for generated reports, logs, and temporary outputs in .gitignore
- [X] T005 [P] Add Bats test helper for running scripts from repository root in tests/test_helper.bash

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement reusable CLI, validation, logging, dependency, resolver, and CSV primitives required by all user stories.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Implement command-line argument parsing for --domains, --ports, --output, --log, --dns-server, --tmp-dir, --timeout, and --help in end-scanner.sh
- [X] T007 Implement dependency checks for bash version, nmap, httpx, jq, dig, and xmllint/xmlstarlet in end-scanner.sh
- [X] T008 [P] Implement diagnostic logging helpers with stderr/file routing in lib/logging.sh
- [X] T009 [P] Implement CSV header and field escaping helpers in lib/csv.sh
- [X] T010 [P] Implement domain input normalization, comment skipping, and deduplication helpers in lib/dns.sh
- [X] T011 [P] Implement port list parsing for comma-separated values and files in end-scanner.sh
- [X] T012 [P] Implement DNS resolver address syntax validation for IPv4 and IPv6 values in lib/dns.sh
- [X] T013 [P] Implement resolver configuration mode selection for default and explicit resolver behavior in lib/dns.sh
- [X] T014 [P] Add unit tests for CSV escaping and header output in tests/unit/csv.bats
- [X] T015 [P] Add unit tests for domain normalization and deduplication in tests/unit/dns.bats
- [X] T016 [P] Add unit tests for port parsing and invalid port rejection in tests/unit/ports.bats
- [X] T017 [P] Add unit tests for DNS resolver address validation and mode selection in tests/unit/resolver.bats

**Checkpoint**: Foundation ready. CLI validation, diagnostics, resolver configuration, CSV helpers, and input normalization are testable before scanner-specific story work starts.

---

## Phase 3: User Story 1 - Generate Consolidated Inventory (Priority: P1) MVP

**Goal**: A user provides subdomains, ports, and optionally a DNS resolver, then receives a consolidated CSV containing resolved addresses, open services, and web metadata.

**Independent Test**: Run the CLI with fixture-backed DNS, scanner, and web prober outputs for known targets, including explicit resolver mode, then verify the CSV header and expected rows match the contract.

### Tests for User Story 1

- [X] T018 [P] [US1] Add nmap XML fixture with multiple open services in tests/fixtures/nmap/basic-services.xml
- [X] T019 [P] [US1] Add httpx JSONL fixture with status, title, and multiple technologies in tests/fixtures/httpx/basic-web.jsonl
- [X] T020 [P] [US1] Add DNS fixture data for default and explicit resolver success cases in tests/fixtures/dns/basic-resolution.txt
- [X] T021 [P] [US1] Add integration test for successful consolidated inventory generation in tests/integration/us1_consolidated_inventory.bats
- [X] T022 [P] [US1] Add integration test proving --dns-server is used for all target resolution in tests/integration/us1_explicit_dns_resolver.bats

### Implementation for User Story 1

- [X] T023 [P] [US1] Implement default DNS resolution helper returning unique domain/IP/address-family records in lib/dns.sh
- [X] T024 [US1] Implement explicit DNS resolver query path that uses the configured resolver for every target in lib/dns.sh
- [X] T025 [P] [US1] Implement nmap command wrapper that scans one IP against selected ports and writes XML output in lib/nmap_scan.sh
- [X] T026 [US1] Implement nmap XML parser for open port, protocol, service, product, and version fields in lib/nmap_parse.sh
- [X] T027 [P] [US1] Implement httpx JSONL prober wrapper and metadata extraction for status, title, technologies, and versions in lib/http_probe.sh
- [X] T028 [US1] Implement inventory row assembly that correlates domain, IP, service finding, and web finding data in end-scanner.sh
- [X] T029 [US1] Implement CSV report writing with required column order in end-scanner.sh
- [X] T030 [US1] Wire the full happy-path scan flow from input files to output CSV in end-scanner.sh
- [X] T031 [US1] Run and satisfy US1 integration tests in tests/integration/us1_consolidated_inventory.bats and tests/integration/us1_explicit_dns_resolver.bats

**Checkpoint**: User Story 1 is fully functional and independently testable as the MVP, including explicit DNS resolver success behavior.

---

## Phase 4: User Story 2 - Preserve Partial Results (Priority: P2)

**Goal**: Mixed-quality input still produces useful CSV findings while unresolved domains, failed scans, resolver failures, and missing metadata are reported separately.

**Independent Test**: Run with fixtures for one resolvable domain, one unresolvable domain, an invalid or non-responsive resolver, an open service without version, and a non-web service, then verify valid CSV rows remain and diagnostics are logged.

### Tests for User Story 2

- [X] T032 [P] [US2] Add nmap XML fixture with open non-web service and missing version in tests/fixtures/nmap/partial-services.xml
- [X] T033 [P] [US2] Add httpx JSONL fixture with timeout or missing metadata cases in tests/fixtures/httpx/partial-web.jsonl
- [X] T034 [P] [US2] Add DNS fixture data for unresolved domains and resolver failure cases in tests/fixtures/dns/partial-resolution.txt
- [X] T035 [P] [US2] Add integration test for unresolved domains and partial result preservation in tests/integration/us2_partial_results.bats
- [X] T036 [P] [US2] Add integration test for invalid, unreachable, and non-responsive DNS resolver diagnostics in tests/integration/us2_resolver_failures.bats

### Implementation for User Story 2

- [X] T037 [US2] Add unresolved-domain handling that logs failures and continues scanning remaining targets in lib/dns.sh
- [X] T038 [US2] Add resolver failure handling that distinguishes invalid, unreachable, and non-responsive resolver outcomes in lib/dns.sh
- [X] T039 [US2] Add scan failure and parser failure handling that preserves successful service findings in lib/nmap_scan.sh and lib/nmap_parse.sh
- [X] T040 [US2] Add httpx failure, timeout, and missing-metadata handling that preserves available service rows in lib/http_probe.sh
- [X] T041 [US2] Add non-web service row output with empty HTTP Status, HTTP Title, HTTP Tech, and Tech Version fields in end-scanner.sh
- [X] T042 [US2] Add interruption handling that logs cancellation and exits with contract exit code 130 in end-scanner.sh
- [X] T043 [US2] Run and satisfy US2 integration tests in tests/integration/us2_partial_results.bats and tests/integration/us2_resolver_failures.bats

**Checkpoint**: User Stories 1 and 2 work independently, with partial failures visible in diagnostics and valid findings preserved.

---

## Phase 5: User Story 3 - Produce Review-Ready CSV (Priority: P3)

**Goal**: A reviewer can open, sort, filter, and compare the generated CSV without repairing headers, delimiters, blanks, or duplicate rows.

**Independent Test**: Run with fixtures containing duplicate findings and fields with commas, quotes, and line breaks, then validate the CSV with a CSV-aware reader and confirm duplicate rows are removed.

### Tests for User Story 3

- [X] T044 [P] [US3] Add CSV edge-case fixture expectations for quotes, commas, line breaks, blanks, and duplicate rows in tests/fixtures/expected-review-ready.csv
- [X] T045 [P] [US3] Add integration test for review-ready CSV escaping, sorting compatibility, and deduplication in tests/integration/us3_review_ready_csv.bats

### Implementation for User Story 3

- [X] T046 [US3] Harden CSV field escaping for commas, quotes, carriage returns, and line breaks in lib/csv.sh
- [X] T047 [US3] Implement exact-row deduplication before report write in end-scanner.sh
- [X] T048 [US3] Ensure empty unavailable values are emitted as empty CSV fields across service and web rows in end-scanner.sh
- [X] T049 [US3] Validate required header order and row uniqueness in report generation in end-scanner.sh
- [X] T050 [US3] Run and satisfy the US3 integration test in tests/integration/us3_review_ready_csv.bats

**Checkpoint**: All user stories are independently functional and the CSV is ready for spreadsheet or analysis tooling.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, documentation alignment, and maintainability work across all stories.

- [X] T051 [P] Add ShellCheck-friendly comments or suppressions only where justified in end-scanner.sh, lib/csv.sh, lib/dns.sh, lib/http_probe.sh, lib/logging.sh, lib/nmap_parse.sh, and lib/nmap_scan.sh
- [X] T052 [P] Add README usage, prerequisites, --dns-server behavior, output columns, exit codes, and authorization note in README.md
- [X] T053 Add quickstart sample input and explicit DNS resolver documentation links in README.md
- [ ] T054 Run ShellCheck across end-scanner.sh, lib/csv.sh, lib/dns.sh, lib/http_probe.sh, lib/logging.sh, lib/nmap_parse.sh, and lib/nmap_scan.sh
- [ ] T055 Run all Bats tests in tests/unit and tests/integration
- [X] T056 Run quickstart validation from specs/001-domain-service-inventory/quickstart.md
- [X] T057 Review implementation against CLI contract in specs/001-domain-service-inventory/contracts/cli.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks all user story work.
- **User Story 1 (Phase 3)**: Depends on Phase 2; delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on Phase 2 and can be implemented independently, but should be validated after US1 for full CLI behavior.
- **User Story 3 (Phase 5)**: Depends on Phase 2 and benefits from US1 row assembly, but its CSV hardening remains independently testable.
- **Polish (Phase 6)**: Depends on the desired user stories being complete.

### User Story Dependencies

- **US1 Generate Consolidated Inventory**: Start after Foundational. No dependency on other stories. Includes explicit DNS resolver success behavior.
- **US2 Preserve Partial Results**: Start after Foundational. Uses the same CLI and helpers, but is independently testable with failure fixtures, including resolver failures.
- **US3 Produce Review-Ready CSV**: Start after Foundational. Uses the same CSV helper and report writer, but is independently testable with CSV edge fixtures.

### Within Each User Story

- Fixture and test tasks come before implementation tasks.
- Resolver validation and mode selection come before DNS resolution behavior.
- Parsers and wrappers come before row assembly.
- Row assembly comes before report writing validation.
- Story checkpoint must pass before considering that story complete.

### Parallel Opportunities

- Setup tasks T002, T003, T004, and T005 can run in parallel after T001 is clear.
- Foundational helper tasks T008, T009, T010, T011, T012, T013, T014, T015, T016, and T017 can run in parallel after T006 and T007 interfaces are settled.
- US1 fixture and wrapper tasks T018, T019, T020, T021, T022, T023, T025, and T027 can be split across files before final assembly tasks T028-T031.
- US2 fixture tasks T032-T036 can run in parallel with failure handling tasks once the relevant module interfaces exist.
- US3 fixture/test tasks T044-T045 can run in parallel with CSV hardening once lib/csv.sh exists.

---

## Parallel Example: User Story 1

```bash
Task: "T018 [P] [US1] Add nmap XML fixture with multiple open services in tests/fixtures/nmap/basic-services.xml"
Task: "T019 [P] [US1] Add httpx JSONL fixture with status, title, and multiple technologies in tests/fixtures/httpx/basic-web.jsonl"
Task: "T020 [P] [US1] Add DNS fixture data for default and explicit resolver success cases in tests/fixtures/dns/basic-resolution.txt"
Task: "T023 [P] [US1] Implement default DNS resolution helper returning unique domain/IP/address-family records in lib/dns.sh"
Task: "T025 [P] [US1] Implement nmap command wrapper that scans one IP against selected ports and writes XML output in lib/nmap_scan.sh"
Task: "T027 [P] [US1] Implement httpx JSONL prober wrapper and metadata extraction for status, title, technologies, and versions in lib/http_probe.sh"
```

## Parallel Example: User Story 2

```bash
Task: "T032 [P] [US2] Add nmap XML fixture with open non-web service and missing version in tests/fixtures/nmap/partial-services.xml"
Task: "T033 [P] [US2] Add httpx JSONL fixture with timeout or missing metadata cases in tests/fixtures/httpx/partial-web.jsonl"
Task: "T034 [P] [US2] Add DNS fixture data for unresolved domains and resolver failure cases in tests/fixtures/dns/partial-resolution.txt"
Task: "T035 [P] [US2] Add integration test for unresolved domains and partial result preservation in tests/integration/us2_partial_results.bats"
Task: "T036 [P] [US2] Add integration test for invalid, unreachable, and non-responsive DNS resolver diagnostics in tests/integration/us2_resolver_failures.bats"
```

## Parallel Example: User Story 3

```bash
Task: "T044 [P] [US3] Add CSV edge-case fixture expectations for quotes, commas, line breaks, blanks, and duplicate rows in tests/fixtures/expected-review-ready.csv"
Task: "T045 [P] [US3] Add integration test for review-ready CSV escaping, sorting compatibility, and deduplication in tests/integration/us3_review_ready_csv.bats"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 setup tasks.
2. Complete Phase 2 foundational tasks.
3. Complete Phase 3 User Story 1 tasks.
4. Stop and validate the MVP using tests/integration/us1_consolidated_inventory.bats, tests/integration/us1_explicit_dns_resolver.bats, and the CSV header check from quickstart.md.

### Incremental Delivery

1. Build Setup and Foundational phases.
2. Add US1 to generate the consolidated inventory CSV with optional explicit DNS resolver support.
3. Add US2 to preserve useful findings under partial failures, including resolver failures.
4. Add US3 to harden CSV output for reviewer workflows.
5. Finish with ShellCheck, full Bats suite, quickstart validation, and contract review.

### Single-Developer Strategy

Work sequentially by phase and keep each checkpoint green before moving on. US1 is the suggested MVP scope because it proves the complete resolve-scan-probe-report loop and the requested explicit resolver path.

## Notes

- All task paths are relative to the repository root.
- `[P]` tasks are limited to files that can be edited independently.
- User story tasks include `[US1]`, `[US2]`, or `[US3]` for traceability.
- Setup, Foundational, and Polish tasks intentionally omit story labels.
