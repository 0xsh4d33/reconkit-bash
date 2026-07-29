#!/usr/bin/env bash

host_discovery_run() {
  local cidr="$1" output="$2" jobs="${3:-64}" timeout_value="${4:-3}"

  if [[ -n "${CIDR_SCANNER_DISCOVERY_FIXTURE:-}" ]]; then
    cp "$CIDR_SCANNER_DISCOVERY_FIXTURE" "$output"
    return $?
  fi

  local cmd=(nmap -sn --max-retries 1 --host-timeout "${timeout_value}s" -oX "$output" "$cidr")
  if command -v timeout >/dev/null 2>&1; then
    timeout "$((timeout_value * 2 + 30))" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
  log_info "stage=discovery max_discovery_jobs=$jobs"
}

host_discovery_parse_responsive() {
  local xml_file="$1"
  [[ -s "$xml_file" ]] || return 1
  awk '
    /<host[ >]/ { in_host=1; up=0; ip="" }
    in_host && /<status/ && /state="up"/ { up=1 }
    in_host && /<address/ && /addrtype="ipv4"/ {
      if (match($0, /addr="[^"]+"/)) {
        ip=substr($0, RSTART + 6, RLENGTH - 7)
      }
    }
    /<\/host>/ {
      if (in_host && up && ip != "") print ip
      in_host=0
    }
  ' "$xml_file" | sort -u
}

host_discovery_mark_candidates() {
  local candidates_file="$1" responsive_file="$2"
  awk 'NR==FNR { up[$1]=1; next } { print $1 "\t" (($1 in up) ? "responsive" : "inactive") }' \
    "$responsive_file" "$candidates_file"
}
