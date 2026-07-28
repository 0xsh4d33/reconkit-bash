#!/usr/bin/env bash

trim() {
  local value="${1-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_domains() {
  local input="$1"
  local line domain
  awk '
    {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      if ($0 == "" || $0 ~ /^#/) next
      domain=tolower($0)
      if (!seen[domain]++) print domain
    }
  ' "$input"
}

is_ipv4() {
  local ip="$1"
  local IFS=.
  local -a parts
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  read -r -a parts <<< "$ip"
  local part
  for part in "${parts[@]}"; do
    ((part >= 0 && part <= 255)) || return 1
  done
}

is_ipv6() {
  local ip="$1"
  [[ "$ip" == *:* && "$ip" =~ ^[0-9A-Fa-f:]+$ ]]
}

validate_resolver_or_exit() {
  local resolver="${1-}"
  [[ -z "$resolver" ]] && return 0
  is_ipv4 "$resolver" || is_ipv6 "$resolver"
}

resolver_mode() {
  if [[ -n "${1-}" ]]; then
    printf 'explicit'
  else
    printf 'default'
  fi
}

check_resolver_runtime_or_exit() {
  local resolver="${1-}"
  [[ -z "$resolver" ]] && return 0

  case "${END_SCANNER_RESOLVER_STATUS:-valid}" in
    valid|"")
      return 0
      ;;
    invalid)
      log_error "invalid DNS resolver: $resolver"
      return 1
      ;;
    unreachable)
      log_error "unreachable DNS resolver: $resolver"
      return 1
      ;;
    non_responsive|non-responsive)
      log_error "non-responsive DNS resolver: $resolver"
      return 1
      ;;
    *)
      log_error "resolver failure for $resolver: ${END_SCANNER_RESOLVER_STATUS}"
      return 1
      ;;
  esac
}

address_family() {
  local ip="$1"
  if is_ipv4 "$ip"; then
    printf 'ipv4'
  else
    printf 'ipv6'
  fi
}

resolve_from_fixture() {
  local domain="$1"
  local resolver="$2"
  local output="$3"
  local fixture="${END_SCANNER_DNS_FIXTURE:-}"
  [[ -n "$fixture" && -r "$fixture" ]] || return 2

  local mode
  mode="$(resolver_mode "$resolver")"
  awk -v mode="$mode" -v domain="$domain" -F '\t' '
    $1 == mode && $2 == domain && $3 == "ok" { print $2 "\t" $4 "\t" $5; found=1 }
    $1 == mode && $2 == domain && $3 != "ok" { failed=1 }
    END {
      if (found) exit 0
      if (failed) exit 1
      exit 1
    }
  ' "$fixture" > "$output"
}

resolve_domain() {
  local domain="$1"
  local resolver="${2-}"
  local output="$3"
  : > "$output"

  if resolve_from_fixture "$domain" "$resolver" "$output"; then
    sort -u "$output" -o "$output"
    return 0
  elif [[ -n "${END_SCANNER_DNS_FIXTURE:-}" ]]; then
    return 1
  fi

  if [[ -n "$resolver" ]]; then
    dig @"$resolver" +time=2 +tries=1 +short A "$domain" | awk -v d="$domain" '/^[0-9.]+$/ { print d "\t" $1 "\tipv4" }' >> "$output"
    dig @"$resolver" +time=2 +tries=1 +short AAAA "$domain" | awk -v d="$domain" '/^[0-9A-Fa-f:]+$/ { print d "\t" $1 "\tipv6" }' >> "$output"
  else
    if command -v getent >/dev/null 2>&1; then
      getent ahosts "$domain" | awk -v d="$domain" '{ if ($1 ~ /^[0-9.]+$/) print d "\t" $1 "\tipv4" }' >> "$output"
    fi
    dig +short A "$domain" | awk -v d="$domain" '/^[0-9.]+$/ { print d "\t" $1 "\tipv4" }' >> "$output"
    dig +short AAAA "$domain" | awk -v d="$domain" '/^[0-9A-Fa-f:]+$/ { print d "\t" $1 "\tipv6" }' >> "$output"
  fi

  sort -u "$output" -o "$output"
  [[ -s "$output" ]]
}
