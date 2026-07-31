#!/usr/bin/env bats

load ../test_helper

@test "all responsive printers skip later stages and return no-detailed-scan exit code" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/printer-two-hosts.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/all-9100-open.tsv" \
    run_cidr_scanner --cidr 192.0.2.0/29 --ports 80 --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"

  [ "$status" -eq 3 ]
  grep -q 'stage=printer_exclusion status=complete checked=2 excluded_count=2 eligible_count=0' "$log"
  grep -q 'no eligible hosts remain after printer exclusion' "$log"
  [ ! -e "$output" ]
}

