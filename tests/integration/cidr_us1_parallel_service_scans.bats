#!/usr/bin/env bats

load ../test_helper

run_parallel_fixture_scan() {
  local output="$1"
  local log="$2"
  local trace="$3"
  local jobs="$4"

  CIDR_SCANNER_DISCOVERY_FIXTURE="$REPO_ROOT/tests/fixtures/discovery/parallel-many-hosts.xml" \
  CIDR_SCANNER_PRINTER_FIXTURE="$REPO_ROOT/tests/fixtures/printer/none-9100-open.tsv" \
  CIDR_SCANNER_REVERSE_DNS_FIXTURE="$REPO_ROOT/tests/fixtures/cidr/parallel-reverse-dns.txt" \
  END_SCANNER_NMAP_FIXTURE_DIR="$REPO_ROOT/tests/fixtures/parallel/success" \
  END_SCANNER_NMAP_DELAY_SECONDS=0.1 \
  END_SCANNER_NMAP_TRACE_FILE="$trace" \
  END_SCANNER_HTTPX_FIXTURE="$REPO_ROOT/tests/fixtures/httpx/parallel-basic-web.jsonl" \
    run_cidr_scanner --cidr 192.0.2.0/27 --ports 80 --max-scan-jobs "$jobs" --output "$output" --log "$log" --tmp-dir "$BATS_TEST_TMPDIR"
}

@test "max scan jobs runs eligible service scans faster than sequential mode" {
  sequential_output="$BATS_TEST_TMPDIR/sequential.csv"
  sequential_log="$BATS_TEST_TMPDIR/sequential.log"
  sequential_trace="$BATS_TEST_TMPDIR/sequential.trace"
  parallel_output="$BATS_TEST_TMPDIR/parallel.csv"
  parallel_log="$BATS_TEST_TMPDIR/parallel.log"
  parallel_trace="$BATS_TEST_TMPDIR/parallel.trace"

  start_ms="$(date +%s%3N)"
  run_parallel_fixture_scan "$sequential_output" "$sequential_log" "$sequential_trace" 1
  sequential_status="$status"
  sequential_ms=$(("$(date +%s%3N)" - start_ms))

  start_ms="$(date +%s%3N)"
  run_parallel_fixture_scan "$parallel_output" "$parallel_log" "$parallel_trace" 8
  parallel_status="$status"
  parallel_ms=$(("$(date +%s%3N)" - start_ms))

  [ "$sequential_status" -eq 0 ]
  [ "$parallel_status" -eq 0 ]
  [ "$(wc -l < "$sequential_trace" | tr -d ' ')" -eq 16 ]
  [ "$(wc -l < "$parallel_trace" | tr -d ' ')" -eq 16 ]
  [ "$((parallel_ms * 2))" -lt "$sequential_ms" ]

  tail -n +2 "$sequential_output" | sort > "$BATS_TEST_TMPDIR/sequential.rows"
  tail -n +2 "$parallel_output" | sort > "$BATS_TEST_TMPDIR/parallel.rows"
  cmp "$BATS_TEST_TMPDIR/sequential.rows" "$BATS_TEST_TMPDIR/parallel.rows"
}

@test "max scan jobs one preserves sequential-compatible output" {
  output="$BATS_TEST_TMPDIR/cidr.csv"
  log="$BATS_TEST_TMPDIR/cidr.log"
  trace="$BATS_TEST_TMPDIR/cidr.trace"

  run_parallel_fixture_scan "$output" "$log" "$trace" 1

  [ "$status" -eq 0 ]
  grep -q 'stage=service_scan status=start' "$log"
  grep -q 'max_scan_jobs=1' "$log"
  [ "$(wc -l < "$trace" | tr -d ' ')" -eq 16 ]
  [ "$(tail -n +2 "$output" | wc -l | tr -d ' ')" -eq 16 ]
}
