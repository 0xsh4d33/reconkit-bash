#!/usr/bin/env bash

nmap_scan() {
  local ip="$1"
  local ports="$2"
  local output="$3"
  local timeout_value="${4-}"

  if [[ -n "${END_SCANNER_NMAP_FIXTURE:-}" ]]; then
    cp "$END_SCANNER_NMAP_FIXTURE" "$output"
    return $?
  fi

  local cmd=(nmap -Pn -open -p "$ports" -oX "$output" "$ip")
  if [[ -n "$timeout_value" ]] && command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_value" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}
