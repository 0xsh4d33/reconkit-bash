#!/usr/bin/env bats

load ../test_helper

@test "detects unique printer IPs from fixture statuses" {
  responsive="$BATS_TEST_TMPDIR/responsive.txt"
  excluded="$BATS_TEST_TMPDIR/excluded.txt"
  printf '192.0.2.1\n192.0.2.2\n192.0.2.1\n192.0.2.3\n' > "$responsive"

  run bash -c ". '$REPO_ROOT/lib/logging.sh'; . '$REPO_ROOT/lib/printer_exclusion.sh'; CIDR_SCANNER_PRINTER_FIXTURE='$REPO_ROOT/tests/fixtures/printer/mixed-9100-open.tsv' printer_exclusion_detect '$responsive' '$excluded' 1; cat '$excluded'"

  [ "$status" -eq 0 ]
  [ "$output" = "192.0.2.1" ]
}

@test "filters eligible IPs by subtracting excluded printers" {
  responsive="$BATS_TEST_TMPDIR/responsive.txt"
  excluded="$BATS_TEST_TMPDIR/excluded.txt"
  eligible="$BATS_TEST_TMPDIR/eligible.txt"
  printf '192.0.2.1\n192.0.2.2\n192.0.2.3\n' > "$responsive"
  printf '192.0.2.1\n192.0.2.2\n' > "$excluded"

  run bash -c ". '$REPO_ROOT/lib/printer_exclusion.sh'; printer_exclusion_filter_eligible '$responsive' '$excluded' '$eligible'; cat '$eligible'"

  [ "$status" -eq 0 ]
  [ "$output" = "192.0.2.3" ]
}

@test "logs fixture-driven detection failures separately from exclusions" {
  responsive="$BATS_TEST_TMPDIR/responsive.txt"
  excluded="$BATS_TEST_TMPDIR/excluded.txt"
  log="$BATS_TEST_TMPDIR/printer.log"
  printf '192.0.2.1\n192.0.2.2\n192.0.2.3\n' > "$responsive"

  run bash -c ". '$REPO_ROOT/lib/logging.sh'; . '$REPO_ROOT/lib/printer_exclusion.sh'; log_init '$log'; CIDR_SCANNER_PRINTER_FIXTURE='$REPO_ROOT/tests/fixtures/printer/detection-failure.tsv' printer_exclusion_detect '$responsive' '$excluded' 1; cat '$excluded'"

  [ "$status" -eq 0 ]
  [ "$output" = "192.0.2.2" ]
  grep -q 'stage=printer_exclusion detection_failure ip=192.0.2.1 status=failed' "$log"
}
