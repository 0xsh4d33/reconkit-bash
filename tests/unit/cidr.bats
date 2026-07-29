#!/usr/bin/env bats

load ../test_helper

@test "validates IPv4 CIDR syntax and counts usable addresses" {
  run bash -c ". '$REPO_ROOT/lib/cidr.sh'; cidr_validate 192.0.2.0/30 && cidr_candidate_count 192.0.2.0/30"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "rejects malformed CIDR and unsupported broad ranges" {
  run bash -c ". '$REPO_ROOT/lib/cidr.sh'; cidr_validate 192.0.2.0/not-a-prefix"
  [ "$status" -ne 0 ]

  run bash -c ". '$REPO_ROOT/lib/cidr.sh'; cidr_validate 10.0.0.0/8"
  [ "$status" -ne 0 ]
}
