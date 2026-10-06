#!/usr/bin/env bats

load ../test_helper

@test "parallel service scan keeps successful rows when one scan and one parser fail" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"
  trace="$BATS_TEST_TMPDIR/cidr.trace"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/parallel-many-hosts.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/none-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/parallel-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/parallel/partial" \
  END_SCANNER_NMAP_TRACE_FILE="$trace" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/parallel-basic-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/27 --ports 80 --max-scan-jobs 8 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [ "$(wc -l < "$trace" | tr -d ' ')" -eq 16 ]
  [ "$(tail -n +2 "$output" | wc -l | tr -d ' ')" -eq 14 ]
  grep -q 'stage=service_scan scan failure ip=192.0.2.11' "$log"
  grep -q 'stage=service_scan parser failure ip=192.0.2.12' "$log"
  grep -q 'stage=service_scan status=complete service_rows=14' "$log"
}
