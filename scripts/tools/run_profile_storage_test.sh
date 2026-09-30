#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
# An isolated numeric identity; never uses configured accounts or alters their profiles.
test_id="9900$(date +%s)${RANDOM}"
test_config=$(mktemp /tmp/gsf-profile-config.XXXXXX)
test_log=$(mktemp /tmp/gsf-profile-log.XXXXXX)
trap 'rm -f "$test_config" "$test_log"' EXIT
for phase in write read; do
  cat > "$test_config" <<EOF
include "/app/etc/profile-storage-test.config"
profile_test_id = "$test_id"
profile_test_phase = "$phase"
EOF
  if ! timeout 15 ./skynet/skynet "$test_config" > "$test_log" 2>&1; then
    cat "$test_log"
    exit 1
  fi
  if ! grep -q "PROFILE_STORAGE_TEST_PASS: $phase" "$test_log"; then
    cat "$test_log"
    exit 1
  fi
  echo "profile storage $phase process passed"
done
echo "complete profile persisted and recovered in a new Skynet process; test rows removed"
