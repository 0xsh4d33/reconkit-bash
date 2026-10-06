#!/usr/bin/env bash

declare -A PROGRESS_STARTED=()

progress_stage_start() {
  local stage="$1"
  shift
  PROGRESS_STARTED["$stage"]=$SECONDS
  log_info "stage=$stage status=start $*"
}

progress_stage_complete() {
  local stage="$1"
  shift
  log_info "stage=$stage status=complete $* elapsed_seconds=$((SECONDS - ${PROGRESS_STARTED[$stage]:-$SECONDS}))"
}

progress_stage_error() {
  local stage="$1"
  shift
  log_error "stage=$stage status=error $*"
}

progress_count() {
  local stage="$1" name="$2" value="$3"
  log_info "stage=$stage $name=$value"
}
