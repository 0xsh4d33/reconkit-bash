#!/usr/bin/env bash

LOG_DEST=""

log_init() {
  LOG_DEST="${1:-}"
  if [[ -n "$LOG_DEST" ]]; then
    : > "$LOG_DEST"
  fi
}

log_line() {
  local level="$1"
  shift
  if [[ -n "$LOG_DEST" ]]; then
    printf '%s: %s\n' "$level" "$*" >> "$LOG_DEST"
  else
    printf '%s: %s\n' "$level" "$*" >&2
  fi
}

log_info() {
  log_line "INFO" "$@"
}

log_error() {
  log_line "ERROR" "$@"
}
