#!/usr/bin/env bats

load ../test_helper

@test "csv header uses required order" {
  run bash -c ". '$REPO_ROOT/lib/csv.sh'; csv_header"
  [ "$status" -eq 0 ]
  [ "$output" = "Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version" ]
}

@test "csv escaping quotes commas and quotes" {
  run bash -c ". '$REPO_ROOT/lib/csv.sh'; csv_row 'a,b' 'quote \" value' ''"
  [ "$status" -eq 0 ]
  [ "$output" = '"a,b","quote "" value",' ]
}
