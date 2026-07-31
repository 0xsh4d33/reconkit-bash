#!/usr/bin/env bash

printer_exclusion_status_from_fixture() {
  local ip="$1" fixture="$2"
  awk -F '\t' -v ip="$ip" '$1 == ip { print $2; found=1; exit } END { if (!found) exit 1 }' "$fixture"
}

printer_exclusion_probe_ip() {
  local ip="$1" timeout_value="${2:-3}" result

  if [[ -n "${CIDR_SCANNER_PRINTER_FIXTURE:-}" ]]; then
    result="$(printer_exclusion_status_from_fixture "$ip" "$CIDR_SCANNER_PRINTER_FIXTURE")" || {
      printf 'closed\n'
      return 0
    }
    printf '%s\n' "$result"
    return 0
  fi

  local cmd=(nmap -Pn --max-retries 1 -p 9100 -oG - "$ip")
  if command -v timeout >/dev/null 2>&1; then
    if result="$(timeout "$timeout_value" "${cmd[@]}" 2>/dev/null)"; then
      [[ "$result" == *"9100/open"* ]] && printf 'open\n' || printf 'closed\n'
      return 0
    fi
  elif result="$("${cmd[@]}" 2>/dev/null)"; then
    [[ "$result" == *"9100/open"* ]] && printf 'open\n' || printf 'closed\n'
    return 0
  fi

  printf 'failed\n'
}

printer_exclusion_detect() {
  local responsive_file="$1" excluded_file="$2" timeout_value="${3:-3}"
  local ip status tmp_file

  tmp_file="${excluded_file}.tmp"
  : > "$tmp_file"

  while IFS= read -r ip; do
    [[ -n "$ip" ]] || continue
    status="$(printer_exclusion_probe_ip "$ip" "$timeout_value")"
    case "$status" in
      open)
        printf '%s\n' "$ip" >> "$tmp_file"
        ;;
      failed|timeout)
        log_error "stage=printer_exclusion detection_failure ip=$ip status=$status"
        ;;
    esac
  done < "$responsive_file"

  sort -u "$tmp_file" > "$excluded_file"
  rm -f "$tmp_file"
}

printer_exclusion_filter_eligible() {
  local responsive_file="$1" excluded_file="$2" eligible_file="$3"
  awk 'FILENAME == ARGV[1] { excluded[$1]=1; next } $1 != "" && !($1 in excluded) { print $1 }' \
    "$excluded_file" "$responsive_file" | sort -u > "$eligible_file"
}
