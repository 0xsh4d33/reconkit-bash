# Implementation Plan: CIDR Host Inventory

**Branch**: `002-cidr-host-inventory` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-cidr-host-inventory/spec.md`

## Summary

Build a separate command-line inventory script that accepts an IPv4 CIDR range, selected ports, and performance controls. The script discovers responsive hosts before detailed work, attempts reverse name resolution for responsive IPs, scans selected ports for open services, probes web endpoints for HTTP metadata, and writes the same review-ready CSV shape used by the domain inventory workflow. The implementation reuses CSV, logging, scanner parsing, scanner wrapper, and web probing helpers where compatible, while adding CIDR expansion, host discovery, reverse lookup, progress reporting, and performance controls.

## Technical Context

**Language/Version**: Bash 4.4+ with POSIX-friendly shell utilities where practical

**Primary Dependencies**: `nmap` for host discovery and service discovery, ProjectDiscovery `httpx` for web metadata, `jq` for JSONL parsing, XML parser support via `xmllint` or `xmlstarlet`, reverse DNS through `dig`/`host` fallback

**Storage**: Local files only: generated CSV report, temporary working files for discovery/service/probe outputs, and diagnostic log

**Testing**: ShellCheck for static validation; Bats tests for CLI behavior, CIDR validation, CSV formatting, and fixture-based integration tests with mocked discovery/scanner/prober outputs

**Target Platform**: Linux command-line environments where Bash and scanner dependencies are available

**Project Type**: Separate command-line tool in the same repository

**Performance Goals**: Complete a `/16` scan with no more than 1,000 responsive hosts within 60 minutes under normal local network conditions and default performance settings; skip detailed checks for inactive addresses

**Constraints**: First version supports IPv4 CIDR input; do not scan ports outside the user-provided list; do not run detailed service or web checks for hosts not found responsive during discovery; preserve empty Domain values when reverse lookup fails; produce CSV columns in exact required order; support valid CSV escaping for commas, quotes, and line breaks

**Scale/Scope**: Authorized local/internal IPv4 ranges up to `/16`, selected port lists, one CSV report per run

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file currently contains only placeholder text and defines no enforceable project-specific gates. General quality gates applied for this plan:

- Separate CLI behavior is documented through a contract.
- Validation scenarios cover happy path, `/16` performance behavior, partial data, and CSV correctness.
- Design favors shared shell helpers and a separate entrypoint instead of duplicating the existing domain workflow wholesale.

Initial gate status: PASS.

Post-design gate status: PASS. Phase 1 artifacts define data entities, the CLI contract, and validation guide without adding unjustified complexity.

## Project Structure

### Documentation (this feature)

```text
specs/002-cidr-host-inventory/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── cli.md
└── tasks.md
```

### Source Code (repository root)

```text
cidr-scanner.sh

lib/
├── cidr.sh
├── csv.sh
├── host_discovery.sh
├── http_probe.sh
├── logging.sh
├── nmap_parse.sh
├── nmap_scan.sh
├── progress.sh
└── reverse_dns.sh

tests/
├── fixtures/
│   ├── cidr/
│   ├── discovery/
│   ├── httpx/
│   └── nmap/
├── integration/
└── unit/
```

**Structure Decision**: Use `cidr-scanner.sh` as a separate user-facing command. Add CIDR, host discovery, reverse DNS, and progress helpers under `lib/`, while reusing existing CSV, logging, scanner, parser, and HTTP probing helpers where their interfaces fit both scanner workflows. Tests remain under the existing `tests/` tree with CIDR-specific fixtures and Bats files.
