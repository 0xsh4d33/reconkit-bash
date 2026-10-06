#!/usr/bin/env bash

host_discovery_run() {
  local cidr="$1" output="$2" jobs="${3:-64}" timeout_value="${4:-3}"

  if [[ -n "${CIDR_SCANNER_DISCOVERY_FIXTURE:-}" ]]; then
    cp "$CIDR_SCANNER_DISCOVERY_FIXTURE" "$output"
    return $?
  fi

  local candidates="${5:-${output}.candidates}" batch="${output}.batch"
  local ip count=0 number=0 xml
  [[ -n "${5:-}" ]] || cidr_enumerate "$cidr" > "$candidates" || return 1
  printf '<nmaprun>\n' > "$output"
  : > "$batch"
  while IFS= read -r ip || [[ -n "$ip" ]]; do
    [[ -n "$ip" ]] || continue
    printf '%s\n' "$ip" >> "$batch"
    ((count += 1))
    if ((count == jobs)); then
      ((number += 1))
      xml="${output}.part-$number"
      host_discovery_batch "$batch" "$xml" "$timeout_value" "$output" || return 1
      log_info "stage=discovery batch=$number candidates=$count max_discovery_jobs=$jobs"
      count=0
      : > "$batch"
    fi
  done < "$candidates"
  if ((count)); then
    ((number += 1))
    host_discovery_batch "$batch" "${output}.part-$number" "$timeout_value" "$output" || return 1
    log_info "stage=discovery batch=$number candidates=$count max_discovery_jobs=$jobs"
  fi
  printf '</nmaprun>\n' >> "$output"
}

host_discovery_batch() {
  local batch="$1" xml="$2" seconds="$3" output="$4" ip
  local -a cmd=(nmap -n -sn --max-retries 1 --host-timeout "${seconds}s" -iL "$batch" -oX "$xml")
  if declare -F worker_pool_command >/dev/null; then
    worker_pool_command "${cmd[@]}" >&2 || return 1
  else
    "${cmd[@]}" >&2 || return 1
  fi
  host_discovery_parse_responsive "$xml" > "${xml}.responsive" || return 1
  while IFS= read -r ip; do
    printf '<host>\n<status state="up"/>\n<address addr="%s" addrtype="ipv4"/>\n</host>\n' "$ip"
  done < "${xml}.responsive" >> "$output"
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
  awk 'FILENAME == ARGV[1] { up[$1]=1; next } { print $1 "\t" (($1 in up) ? "responsive" : "inactive") }' \
    "$responsive_file" "$candidates_file"
}
