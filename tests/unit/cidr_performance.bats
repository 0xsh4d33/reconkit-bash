#!/usr/bin/env bats

load ../test_helper

@test "rejects invalid performance controls" {
  run bash -c ". '$REPO_ROOT/cidr-scanner.sh'; MAX_DISCOVERY_JOBS=0; validate_performance_controls"
  [ "$status" -eq 1 ]
}

@test "accepts positive performance controls" {
  run bash -c ". '$REPO_ROOT/cidr-scanner.sh'; validate_performance_controls"
  [ "$status" -eq 0 ]
}
