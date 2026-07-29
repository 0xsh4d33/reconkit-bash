# Tasks: CIDR Host Inventory

**Input**: Design documents from `/specs/002-cidr-host-inventory/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/cli.md](./contracts/cli.md), [quickstart.md](./quickstart.md)

**Tests**: Included because the implementation plan defines ShellCheck, Bats, fixture-based integration tests, and quickstart validation.

**Organization**: Tasks are grouped by user story so each story can be implemented and tested independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and does not depend on incomplete tasks.
- **[Story]**: Maps task to a user story from [spec.md](./spec.md).
- Every task includes an exact file path.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the separate CIDR scanner entrypoint, helper modules, and test fixtures.

- [X] T001 Create executable CIDR scanner CLI entrypoint with usage stub in cidr-scanner.sh
- [X] T002 [P] Create CIDR-specific shell helper placeholders in lib/cidr.sh, lib/host_discovery.sh, lib/progress.sh, and lib/reverse_dns.sh
- [X] T003 [P] Create CIDR fixture directories in tests/fixtures/cidr and tests/fixtures/discovery
- [X] T004 [P] Add CIDR scanner generated report, log, and temporary output ignore rules in .gitignore
- [X] T005 [P] Add CIDR scanner command helper functions in tests/test_helper.bash

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement reusable CLI validation, CIDR parsing, performance controls, dependency checks, and shared report primitives required by all user stories.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Implement command-line argument parsing for --cidr, --ports, --output, --log, --tmp-dir, --max-discovery-jobs, --max-scan-jobs, --max-probe-jobs, --host-timeout, --probe-timeout, and --help in cidr-scanner.sh
- [X] T007 Implement dependency checks for bash version, nmap, httpx, jq, dig/host, and xmllint/xmlstarlet in cidr-scanner.sh
- [X] T008 [P] Implement IPv4 CIDR syntax validation, prefix validation, and candidate count calculation in lib/cidr.sh
- [X] T009 [P] Implement IPv4 candidate address enumeration for supported CIDR ranges in lib/cidr.sh
- [X] T010 [P] Implement performance control validation for concurrency and timeout values in cidr-scanner.sh
- [X] T011 [P] Implement CIDR stage progress helpers for input, discovery, reverse_dns, service_scan, web_probe, and report stages in lib/progress.sh
- [X] T012 [P] Verify shared CSV header and escaping helpers support empty Domain fields in lib/csv.sh
- [X] T013 [P] Verify shared logging helpers support CIDR stage diagnostics in lib/logging.sh
- [X] T014 [P] Add unit tests for CIDR validation and candidate counts in tests/unit/cidr.bats
- [X] T015 [P] Add unit tests for CIDR address enumeration edge cases in tests/unit/cidr_enumeration.bats
- [X] T016 [P] Add unit tests for performance control validation in tests/unit/cidr_performance.bats
- [X] T017 [P] Add unit tests for CIDR progress diagnostics in tests/unit/progress.bats

**Checkpoint**: Foundation ready. CLI validation, CIDR expansion, performance controls, progress diagnostics, and shared CSV/logging behavior are testable before story work starts.

---

## Phase 3: User Story 1 - Generate CIDR Host Inventory (Priority: P1) MVP

**Goal**: A user provides a valid CIDR range and selected ports, then receives the required CSV for responsive hosts, open services, reverse names when available, and web metadata.

**Independent Test**: Run the CLI with fixture-backed discovery, reverse DNS, scanner, and web prober outputs for a small controlled CIDR, then verify expected CSV rows including empty Domain fields.

### Tests for User Story 1

- [X] T018 [P] [US1] Add CIDR fixture with reachable and unreachable candidate addresses in tests/fixtures/cidr/small-range.txt
- [X] T019 [P] [US1] Add nmap host discovery fixture with responsive hosts in tests/fixtures/discovery/small-range.xml
- [X] T020 [P] [US1] Add reverse DNS fixture with resolved and unresolved IPs in tests/fixtures/cidr/reverse-dns.txt
- [X] T021 [P] [US1] Add nmap service XML fixture for responsive CIDR hosts in tests/fixtures/nmap/cidr-basic-services.xml
- [X] T022 [P] [US1] Add httpx JSONL fixture for responsive CIDR web endpoints in tests/fixtures/httpx/cidr-basic-web.jsonl
- [X] T023 [P] [US1] Add integration test for successful CIDR inventory generation in tests/integration/cidr_us1_inventory.bats

### Implementation for User Story 1

- [X] T024 [P] [US1] Implement nmap host discovery wrapper that writes structured responsive-host output in lib/host_discovery.sh
- [X] T025 [US1] Implement host discovery output parser that marks Candidate Addresses responsive or inactive in lib/host_discovery.sh
- [X] T026 [P] [US1] Implement best-effort reverse DNS lookup helper for responsive IPs in lib/reverse_dns.sh
- [X] T027 [US1] Reuse or adapt service scan wrapper for responsive IP-only targets in lib/nmap_scan.sh
- [X] T028 [US1] Reuse or adapt nmap XML parser for CIDR service findings in lib/nmap_parse.sh
- [X] T029 [US1] Reuse or adapt httpx probing for IP-based web endpoints in lib/http_probe.sh
- [X] T030 [US1] Implement CIDR inventory row assembly with empty Domain support in cidr-scanner.sh
- [X] T031 [US1] Implement CSV report writing with required column order in cidr-scanner.sh
- [X] T032 [US1] Wire the full CIDR happy-path flow from input validation to report writing in cidr-scanner.sh
- [ ] T033 [US1] Run and satisfy the US1 integration test in tests/integration/cidr_us1_inventory.bats

**Checkpoint**: User Story 1 is fully functional and independently testable as the MVP.

---

## Phase 4: User Story 2 - Complete Large Range Scans Efficiently (Priority: P2)

**Goal**: A `/16` scan avoids detailed work for inactive hosts, exposes progress, and supports bounded concurrency and timeout controls.

**Independent Test**: Run with large-range fixtures containing many inactive hosts and a controlled responder set, then verify only responsive hosts reach service/web stages and performance controls are honored.

### Tests for User Story 2

- [X] T034 [P] [US2] Add large-range CIDR fixture with candidate and responsive host counts in tests/fixtures/cidr/large-range.txt
- [X] T035 [P] [US2] Add discovery fixture with many inactive hosts skipped in tests/fixtures/discovery/large-range.xml
- [X] T036 [P] [US2] Add integration test proving inactive hosts are not service scanned or web probed in tests/integration/cidr_us2_skip_inactive.bats
- [X] T037 [P] [US2] Add integration test for concurrency, timeout, and stage progress options in tests/integration/cidr_us2_performance_controls.bats

### Implementation for User Story 2

- [X] T038 [US2] Add discovery-first orchestration that blocks reverse DNS, service scan, and web probe stages until responsive hosts are known in cidr-scanner.sh
- [X] T039 [US2] Add enforcement that inactive hosts are excluded from service scan inputs in cidr-scanner.sh
- [X] T040 [US2] Add enforcement that inactive hosts are excluded from web probe inputs in cidr-scanner.sh
- [X] T041 [US2] Pass validated concurrency and timeout controls into discovery, service scan, and web probe helpers in cidr-scanner.sh
- [X] T042 [US2] Emit stage start, stage completion, candidate count, and responsive host count diagnostics in lib/progress.sh
- [X] T043 [US2] Handle no-responsive-host condition with contract exit code and diagnostics in cidr-scanner.sh
- [ ] T044 [US2] Run and satisfy US2 integration tests in tests/integration/cidr_us2_skip_inactive.bats and tests/integration/cidr_us2_performance_controls.bats

**Checkpoint**: User Story 2 is independently testable and proves the `/16` usability path.

---

## Phase 5: User Story 3 - Preserve Review-Ready Output Under Partial Data (Priority: P3)

**Goal**: Mixed CIDR scans produce spreadsheet-ready CSV even when reverse names, service versions, web metadata, or individual probes are missing.

**Independent Test**: Run with fixtures containing unresolved names, non-web services, missing versions, duplicate rows, and CSV special characters, then validate report shape and diagnostics.

### Tests for User Story 3

- [X] T045 [P] [US3] Add reverse DNS failure and timeout fixture in tests/fixtures/cidr/reverse-dns-partial.txt
- [X] T046 [P] [US3] Add nmap XML fixture with non-web service and missing version in tests/fixtures/nmap/cidr-partial-services.xml
- [X] T047 [P] [US3] Add httpx JSONL fixture with missing technologies and timeout cases in tests/fixtures/httpx/cidr-partial-web.jsonl
- [X] T048 [P] [US3] Add expected CSV fixture for empty Domain, escaped fields, and deduplication in tests/fixtures/cidr/expected-review-ready.csv
- [X] T049 [P] [US3] Add integration test for partial data and review-ready CSV output in tests/integration/cidr_us3_review_ready.bats

### Implementation for User Story 3

- [X] T050 [US3] Add reverse DNS failure, timeout, and multiple-name handling with best-effort Domain selection in lib/reverse_dns.sh
- [X] T051 [US3] Add non-web service row output with empty HTTP Status, HTTP Title, HTTP Tech, and Tech Version fields in cidr-scanner.sh
- [X] T052 [US3] Preserve service rows when web probing fails or returns no technologies in cidr-scanner.sh
- [X] T053 [US3] Implement exact-row deduplication before CIDR report write in cidr-scanner.sh
- [X] T054 [US3] Validate CSV escaping and required header order for CIDR reports in cidr-scanner.sh
- [X] T055 [US3] Add interruption handling that logs cancellation and exits with contract exit code 130 in cidr-scanner.sh
- [ ] T056 [US3] Run and satisfy the US3 integration test in tests/integration/cidr_us3_review_ready.bats

**Checkpoint**: All user stories are independently functional and the CIDR CSV is ready for spreadsheet or analysis tooling.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, documentation alignment, and maintainability work across all CIDR scanner stories.

- [X] T057 [P] Add ShellCheck-friendly comments or suppressions only where justified in cidr-scanner.sh, lib/cidr.sh, lib/host_discovery.sh, lib/progress.sh, and lib/reverse_dns.sh
- [X] T058 [P] Update README with CIDR scanner usage, prerequisites, performance controls, output columns, exit codes, and authorization note in README.md
- [X] T059 Add CIDR quickstart examples and separate-script distinction to README.md
- [ ] T060 Run ShellCheck across cidr-scanner.sh, lib/cidr.sh, lib/host_discovery.sh, lib/progress.sh, and lib/reverse_dns.sh
- [ ] T061 Run all CIDR Bats tests in tests/unit/cidr.bats, tests/unit/cidr_enumeration.bats, tests/unit/cidr_performance.bats, tests/unit/progress.bats, tests/integration/cidr_us1_inventory.bats, tests/integration/cidr_us2_skip_inactive.bats, tests/integration/cidr_us2_performance_controls.bats, and tests/integration/cidr_us3_review_ready.bats
- [X] T062 Run quickstart validation from specs/002-cidr-host-inventory/quickstart.md
- [X] T063 Review implementation against CLI contract in specs/002-cidr-host-inventory/contracts/cli.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1; blocks all user story work.
- **User Story 1 (Phase 3)**: Depends on Phase 2; delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on Phase 2 and validates large-range efficiency; can be implemented after or alongside US1 orchestration.
- **User Story 3 (Phase 5)**: Depends on Phase 2 and benefits from US1 row assembly; remains independently testable with partial-data fixtures.
- **Polish (Phase 6)**: Depends on the desired user stories being complete.

### User Story Dependencies

- **US1 Generate CIDR Host Inventory**: Start after Foundational. No dependency on other stories.
- **US2 Complete Large Range Scans Efficiently**: Start after Foundational. Depends conceptually on discovery-stage interfaces and can be validated independently with large fixtures.
- **US3 Preserve Review-Ready Output Under Partial Data**: Start after Foundational. Uses shared report writer behavior and CIDR partial-data fixtures.

### Within Each User Story

- Fixture and test tasks come before implementation tasks.
- CIDR validation and performance controls come before scan orchestration.
- Host discovery comes before reverse DNS, service scanning, and web probing.
- Row assembly comes before report writing validation.
- Story checkpoint must pass before considering that story complete.

### Parallel Opportunities

- Setup tasks T002, T003, T004, and T005 can run in parallel after T001 is clear.
- Foundational helper tasks T008, T009, T010, T011, T012, T013, T014, T015, T016, and T017 can run in parallel after T006 and T007 interfaces are settled.
- US1 fixture tasks T018-T023 can run in parallel with helper implementation tasks T024, T026, T027, T028, and T029.
- US2 fixture and test tasks T034-T037 can run in parallel before final orchestration tasks T038-T044.
- US3 fixture and test tasks T045-T049 can run in parallel before final partial-data tasks T050-T056.

---

## Parallel Example: User Story 1

```bash
Task: "T018 [P] [US1] Add CIDR fixture with reachable and unreachable candidate addresses in tests/fixtures/cidr/small-range.txt"
Task: "T019 [P] [US1] Add nmap host discovery fixture with responsive hosts in tests/fixtures/discovery/small-range.xml"
Task: "T020 [P] [US1] Add reverse DNS fixture with resolved and unresolved IPs in tests/fixtures/cidr/reverse-dns.txt"
Task: "T024 [P] [US1] Implement nmap host discovery wrapper that writes structured responsive-host output in lib/host_discovery.sh"
Task: "T026 [P] [US1] Implement best-effort reverse DNS lookup helper for responsive IPs in lib/reverse_dns.sh"
```

## Parallel Example: User Story 2

```bash
Task: "T034 [P] [US2] Add large-range CIDR fixture with candidate and responsive host counts in tests/fixtures/cidr/large-range.txt"
Task: "T035 [P] [US2] Add discovery fixture with many inactive hosts skipped in tests/fixtures/discovery/large-range.xml"
Task: "T036 [P] [US2] Add integration test proving inactive hosts are not service scanned or web probed in tests/integration/cidr_us2_skip_inactive.bats"
Task: "T037 [P] [US2] Add integration test for concurrency, timeout, and stage progress options in tests/integration/cidr_us2_performance_controls.bats"
```

## Parallel Example: User Story 3

```bash
Task: "T045 [P] [US3] Add reverse DNS failure and timeout fixture in tests/fixtures/cidr/reverse-dns-partial.txt"
Task: "T046 [P] [US3] Add nmap XML fixture with non-web service and missing version in tests/fixtures/nmap/cidr-partial-services.xml"
Task: "T047 [P] [US3] Add httpx JSONL fixture with missing technologies and timeout cases in tests/fixtures/httpx/cidr-partial-web.jsonl"
Task: "T049 [P] [US3] Add integration test for partial data and review-ready CSV output in tests/integration/cidr_us3_review_ready.bats"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 setup tasks.
2. Complete Phase 2 foundational tasks.
3. Complete Phase 3 User Story 1 tasks.
4. Stop and validate the MVP using tests/integration/cidr_us1_inventory.bats and the CSV header check from quickstart.md.

### Incremental Delivery

1. Build Setup and Foundational phases.
2. Add US1 to generate CIDR inventory CSV for responsive hosts.
3. Add US2 to prove `/16`-scale discovery-first performance behavior.
4. Add US3 to harden output under partial data and CSV edge cases.
5. Finish with ShellCheck, full CIDR Bats suite, quickstart validation, and contract review.

### Single-Developer Strategy

Work sequentially by phase and keep each checkpoint green before moving on. US1 is the suggested MVP scope because it proves the complete CIDR, discover, reverse-resolve, scan, probe, and report loop.

## Notes

- All task paths are relative to the repository root.
- `[P]` tasks are limited to files that can be edited independently.
- User story tasks include `[US1]`, `[US2]`, or `[US3]` for traceability.
- Setup, Foundational, and Polish tasks intentionally omit story labels.
