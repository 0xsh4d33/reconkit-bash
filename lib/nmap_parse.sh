#!/usr/bin/env bash

nmap_parse() {
  local domain="$1"
  local ip="$2"
  local xml_file="$3"
  [[ -s "$xml_file" ]] || return 1

  if command -v xmlstarlet >/dev/null 2>&1; then
    xmlstarlet val -q "$xml_file" || return 1
    xmlstarlet sel -t \
      -m "//port[state/@state='open']" \
      -v "@portid" -o $'\t' \
      -v "@protocol" -o $'\t' \
      -v "service/@name" -o $'\t' \
      -v "service/@product" -o $'\t' \
      -v "service/@version" \
      -n "$xml_file" |
      while IFS= read -r line; do
        line="${line//$'\t'/$'\x1f'}"
        IFS=$'\x1f' read -r port protocol service product version <<< "$line"
        [[ -n "$port" ]] || continue
        if [[ -n "$product" ]]; then
          service="$service $product"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version"
      done
    return 0
  fi

  local count index base port protocol service product version
  count="$(xmllint --xpath "count(//port[state/@state='open'])" "$xml_file" 2>/dev/null)" || return 1
  for ((index=1; index<=count; index++)); do
    base="(//port[state/@state='open'])[$index]"
    port="$(xmllint --xpath "string($base/@portid)" "$xml_file")" || return 1
    protocol="$(xmllint --xpath "string($base/@protocol)" "$xml_file")" || return 1
    service="$(xmllint --xpath "string($base/service/@name)" "$xml_file")" || return 1
    product="$(xmllint --xpath "string($base/service/@product)" "$xml_file")" || return 1
    version="$(xmllint --xpath "string($base/service/@version)" "$xml_file")" || return 1
    [[ -n "$product" ]] && service="$service $product"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version"
  done
}
