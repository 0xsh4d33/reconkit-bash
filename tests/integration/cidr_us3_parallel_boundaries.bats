#!/usr/bin/env bats

load ../test_helper

@test "parallel service scan skips printer-excluded hosts" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"
  trace="$BATS_TEST_TMPDIR/cidr.trace"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/printer-mixed.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/mixed-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/printer-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/parallel/success" \
  END_SCANNER_NMAP_TRACE_FILE="$trace" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-printer-exclusion-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/29 --ports 80 --max-scan-jobs 4 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  ! grep -q '^192\.0\.2\.1[[:space:]]' "$trace"
  grep -q '^192\.0\.2\.2[[:space:]]80$' "$trace"
  grep -q '^192\.0\.2\.3[[:space:]]80$' "$trace"
}

@test "parallel service scan preserves selected port list" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"
  trace="$BATS_TEST_TMPDIR/cidr.trace"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/printer-mixed.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/mixed-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/printer-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/parallel/success" \
  END_SCANNER_NMAP_TRACE_FILE="$trace" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-printer-exclusion-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/29 --ports 80,9100 --max-scan-jobs 4 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  ! grep -q '^192\.0\.2\.1[[:space:]]' "$trace"
  grep -q '^192\.0\.2\.2[[:space:]]80,9100$' "$trace"
  grep -q '^192\.0\.2\.3[[:space:]]80,9100$' "$trace"
}
