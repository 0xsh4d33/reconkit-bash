#!/usr/bin/env bats

load ../test_helper

@test "printer detection failures are diagnostic warnings distinct from exclusions" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/printer-mixed.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/detection-failure.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/printer-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-printer-exclusion-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-printer-exclusion-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/29 --ports 80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  grep -q 'stage=printer_exclusion detection_failure ip=192.0.2.1 status=failed' "$log"
  grep -q 'stage=printer_exclusion excluded ip=192.0.2.2 reason="open port 9100"' "$log"
  grep -q '192.0.2.3,80,tcp' "$output"
}

