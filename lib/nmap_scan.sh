#!/usr/bin/env bash

nmap_scan() {
  local ip="$1"
  local ports="$2"
  local output="$3"
  local timeout_value="${4-}"
  local safe_ip fixture_file nmap_host_timeout outer_timeout

  if [[ -n "${END_SCANNER_NMAP_DELAY_SECONDS:-}" ]]; then
    sleep "$END_SCANNER_NMAP_DELAY_SECONDS"
  fi

  if [[ -n "${END_SCANNER_NMAP_TRACE_FILE:-}" ]]; then
    printf '%s\t%s\n' "$ip" "$ports" >> "$END_SCANNER_NMAP_TRACE_FILE"
  fi

  if [[ -n "${END_SCANNER_NMAP_FIXTURE_DIR:-}" ]]; then
    safe_ip="${ip//[^A-Za-z0-9_.-]/_}"
    if [[ -e "$END_SCANNER_NMAP_FIXTURE_DIR/$safe_ip.fail" ]]; then
      return 1
    fi
    fixture_file="$END_SCANNER_NMAP_FIXTURE_DIR/$safe_ip.xml"
    [[ -r "$fixture_file" ]] || fixture_file="$END_SCANNER_NMAP_FIXTURE_DIR/default.xml"
    [[ -r "$fixture_file" ]] || return 1
    cp "$fixture_file" "$output"
    return $?
  fi

  if [[ -n "${END_SCANNER_NMAP_FIXTURE:-}" ]]; then
    cp "$END_SCANNER_NMAP_FIXTURE" "$output"
    return $?
  fi

  nmap_host_timeout="${timeout_value:-3}"
  outer_timeout="$((nmap_host_timeout + 10))"

  local cmd=(nmap -Pn -sV --version-light --max-retries 1 --host-timeout "${nmap_host_timeout}s" -T4 --open -p "$ports" -oX "$output" "$ip")
  if [[ -n "$timeout_value" ]] && command -v timeout >/dev/null 2>&1; then
    timeout "$outer_timeout" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}
