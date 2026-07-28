#!/usr/bin/env bats

load ../test_helper

@test "explicit dns resolver uses explicit fixture records" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  printf 'app.example.test\n' > "$domains"

  END_SCANNER_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/dns/basic-resolution.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/basic-web.jsonl" \
    run_scanner --domains "$domains" --ports 80 --dns-server 10.10.10.53 --output "$output" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  grep -q 'app.example.test,198.51.100.10,80,tcp,http nginx,1.24.0' "$output"
}
