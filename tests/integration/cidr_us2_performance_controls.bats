#!/usr/bin/env bats

load ../test_helper

@test "concurrency timeout and stage progress options are honored" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/small-range.xml" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-basic-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/30 --ports 80 --max-discovery-jobs 7 --max-scan-jobs 5 --max-probe-jobs 3 --host-timeout 2 --probe-timeout 4 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  grep -q 'stage=discovery status=start' "$log"
  grep -q 'max_discovery_jobs=7' "$log"
  grep -q 'responsive_count=1' "$log"
  grep -q 'max_scan_jobs=5' "$log"
  grep -q 'max_probe_jobs=3' "$log"
}
