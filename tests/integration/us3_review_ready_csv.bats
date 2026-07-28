#!/usr/bin/env bats

load ../test_helper

@test "csv report is escaped and deduplicated" {
  run bash -c ". '$REPO_ROOT/lib/csv.sh'; { csv_header; csv_row app.example.test 192.0.2.10 80 tcp nginx 1.24.0 200 'Title, with comma' 'Quote \"Tech\"' 1.0; }"
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = 'app.example.test,192.0.2.10,80,tcp,nginx,1.24.0,200,"Title, with comma","Quote ""Tech""",1.0' ]
}
