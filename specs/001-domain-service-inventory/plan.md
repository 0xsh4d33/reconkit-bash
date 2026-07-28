# Implementation Plan: Domain Service Inventory

**Branch**: `001-domain-service-inventory` | **Date**: 2026-07-25 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-domain-service-inventory/spec.md`

## Summary

Build a command-line inventory script that accepts a subdomain list, selected ports, and an optional DNS resolver address. The script resolves each domain through the chosen resolver behavior, scans resolved addresses for open services, probes web endpoints for response and technology metadata, and emits a standards-compatible CSV with the required report columns. The design keeps source layout minimal for a Bash CLI while using structured output from external discovery tools so parsing remains reliable.

## Technical Context

**Language/Version**: Bash 4.4+ with POSIX-friendly shell utilities where practical

**Primary Dependencies**: `nmap` for service discovery, ProjectDiscovery `httpx` for web metadata, `jq` for JSONL parsing, XML parser support via `xmllint` or `xmlstarlet`, DNS resolution through `dig` when a resolver is specified and environment default resolution through `getent`/`dig`/`host` fallback when no resolver is specified

**Storage**: Local files only: input domain list, generated CSV report, temporary working files, and diagnostic log

**Testing**: ShellCheck for static validation; Bats tests for CLI behavior and CSV formatting; fixture-based integration tests with mocked scanner/prober command outputs

**Target Platform**: Linux command-line environments where Bash and scanner dependencies are available

**Project Type**: Single command-line tool

**Performance Goals**: Complete a typical inventory of 100 subdomains across 20 selected ports without manual intervention; preserve partial results when individual targets fail

**Constraints**: Do not scan ports outside the user-provided list; use the user-specified DNS resolver for all subdomain resolution when provided; fall back to environment default name resolution only when no resolver is provided; produce CSV columns in exact required order; do not invent values when service, version, title, or technology metadata is unavailable; support valid CSV escaping for commas, quotes, and line breaks

**Scale/Scope**: First version targets local authorized inventories with hundreds of subdomains and tens of ports, producing one CSV report per run

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file currently contains only placeholder text and defines no enforceable project-specific gates. General quality gates applied for this plan:

- CLI behavior is documented through a contract.
- Validation scenarios cover success, partial failure, and CSV correctness.
- Design favors simple local files and a single command-line entry point.

Initial gate status: PASS.

Post-design gate status: PASS. Phase 1 artifacts define data entities, the CLI contract, and validation guide without adding unjustified complexity.

## Project Structure

### Documentation (this feature)

```text
specs/001-domain-service-inventory/
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
end-scanner.sh

lib/
├── csv.sh
├── dns.sh
├── http_probe.sh
├── logging.sh
├── nmap_parse.sh
└── nmap_scan.sh

tests/
├── fixtures/
│   ├── httpx/
│   └── nmap/
├── integration/
└── unit/
```

**Structure Decision**: Use a single executable script at repository root for the user-facing command, with small Bash libraries under `lib/` for parsing, probing, CSV escaping, and logging. Tests are split into unit tests for pure shell functions and fixture-based integration tests for end-to-end report generation.
