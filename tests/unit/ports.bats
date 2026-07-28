#!/usr/bin/env bats

load ../test_helper

@test "port parser accepts comma-separated ports and deduplicates" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/out.csv"
  printf 'app.example.test\n' > "$domains"
  END_SCANNER_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/dns/basic-resolution.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/basic-web.jsonl" \
    run_scanner --domains "$domains" --ports 80,80,443 --output "$output" --tmp-dir "$BATS_TEST_TMPDIR"
  [ "$status" -eq 0 ]
}

@test "invalid port is rejected by CLI" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  printf 'app.example.test\n' > "$domains"
  run_scanner --domains "$domains" --ports 0 --output "$BATS_TEST_TMPDIR/out.csv"
  [ "$status" -eq 1 ]
}
