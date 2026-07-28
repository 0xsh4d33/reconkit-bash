#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
. "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/csv.sh
. "$SCRIPT_DIR/lib/csv.sh"
# shellcheck source=lib/dns.sh
. "$SCRIPT_DIR/lib/dns.sh"
# shellcheck source=lib/nmap_scan.sh
. "$SCRIPT_DIR/lib/nmap_scan.sh"
# shellcheck source=lib/nmap_parse.sh
. "$SCRIPT_DIR/lib/nmap_parse.sh"
# shellcheck source=lib/http_probe.sh
. "$SCRIPT_DIR/lib/http_probe.sh"

DOMAINS_FILE=""
PORTS_INPUT=""
OUTPUT_FILE=""
LOG_FILE=""
DNS_SERVER=""
TMP_DIR="${TMPDIR:-/tmp}"
TIMEOUT_VALUE=""
PORTS=()

usage() {
  cat <<'USAGE'
Usage: ./end-scanner.sh --domains <path> --ports <ports|path> --output <path> [options]

Options:
  --log <path>          Write diagnostics to a log file instead of stderr
  --dns-server <ip>     Use this DNS resolver for every target
  --tmp-dir <path>      Directory for temporary scanner/prober output
  --timeout <seconds>   Per-target timeout for supported tools
  --help                Show this help text
USAGE
}

fail() {
  local code="$1"
  shift
  log_error "$*"
  exit "$code"
}

on_interrupt() {
  log_error "interrupted by user"
  exit 130
}

trap on_interrupt INT TERM

parse_args() {
  while (($#)); do
    case "$1" in
      --domains)
        (($# >= 2)) || fail 1 "--domains requires a path"
        DOMAINS_FILE="$2"
        shift 2
        ;;
      --ports)
        (($# >= 2)) || fail 1 "--ports requires a comma list or file path"
        PORTS_INPUT="$2"
        shift 2
        ;;
      --output)
        (($# >= 2)) || fail 1 "--output requires a path"
        OUTPUT_FILE="$2"
        shift 2
        ;;
      --log)
        (($# >= 2)) || fail 1 "--log requires a path"
        LOG_FILE="$2"
        shift 2
        ;;
      --dns-server)
        (($# >= 2)) || fail 1 "--dns-server requires an IP address"
        DNS_SERVER="$2"
        shift 2
        ;;
      --tmp-dir)
        (($# >= 2)) || fail 1 "--tmp-dir requires a path"
        TMP_DIR="$2"
        shift 2
        ;;
      --timeout)
        (($# >= 2)) || fail 1 "--timeout requires seconds"
        TIMEOUT_VALUE="$2"
        shift 2
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        fail 1 "unknown argument: $1"
        ;;
    esac
  done
}

check_dependencies() {
  local missing=0
  local dep
  if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
    log_error "bash 4.4 or newer is required"
    missing=1
  fi
  for dep in nmap httpx jq dig; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      log_error "missing required dependency: $dep"
      missing=1
    fi
  done
  if ! command -v xmllint >/dev/null 2>&1 && ! command -v xmlstarlet >/dev/null 2>&1; then
    log_error "missing required dependency: xmllint or xmlstarlet"
    missing=1
  fi
  ((missing == 0)) || exit 2
}

validate_paths() {
  [[ -n "$DOMAINS_FILE" ]] || fail 1 "--domains is required"
  [[ -n "$PORTS_INPUT" ]] || fail 1 "--ports is required"
  [[ -n "$OUTPUT_FILE" ]] || fail 1 "--output is required"
  [[ -r "$DOMAINS_FILE" ]] || fail 1 "domain file is not readable: $DOMAINS_FILE"
  [[ -d "$TMP_DIR" && -w "$TMP_DIR" ]] || fail 1 "temporary directory is not writable: $TMP_DIR"

  local output_parent
  output_parent="$(dirname "$OUTPUT_FILE")"
  [[ -d "$output_parent" && -w "$output_parent" ]] || fail 1 "output directory is not writable: $output_parent"

  if [[ -n "$LOG_FILE" ]]; then
    local log_parent
    log_parent="$(dirname "$LOG_FILE")"
    [[ -d "$log_parent" && -w "$log_parent" ]] || fail 1 "log directory is not writable: $log_parent"
  fi

  if [[ -n "$TIMEOUT_VALUE" && ! "$TIMEOUT_VALUE" =~ ^[1-9][0-9]*$ ]]; then
    fail 1 "--timeout must be a positive integer"
  fi
}

parse_ports() {
  local raw port
  local seen=" "
  local values=()
  if [[ -r "$PORTS_INPUT" && "$PORTS_INPUT" != *,* ]]; then
    mapfile -t values < "$PORTS_INPUT"
  else
    IFS=',' read -r -a values <<<"$PORTS_INPUT"
  fi

  for raw in "${values[@]}"; do
    port="$(trim "$raw")"
    [[ -n "$port" ]] || continue
    [[ "$port" =~ ^[0-9]+$ ]] || fail 1 "invalid port: $port"
    ((port >= 1 && port <= 65535)) || fail 1 "port out of range: $port"
    if [[ "$seen" != *" $port "* ]]; then
      PORTS+=("$port")
      seen+="$port "
    fi
  done
  ((${#PORTS[@]} > 0)) || fail 3 "no valid ports were provided"
}

join_ports() {
  local IFS=,
  printf '%s' "${PORTS[*]}"
}

write_report() {
  local rows_file="$1"
  {
    csv_header
    if [[ -s "$rows_file" ]]; then
      sort -u "$rows_file" | while IFS= read -r line; do
        line="${line//$'\t'/$'\x1f'}"
        IFS=$'\x1f' read -r domain ip port protocol service version status title tech tech_version <<< "$line"
        csv_row "$domain" "$ip" "$port" "$protocol" "$service" "$version" "$status" "$title" "$tech" "$tech_version"
      done
    fi
  } > "$OUTPUT_FILE" || return 1
}

main() {
  parse_args "$@"
  log_init "$LOG_FILE"
  validate_paths
  validate_resolver_or_exit "$DNS_SERVER" || fail 1 "invalid resolver address: $DNS_SERVER"
  check_resolver_runtime_or_exit "$DNS_SERVER" || fail 1 "resolver failure: $DNS_SERVER"
  check_dependencies
  parse_ports

  local run_dir rows_file services_file web_file targets_file domain_file port_list resolver_mode
  run_dir="$(mktemp -d "$TMP_DIR/end-scanner.XXXXXX")" || fail 4 "could not create temporary directory"
  rows_file="$run_dir/report-rows.tsv"
  services_file="$run_dir/services.tsv"
  web_file="$run_dir/web.tsv"
  targets_file="$run_dir/http-targets.txt"
  domain_file="$run_dir/domains.txt"
  : > "$rows_file"
  : > "$services_file"
  : > "$targets_file"

  normalize_domains "$DOMAINS_FILE" > "$domain_file"
  [[ -s "$domain_file" ]] || fail 3 "no valid scan targets were provided"

  resolver_mode="$(resolver_mode "$DNS_SERVER")"
  port_list="$(join_ports)"

  local domain ip family xml_file
  while IFS= read -r domain; do
    local resolved_file="$run_dir/resolved-${domain//[^A-Za-z0-9_.-]/_}.tsv"
    if ! resolve_domain "$domain" "$DNS_SERVER" "$resolved_file"; then
      log_error "unresolved domain: $domain"
      continue
    fi
    if [[ ! -s "$resolved_file" ]]; then
      log_error "unresolved domain: $domain"
      continue
    fi

    while IFS=$'\t' read -r _resolved_domain ip family; do
      [[ -n "$ip" && -n "$family" ]] || continue
      xml_file="$run_dir/nmap-${domain//[^A-Za-z0-9_.-]/_}-${ip//[^A-Za-z0-9_.-]/_}.xml"
      if ! nmap_scan "$ip" "$port_list" "$xml_file" "$TIMEOUT_VALUE"; then
        log_error "scan failure for $domain ($ip)"
        continue
      fi
      if ! nmap_parse "$domain" "$ip" "$xml_file" >> "$services_file"; then
        log_error "parser failure for nmap output: $domain ($ip)"
        continue
      fi
    done < "$resolved_file"
  done < "$domain_file"

  if [[ -s "$services_file" ]]; then
    awk -F '\t' '{ print "http://"$1":"$3; print "https://"$1":"$3 }' "$services_file" | sort -u > "$targets_file"
    if ! http_probe "$targets_file" "$run_dir/httpx.jsonl" "$TIMEOUT_VALUE"; then
      log_error "httpx probe failure or timeout"
      : > "$run_dir/httpx.jsonl"
    fi
    http_probe_parse "$run_dir/httpx.jsonl" > "$web_file" || {
      log_error "parser failure for httpx output"
      : > "$web_file"
    }

    while IFS= read -r service_line; do
      service_line="${service_line//$'\t'/$'\x1f'}"
      IFS=$'\x1f' read -r domain ip port protocol service version <<< "$service_line"
      local matched=0
      while IFS= read -r web_line; do
        web_line="${web_line//$'\t'/$'\x1f'}"
        IFS=$'\x1f' read -r web_domain web_ip web_port status title tech tech_version <<< "$web_line"
        if [[ "$web_domain" == "$domain" && ( -z "$web_ip" || "$web_ip" == "$ip" ) && "$web_port" == "$port" ]]; then
          printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version" "$status" "$title" "$tech" "$tech_version" >> "$rows_file"
          matched=1
        fi
      done < "$web_file"
      if ((matched == 0)); then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t\t\t\t\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version" >> "$rows_file"
      fi
    done < "$services_file"
  fi

  write_report "$rows_file" || fail 4 "could not write CSV report: $OUTPUT_FILE"
  log_info "completed inventory using $resolver_mode resolver mode"
}

main "$@"
