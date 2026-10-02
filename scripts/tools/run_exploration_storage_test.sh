#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_id="9901$(date +%s)${RANDOM}"
test_config=$(mktemp /tmp/gsf-exploration-config.XXXXXX)
test_log=$(mktemp /tmp/gsf-exploration-log.XXXXXX)
trap 'rm -f "$test_config" "$test_log"' EXIT
for phase in write read; do
  cat > "$test_config" <<EOF
include "/app/etc/exploration-storage-test.config"
exploration_test_id = "$test_id"
exploration_test_phase = "$phase"
EOF
  timeout 15 ./skynet/skynet "$test_config" > "$test_log" 2>&1 || { cat "$test_log"; exit 1; }
  grep -q "EXPLORATION_STORAGE_PASS: $phase" "$test_log" || { cat "$test_log"; exit 1; }
  echo "exploration storage $phase process passed"
done
