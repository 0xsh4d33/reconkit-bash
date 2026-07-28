#!/usr/bin/env bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_scanner() {
  (cd "$REPO_ROOT" && ./end-scanner.sh "$@")
}
