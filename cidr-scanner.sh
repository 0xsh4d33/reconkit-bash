#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/logging.sh
. "$SCRIPT_DIR/lib/logging.sh"
# shellcheck source=lib/csv.sh
. "$SCRIPT_DIR/lib/csv.sh"
# shellcheck source=lib/cidr.sh
. "$SCRIPT_DIR/lib/cidr.sh"
# shellcheck source=lib/host_discovery.sh
. "$SCRIPT_DIR/lib/host_discovery.sh"
# shellcheck source=lib/progress.sh
. "$SCRIPT_DIR/lib/progress.sh"
# shellcheck source=lib/reverse_dns.sh
. "$SCRIPT_DIR/lib/reverse_dns.sh"
# shellcheck source=lib/nmap_scan.sh
. "$SCRIPT_DIR/lib/nmap_scan.sh"
# shellcheck source=lib/nmap_parse.sh
. "$SCRIPT_DIR/lib/nmap_parse.sh"
# shellcheck source=lib/http_probe.sh
. "$SCRIPT_DIR/lib/http_probe.sh"
# shellcheck source=lib/printer_exclusion.sh
. "$SCRIPT_DIR/lib/printer_exclusion.sh"

CIDR_INPUT=""
PORTS_INPUT=""
OUTPUT_FILE=""
LOG_FILE=""
TMP_DIR="${TMPDIR:-/tmp}"
MAX_DISCOVERY_JOBS=64
MAX_SCAN_JOBS=16
MAX_PROBE_JOBS=16
HOST_TIMEOUT=3
PROBE_TIMEOUT=5
PORTS=()

usage() {
  cat <<'USAGE'
Usage: ./cidr-scanner.sh --cidr <cidr> --ports <ports|path> --output <path> [options]

Options:
  --log <path>                    Write diagnostics to a log file instead of stderr
  --tmp-dir <path>                Directory for temporary discovery, scanner, and prober output
  --max-discovery-jobs <count>    Maximum concurrent discovery work
  --max-scan-jobs <count>         Maximum concurrent service scan work
  --max-probe-jobs <count>        Maximum concurrent web probe work
  --host-timeout <seconds>        Per-host timeout for discovery/service stages
  --probe-timeout <seconds>       Per-web-probe timeout
  --help                          Show this help text
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

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --cidr) (($# >= 2)) || fail 1 "--cidr requires a CIDR range"; CIDR_INPUT="$2"; shift 2 ;;
      --ports) (($# >= 2)) || fail 1 "--ports requires a comma list or file path"; PORTS_INPUT="$2"; shift 2 ;;
      --output) (($# >= 2)) || fail 1 "--output requires a path"; OUTPUT_FILE="$2"; shift 2 ;;
      --log) (($# >= 2)) || fail 1 "--log requires a path"; LOG_FILE="$2"; shift 2 ;;
      --tmp-dir) (($# >= 2)) || fail 1 "--tmp-dir requires a path"; TMP_DIR="$2"; shift 2 ;;
      --max-discovery-jobs) (($# >= 2)) || fail 1 "--max-discovery-jobs requires a count"; MAX_DISCOVERY_JOBS="$2"; shift 2 ;;
      --max-scan-jobs) (($# >= 2)) || fail 1 "--max-scan-jobs requires a count"; MAX_SCAN_JOBS="$2"; shift 2 ;;
      --max-probe-jobs) (($# >= 2)) || fail 1 "--max-probe-jobs requires a count"; MAX_PROBE_JOBS="$2"; shift 2 ;;
      --host-timeout) (($# >= 2)) || fail 1 "--host-timeout requires seconds"; HOST_TIMEOUT="$2"; shift 2 ;;
      --probe-timeout) (($# >= 2)) || fail 1 "--probe-timeout requires seconds"; PROBE_TIMEOUT="$2"; shift 2 ;;
      --help) usage; exit 0 ;;
      *) fail 1 "unknown argument: $1" ;;
    esac
  done
}

require_positive_integer() {
  local name="$1" value="$2"
  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail 1 "$name must be a positive integer"
}

validate_performance_controls() {
  require_positive_integer "--max-discovery-jobs" "$MAX_DISCOVERY_JOBS"
  require_positive_integer "--max-scan-jobs" "$MAX_SCAN_JOBS"
  require_positive_integer "--max-probe-jobs" "$MAX_PROBE_JOBS"
  require_positive_integer "--host-timeout" "$HOST_TIMEOUT"
  require_positive_integer "--probe-timeout" "$PROBE_TIMEOUT"
}

check_dependencies() {
  [[ "${CIDR_SCANNER_SKIP_DEP_CHECK:-}" == "1" ]] && return 0
  local missing=0 dep
  if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
    log_error "bash 4.4 or newer is required"
    missing=1
  fi
  for dep in nmap httpx jq; do
    command -v "$dep" >/dev/null 2>&1 || { log_error "missing required dependency: $dep"; missing=1; }
  done
  if ! command -v dig >/dev/null 2>&1 && ! command -v host >/dev/null 2>&1; then
    log_error "missing required dependency: dig or host"
    missing=1
  fi
  if ! command -v xmllint >/dev/null 2>&1 && ! command -v xmlstarlet >/dev/null 2>&1; then
    log_error "missing required dependency: xmllint or xmlstarlet"
    missing=1
  fi
  ((missing == 0)) || exit 2
}

validate_paths() {
  [[ -n "$CIDR_INPUT" ]] || fail 1 "--cidr is required"
  [[ -n "$PORTS_INPUT" ]] || fail 1 "--ports is required"
  [[ -n "$OUTPUT_FILE" ]] || fail 1 "--output is required"
  cidr_validate "$CIDR_INPUT" || fail 1 "invalid or unsupported CIDR: $CIDR_INPUT"
  [[ -d "$TMP_DIR" && -w "$TMP_DIR" ]] || fail 1 "temporary directory is not writable: $TMP_DIR"

  local output_parent log_parent
  output_parent="$(dirname "$OUTPUT_FILE")"
  [[ -d "$output_parent" && -w "$output_parent" ]] || fail 1 "output directory is not writable: $output_parent"
  if [[ -n "$LOG_FILE" ]]; then
    log_parent="$(dirname "$LOG_FILE")"
    [[ -d "$log_parent" && -w "$log_parent" ]] || fail 1 "log directory is not writable: $log_parent"
  fi
}

parse_ports() {
  local raw port seen=" " values=()
  if [[ -r "$PORTS_INPUT" && "$PORTS_INPUT" != *,* ]]; then
    mapfile -t values < "$PORTS_INPUT"
  else
    IFS=',' read -r -a values <<< "$PORTS_INPUT"
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

lookup_domain_for_ip() {
  local ip="$1" reverse_file="$2"
  awk -F '\t' -v ip="$ip" '$1 == ip { print $2; exit }' "$reverse_file"
}

write_cidr_report() {
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
  } > "$OUTPUT_FILE"
}

main() {
  parse_args "$@"
  log_init "$LOG_FILE"
  validate_performance_controls
  validate_paths
  check_dependencies
  parse_ports

  local run_dir candidates_file discovery_xml responsive_file status_file printer_excluded_file eligible_file reverse_file services_file web_file targets_file rows_file
  local candidate_count responsive_count excluded_count eligible_count port_list ip domain xml_file service_line web_line matched
  run_dir="$(mktemp -d "$TMP_DIR/cidr-scanner.XXXXXX")" || fail 4 "could not create temporary directory"
  candidates_file="$run_dir/candidates.txt"
  discovery_xml="$run_dir/discovery.xml"
  responsive_file="$run_dir/responsive.txt"
  status_file="$run_dir/candidates-status.tsv"
  printer_excluded_file="$run_dir/printer-excluded.txt"
  eligible_file="$run_dir/eligible.txt"
  reverse_file="$run_dir/reverse.tsv"
  services_file="$run_dir/services.tsv"
  web_file="$run_dir/web.tsv"
  targets_file="$run_dir/http-targets.txt"
  rows_file="$run_dir/report-rows.tsv"
  : > "$services_file"; : > "$targets_file"; : > "$rows_file"

  progress_stage_start input "cidr=$CIDR_INPUT"
  cidr_enumerate "$CIDR_INPUT" > "$candidates_file" || fail 1 "could not enumerate CIDR: $CIDR_INPUT"
  candidate_count="$(wc -l < "$candidates_file" | tr -d ' ')"
  progress_count input candidate_count "$candidate_count"
  progress_stage_complete input "candidate_count=$candidate_count"
  ((candidate_count > 0)) || fail 3 "no valid candidate hosts"

  progress_stage_start discovery "cidr=$CIDR_INPUT max_discovery_jobs=$MAX_DISCOVERY_JOBS"
  host_discovery_run "$CIDR_INPUT" "$discovery_xml" "$MAX_DISCOVERY_JOBS" "$HOST_TIMEOUT" || fail 4 "host discovery failed"
  host_discovery_parse_responsive "$discovery_xml" > "$responsive_file" || fail 4 "could not parse host discovery output"
  host_discovery_mark_candidates "$candidates_file" "$responsive_file" > "$status_file"
  responsive_count="$(wc -l < "$responsive_file" | tr -d ' ')"
  progress_stage_complete discovery "candidate_count=$candidate_count responsive_count=$responsive_count"
  ((responsive_count > 0)) || fail 3 "no responsive hosts were discovered"

  progress_stage_start printer_exclusion "checked=$responsive_count"
  printer_exclusion_detect "$responsive_file" "$printer_excluded_file" "$HOST_TIMEOUT"
  printer_exclusion_filter_eligible "$responsive_file" "$printer_excluded_file" "$eligible_file"
  excluded_count="$(wc -l < "$printer_excluded_file" | tr -d ' ')"
  eligible_count="$(wc -l < "$eligible_file" | tr -d ' ')"
  if ((excluded_count > 0)); then
    while IFS= read -r ip; do
      [[ -n "$ip" ]] || continue
      log_info "stage=printer_exclusion excluded ip=$ip reason=\"open port 9100\""
    done < "$printer_excluded_file"
  else
    log_info "stage=printer_exclusion no_exclusions_found"
  fi
  progress_stage_complete printer_exclusion "checked=$responsive_count excluded_count=$excluded_count eligible_count=$eligible_count"
  ((eligible_count > 0)) || fail 3 "no eligible hosts remain after printer exclusion"

  progress_stage_start reverse_dns "responsive_count=$eligible_count"
  reverse_dns_resolve_file "$eligible_file" "$reverse_file" "$HOST_TIMEOUT"
  progress_stage_complete reverse_dns "responsive_count=$eligible_count"

  progress_stage_start service_scan "responsive_count=$eligible_count max_scan_jobs=$MAX_SCAN_JOBS"
  port_list="$(join_ports)"
  while IFS= read -r ip; do
    [[ -n "$ip" ]] || continue
    domain="$(lookup_domain_for_ip "$ip" "$reverse_file")"
    xml_file="$run_dir/nmap-${ip//[^A-Za-z0-9_.-]/_}.xml"
    if nmap_scan "$ip" "$port_list" "$xml_file" "$HOST_TIMEOUT"; then
      nmap_parse "$domain" "$ip" "$xml_file" >> "$services_file" || log_error "stage=service_scan parser failure ip=$ip"
    else
      log_error "stage=service_scan scan failure ip=$ip"
    fi
  done < "$eligible_file"
  progress_stage_complete service_scan "service_rows=$(wc -l < "$services_file" | tr -d ' ')"

  progress_stage_start web_probe "max_probe_jobs=$MAX_PROBE_JOBS"
  if [[ -s "$services_file" ]]; then
    awk -F '\t' '{ print "http://"$2":"$3; print "https://"$2":"$3 }' "$services_file" | sort -u > "$targets_file"
    if http_probe "$targets_file" "$run_dir/httpx.jsonl" "$PROBE_TIMEOUT"; then
      http_probe_parse "$run_dir/httpx.jsonl" > "$web_file" || { log_error "stage=web_probe parser failure"; : > "$web_file"; }
    else
      log_error "stage=web_probe probe failure or timeout"
      : > "$web_file"
    fi
  else
    : > "$web_file"
  fi
  progress_stage_complete web_probe "web_rows=$(wc -l < "$web_file" | tr -d ' ')"

  progress_stage_start report "output=$OUTPUT_FILE"
  while IFS= read -r service_line; do
    service_line="${service_line//$'\t'/$'\x1f'}"
    IFS=$'\x1f' read -r domain ip port protocol service version <<< "$service_line"
    matched=0
    while IFS= read -r web_line; do
      web_line="${web_line//$'\t'/$'\x1f'}"
      IFS=$'\x1f' read -r web_domain web_ip web_port status title tech tech_version <<< "$web_line"
      if [[ ( "$web_domain" == "$ip" || "$web_domain" == "$domain" || "$web_ip" == "$ip" ) && "$web_port" == "$port" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version" "$status" "$title" "$tech" "$tech_version" >> "$rows_file"
        matched=1
      fi
    done < "$web_file"
    if ((matched == 0)); then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t\t\t\t\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version" >> "$rows_file"
    fi
  done < "$services_file"
  if [[ -s "$printer_excluded_file" && -s "$rows_file" ]]; then
    awk -F '\t' 'NR==FNR { excluded[$1]=1; next } !($2 in excluded)' \
      "$printer_excluded_file" "$rows_file" > "$rows_file.filtered"
    mv "$rows_file.filtered" "$rows_file"
  fi
  write_cidr_report "$rows_file" || fail 4 "could not write CSV report: $OUTPUT_FILE"
  progress_stage_complete report "output=$OUTPUT_FILE rows=$(wc -l < "$rows_file" | tr -d ' ')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
