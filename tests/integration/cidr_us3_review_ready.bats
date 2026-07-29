#!/usr/bin/env bats

load ../test_helper

@test "partial data keeps review-ready escaped and deduplicated CSV" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/small-range.xml" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/cidr-partial-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/cidr-partial-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/30 --ports 22,80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  [ "$(grep -c 'Title, with comma' "$output")" -eq 1 ]
  grep -q 'app.example.test,192.0.2.1,22,tcp,ssh OpenSSH,,,,,' "$output"
  grep -q 'app.example.test,192.0.2.1,80,tcp,http nginx,1.24.0,200,"Title, with comma","Quote ""Tech""",1.0' "$output"
}
