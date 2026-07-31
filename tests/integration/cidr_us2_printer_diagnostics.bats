#!/usr/bin/env bats

load ../test_helper

@test "diagnostics list excluded printer IPs with counts" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/printer-mixed.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/mixed-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/printer-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-printer-exclusion-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-printer-exclusion-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/29 --ports 80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  grep -q 'stage=printer_exclusion status=start checked=3' "$log"
  grep -q 'stage=printer_exclusion status=complete checked=3 excluded_count=1 eligible_count=2' "$log"
}
