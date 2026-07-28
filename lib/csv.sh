#!/usr/bin/env bash

CSV_HEADER="Domain,IP,Port,Protocol,Service,Service Version,HTTP Status,HTTP Title,HTTP Tech,Tech Version"

csv_header() {
  printf '%s\n' "$CSV_HEADER"
}

csv_escape() {
  local value="${1-}"
  value="${value//$'"'/$'""'}"
  if [[ "$value" == *","* || "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *'"'* ]]; then
    printf '"%s"' "$value"
  else
    printf '%s' "$value"
  fi
}

csv_row() {
  local first=1 field
  for field in "$@"; do
    if ((first)); then
      first=0
    else
      printf ','
    fi
    csv_escape "$field"
  done
  printf '\n'
}
