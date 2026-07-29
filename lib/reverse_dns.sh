#!/usr/bin/env bash

reverse_dns_lookup() {
  local ip="$1" timeout_value="${2:-3}" name=""

  if [[ -n "${CIDR_SCANNER_REVERSE_DNS_FIXTURE:-}" ]]; then
    awk -v ip="$ip" '$1 == ip { print $2; found=1; exit } END { if (!found) exit 1 }' \
      "$CIDR_SCANNER_REVERSE_DNS_FIXTURE"
    return $?
  fi

  if command -v dig >/dev/null 2>&1; then
    name="$(dig +time="$timeout_value" +tries=1 +short -x "$ip" 2>/dev/null | sed -n '1s/\.$//p')"
  elif command -v host >/dev/null 2>&1; then
    name="$(host -W "$timeout_value" "$ip" 2>/dev/null | awk '/pointer/ {print $NF; exit}' | sed 's/\.$//')"
  else
    return 1
  fi
  [[ -n "$name" ]] || return 1
  printf '%s\n' "$name"
}

reverse_dns_resolve_file() {
  local ips_file="$1" output="$2" timeout_value="${3:-3}" ip name
  : > "$output"
  while IFS= read -r ip; do
    [[ -n "$ip" ]] || continue
    if name="$(reverse_dns_lookup "$ip" "$timeout_value")"; then
      printf '%s\t%s\n' "$ip" "$name" >> "$output"
    else
      printf '%s\t\n' "$ip" >> "$output"
      log_error "stage=reverse_dns unresolved ip=$ip"
    fi
  done < "$ips_file"
}
