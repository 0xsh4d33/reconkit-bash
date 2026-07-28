#!/usr/bin/env bats

load ../test_helper

@test "domain normalization trims comments and duplicates" {
  input="$BATS_TEST_TMPDIR/domains.txt"
  printf ' App.Example.Test \n# comment\n\napp.example.test\nAPI.EXAMPLE.TEST\n' > "$input"
  run bash -c ". '$REPO_ROOT/lib/dns.sh'; normalize_domains '$input'"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "app.example.test" ]
  [ "${lines[1]}" = "api.example.test" ]
  [ "${#lines[@]}" -eq 2 ]
}
