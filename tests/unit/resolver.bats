#!/usr/bin/env bats

load ../test_helper

@test "resolver validation accepts ipv4 and ipv6" {
  run bash -c ". '$REPO_ROOT/lib/dns.sh'; validate_resolver_or_exit 10.10.10.53; validate_resolver_or_exit 2001:db8::53"
  [ "$status" -eq 0 ]
}

@test "resolver validation rejects invalid value" {
  run bash -c ". '$REPO_ROOT/lib/dns.sh'; validate_resolver_or_exit not-an-ip"
  [ "$status" -ne 0 ]
}
