#!/usr/bin/env bats

load ../test_helper

@test "invalid resolver exits with argument error" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  log="$BATS_TEST_TMPDIR/inventory.log"
  printf 'app.example.test\n' > "$domains"

  run_scanner --domains "$domains" --ports 80 --dns-server not-an-ip --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 1 ]
  grep -q 'invalid resolver address' "$log"
}

@test "unreachable resolver is diagnosed" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  log="$BATS_TEST_TMPDIR/inventory.log"
  printf 'app.example.test\n' > "$domains"

  END_SCANNER_RESOLVER_STATUS=unreachable \
    run_scanner --domains "$domains" --ports 80 --dns-server 10.10.10.53 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 1 ]
  grep -q 'unreachable DNS resolver' "$log"
}

@test "non-responsive resolver is diagnosed" {
  domains="$BATS_TEST_TMPDIR/domains.txt"
  output="$BATS_TEST_TMPDIR/inventory.csv"
  log="$BATS_TEST_TMPDIR/inventory.log"
  printf 'app.example.test\n' > "$domains"

  END_SCANNER_RESOLVER_STATUS=non_responsive \
    run_scanner --domains "$domains" --ports 80 --dns-server 10.10.10.53 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 1 ]
  grep -q 'non-responsive DNS resolver' "$log"
}
