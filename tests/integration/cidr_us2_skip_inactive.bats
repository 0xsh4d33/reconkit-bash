#!/usr/bin/env bats

load ../test_helper

@test "inactive hosts are not service scanned or web probed" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/small-range.xml" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-basic-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/30 --ports 80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [ "$(grep -c '^app.example.test,192.0.2.1' "$output")" -eq 1 ]
  ! grep -q '192.0.2.2' "$output"
}
