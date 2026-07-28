#!/usr/bin/env bash

http_probe() {
  local targets_file="$1"
  local output="$2"
  local timeout_value="${3-}"

  if [[ -n "${END_SCANNER_HTTPX_FIXTURE:-}" ]]; then
    cp "$END_SCANNER_HTTPX_FIXTURE" "$output"
    return $?
  fi

  local cmd=(httpx -silent -json -tech-detect -status-code -title -list "$targets_file" -o "$output")
  if [[ -n "$timeout_value" ]] && command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_value" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}

http_probe_parse() {
  local jsonl="$1"
  [[ -s "$jsonl" ]] || return 0
  jq -r '
    def is_ip:
      test("^([0-9]{1,3}\\.){3}[0-9]{1,3}$") or test("^[0-9A-Fa-f:]+$");
    def host_from_url:
      (.url // .input // "") | sub("^https?://"; "") | split("/")[0] | split(":")[0];
    def port_from_url:
      (.port // ((.url // .input // "") | capture(":(?<p>[0-9]+)")?.p) // (if ((.url // "") | startswith("https://")) then "443" else "80" end)) | tostring;
    def ip_value:
      if (.ip? and ((.ip | tostring) | is_ip)) then (.ip | tostring)
      elif (.host? and ((.host | tostring) | is_ip)) then (.host | tostring)
      else ""
      end;
    def tech_list:
      if (.technologies | type) == "array" then .technologies
      elif (.tech | type) == "array" then .tech
      else []
      end;
    def split_inline_version:
      tostring as $raw |
      if ($raw | test(":[0-9][A-Za-z0-9._+~-]*$")) then
        [($raw | sub(":[0-9][A-Za-z0-9._+~-]*$"; "")), ($raw | capture(":(?<version>[0-9][A-Za-z0-9._+~-]*)$").version)]
      else
        [$raw, ""]
      end;
    def tech_rows:
      if (tech_list | length) > 0 then
        tech_list[] as $tech |
        ($tech | split_inline_version) as $parts |
        ($parts[0]) as $name |
        ($parts[1]) as $inline_version |
        [host_from_url, ip_value, port_from_url, ((.status_code // .status) // ""), (.title // ""), $name, (((.tech_versions[$name][0] // .tech_versions[$name] // $inline_version) // "") | tostring)] | @tsv
      else
        [host_from_url, ip_value, port_from_url, ((.status_code // .status) // ""), (.title // ""), "", ""] | @tsv
      end;
    tech_rows
  ' "$jsonl"
}
