# Research: CIDR Host Inventory

## Decision: Implement as a separate Bash CLI

**Rationale**: The requested workflow starts from CIDR/IP ranges rather than subdomain lists and needs different performance behavior. A separate entrypoint keeps user intent clear while still allowing reuse of shared shell helpers.

**Alternatives considered**: Extending the existing domain scanner with mutually exclusive modes would reduce file count but increase CLI branching and make the fast range-scan path easier to regress.

## Decision: Support IPv4 CIDR in the first version

**Rationale**: The motivating examples are IPv4 ranges, and `/16` performance is central to the feature. IPv6 range expansion has radically different scale characteristics and would need separate product and safety decisions.

**Alternatives considered**: Adding IPv6 immediately would broaden scope and complicate validation. Treating arbitrary IP lists as input is useful but not the stated primary workflow.

## Decision: Use discovery-first scanning

**Rationale**: A `/16` contains 65,536 addresses. Running service detection and web probing against every address would be slow and noisy. Host discovery first limits detailed work to responsive addresses and directly satisfies the requirement for fast large-range scans.

**Alternatives considered**: Full per-IP detailed scans are simpler to reason about but waste time on inactive hosts. Relying only on port scans as discovery may miss hosts but can be allowed as a configurable fallback later.

## Decision: Use `nmap` for both host discovery and service findings

**Rationale**: The requested workflow already requires `nmap` for service scanning. `nmap` can discover responsive hosts and then produce structured service output for selected ports, keeping the dependency set compact.

**Alternatives considered**: Dedicated discovery tools may be faster in some environments, but they add dependencies and operational variability. Raw ping loops are simple but unreliable across networks that block ICMP.

## Decision: Preserve reverse DNS as best-effort metadata

**Rationale**: Domain may not resolve for an IP. The report should still include discovered services with an empty Domain field rather than dropping host findings or inventing names.

**Alternatives considered**: Requiring reverse DNS would lose useful service data. Using IP as a fake domain value would blur two distinct fields and make filtering less accurate.

## Decision: Use configurable concurrency and timeouts

**Rationale**: Large ranges need bounded parallel work and per-stage time limits. Defaults should be conservative enough for internal networks, while explicit controls let operators tune faster or slower environments.

**Alternatives considered**: Fixed concurrency would be simpler but either too slow for large networks or too aggressive for fragile ones. Unbounded parallelism risks overwhelming the network and local host.

## Decision: Emit progress and diagnostics outside the CSV

**Rationale**: Long `/16` scans need visible stage progress, but the CSV must remain clean report data. Discovery, reverse lookup, service scanning, web probing, and report writing should be distinguishable in diagnostics.

**Alternatives considered**: Adding progress rows to the CSV would break spreadsheet workflows. Silent long-running scans would leave users unable to tell whether the process is stalled.

## Decision: Use fixture-based tests for performance behavior

**Rationale**: Real `/16` tests are environment-dependent and too slow for routine validation. Fixtures can prove inactive hosts are skipped, only responsive hosts receive detailed checks, and configured limits are passed to scan/probe stages.

**Alternatives considered**: Only live large-network tests would be unreliable and hard to automate. Only unit tests would miss end-to-end stage ordering.
