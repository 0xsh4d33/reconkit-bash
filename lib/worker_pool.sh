#!/usr/bin/env bash

POOL_PIDS=()

worker_pool_cancel() {
  local pid
  for pid in "${POOL_PIDS[@]}"; do
    kill -TERM -- "-$pid" 2>/dev/null || :
  done
  ((${#POOL_PIDS[@]})) && sleep 0.2
  for pid in "${POOL_PIDS[@]}"; do
    kill -KILL -- "-$pid" 2>/dev/null || :
    wait "$pid" 2>/dev/null || :
  done
  POOL_PIDS=()
}

# Callback receives the input line followed by caller arguments. Each worker
# owns its output files; only the parent merges them after all work finishes.
worker_pool_run() {
  local input="$1" limit="$2" directory="$3" callback="$4"
  shift 4
  local item pid index=0 monitor=0 rc failed=0 parent_log="${LOG_DEST:-}"
  local -a remaining=()
  [[ $- == *m* ]] && monitor=1
  mkdir -p "$directory" || return 1
  POOL_PIDS=()
  set -m
  while IFS= read -r item || [[ -n "$item" ]]; do
    [[ -n "$item" ]] || continue
    while ((${#POOL_PIDS[@]} >= limit)); do
      remaining=()
      for pid in "${POOL_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
          remaining+=("$pid")
        else
          wait "$pid" || failed=1
        fi
      done
      POOL_PIDS=("${remaining[@]}")
      ((${#POOL_PIDS[@]} >= limit)) && sleep 0.02
    done
    ((index += 1))
    (
      set +m
      trap - INT TERM
      # Route the logging helper to the worker file as well.
      # shellcheck disable=SC2034 # Read by lib/logging.sh in the callback.
      LOG_DEST=""
      "$callback" "$item" "$@"
      rc=$?
      printf '%s\n' "$rc" > "$directory/$index.status"
      exit "$rc"
    ) > "$directory/$index.out" 2> "$directory/$index.err" &
    POOL_PIDS+=("$!")
  done < "$input"
  for pid in "${POOL_PIDS[@]}"; do
    wait "$pid" || failed=1
  done
  POOL_PIDS=()
  ((monitor)) || set +m
  local i
  for ((i=1; i<=index; i++)); do
    cat "$directory/$i.out" || failed=1
    if [[ -n "$parent_log" ]]; then
      cat "$directory/$i.err" >> "$parent_log" || failed=1
    else
      cat "$directory/$i.err" >&2 || failed=1
    fi
  done
  if declare -F log_info >/dev/null; then
    local success=0 code
    for ((i=1; i<=index; i++)); do
      code=1
      [[ -r "$directory/$i.status" ]] && read -r code < "$directory/$i.status"
      [[ "$code" == 0 ]] && ((success += 1))
    done
    log_info "workers attempted=$index completed=$success failed=$((index-success))"
  fi
  return "$failed"
}

# Run a whole-stage external command in an owned process group so the main
# interrupt handler can terminate it and its descendants while wait is active.
worker_pool_command() {
  local monitor=0 code
  [[ $- == *m* ]] && monitor=1
  set -m
  "$@" &
  POOL_PIDS=("$!")
  wait "${POOL_PIDS[0]}"
  code=$?
  POOL_PIDS=()
  ((monitor)) || set +m
  return "$code"
}
