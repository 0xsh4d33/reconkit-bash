#!/usr/bin/env bash

nmap_parse() {
  local domain="$1"
  local ip="$2"
  local xml_file="$3"
  [[ -s "$xml_file" ]] || return 1

  if command -v xmlstarlet >/dev/null 2>&1; then
    xmlstarlet sel -t \
      -m "//port[state/@state='open']" \
      -v "@portid" -o $'\t' \
      -v "@protocol" -o $'\t' \
      -v "service/@name" -o $'\t' \
      -v "service/@product" -o $'\t' \
      -v "service/@version" \
      -n "$xml_file" |
      while IFS=$'\t' read -r port protocol service product version; do
        [[ -n "$port" ]] || continue
        if [[ -n "$product" ]]; then
          service="$service $product"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$domain" "$ip" "$port" "$protocol" "$service" "$version"
      done
    return "${PIPESTATUS[0]}"
  fi

  xmllint --xpath "//port[state/@state='open']" "$xml_file" >/dev/null 2>&1
}
