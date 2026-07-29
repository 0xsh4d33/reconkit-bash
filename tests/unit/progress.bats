#!/usr/bin/env bats

load ../test_helper

@test "emits stage progress diagnostics" {
  run bash -c ". '$REPO_ROOT/lib/logging.sh'; . '$REPO_ROOT/lib/progress.sh'; progress_stage_start discovery cidr=192.0.2.0/30"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stage=discovery status=start"* ]]
}
