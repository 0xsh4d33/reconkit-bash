#!/usr/bin/env bats

load ../test_helper

@test "enumerates usable addresses for /30" {
  run bash -c ". '$REPO_ROOT/lib/cidr.sh'; cidr_enumerate 192.0.2.0/30"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "192.0.2.1" ]
  [ "${lines[1]}" = "192.0.2.2" ]
}

@test "enumerates both addresses for /31" {
  run bash -c ". '$REPO_ROOT/lib/cidr.sh'; cidr_enumerate 192.0.2.4/31"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "192.0.2.4" ]
  [ "${lines[1]}" = "192.0.2.5" ]
}
