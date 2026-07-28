#!/usr/bin/env bats

load ../test_helper

@test "unresolved domains preserve valid results and diagnostics" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  log="$BATS_TEST_TMPDIR/inventory.log"
  printf 'app.example.test\nmissing.example.test\n' > "$domains"

  END_SCANNER_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/dns/partial-resolution.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/partial-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/partial-web.jsonl" \
    run_scanner --domains "$domains" --ports 22,8080 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  grep -q 'missing.example.test' "$log"
  grep -q 'app.example.test,192.0.2.10,22,tcp,ssh OpenSSH,' "$output"
}
