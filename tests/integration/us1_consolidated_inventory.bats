#!/usr/bin/env bats

load ../test_helper

@test "successful consolidated inventory generation" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  log="$BATS_TEST_TMPDIR/inventory.log"
  printf 'app.example.test\napp.example.test\n# ignored\n' > "$domains"

  END_SCANNER_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/dns/basic-resolution.txt" \
  END_SCANNER_NMAP_FIXTURE="$REPO_ROOT/tests/fixtures/nmap/basic-services.xml" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/basic-web.jsonl" \
    run_scanner --domains "$domains" --ports 80,443 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 0 ]
  head -n 1 "$output" | grep -qx 'Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version'
  grep -q 'app.example.test,192.0.2.10,80,tcp,http nginx,1.24.0,200,Admin Portal,React,18' "$output"
}
