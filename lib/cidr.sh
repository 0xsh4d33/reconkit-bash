#!/usr/bin/env bash

cidr_ip_to_int() {
  local ip="$1" a b c d
  IFS=. read -r a b c d <<< "$ip"
  printf '%u\n' $(((a << 24) + (b << 16) + (c << 8) + d))
}

cidr_int_to_ip() {
  local value="$1"
  printf '%u.%u.%u.%u\n' \
    $(((value >> 24) & 255)) \
    $(((value >> 16) & 255)) \
    $(((value >> 8) & 255)) \
    $((value & 255))
}

cidr_valid_ipv4() {
  local ip="$1" octet
  local -a octets
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    [[ "$octet" =~ ^[0-9]+$ ]] || return 1
    ((octet >= 0 && octet <= 255)) || return 1
  done
}

cidr_prefix_valid() {
  local prefix="$1"
  [[ "$prefix" =~ ^[0-9]+$ ]] || return 1
  ((prefix >= 16 && prefix <= 32))
}

cidr_candidate_count() {
  local cidr="$1" ip prefix total
  IFS=/ read -r ip prefix <<< "$cidr"
  cidr_valid_ipv4 "$ip" || return 1
  cidr_prefix_valid "$prefix" || return 1
  total=$((1 << (32 - prefix)))
  if ((prefix <= 30)); then
    printf '%u\n' $((total - 2))
  else
    printf '%u\n' "$total"
  fi
}

cidr_validate() {
  local cidr="$1" ip prefix count
  [[ "$cidr" == */* ]] || return 1
  IFS=/ read -r ip prefix <<< "$cidr"
  cidr_valid_ipv4 "$ip" || return 1
  cidr_prefix_valid "$prefix" || return 1
  count="$(cidr_candidate_count "$cidr")" || return 1
  ((count > 0)) || return 1
}

cidr_enumerate() {
  local cidr="$1" ip prefix ip_int mask network broadcast start end current
  cidr_validate "$cidr" || return 1
  IFS=/ read -r ip prefix <<< "$cidr"
  ip_int="$(cidr_ip_to_int "$ip")"
  if ((prefix == 0)); then
    mask=0
  else
    mask=$(((0xffffffff << (32 - prefix)) & 0xffffffff))
  fi
  network=$((ip_int & mask))
  broadcast=$((network | (0xffffffff ^ mask)))
  if ((prefix <= 30)); then
    start=$((network + 1))
    end=$((broadcast - 1))
  else
    start="$network"
    end="$broadcast"
  fi
  for ((current = start; current <= end; current++)); do
    cidr_int_to_ip "$current"
  done
}
