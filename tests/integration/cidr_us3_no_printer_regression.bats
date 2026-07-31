#!/usr/bin/env bats

load ../test_helper

@test "no-printer run preserves existing CIDR CSV behavior" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/small-range.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/none-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-basic-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/30 --ports 80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  head -n 1 "$output" | grep -qx 'Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version'
  grep -q 'app.example.test,192.0.2.1,80,tcp,http nginx,1.24.0,200,Admin Portal,React,18' "$output"
}

