#!/usr/bin/env bash
set -euo pipefail

crate_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo_dir=$(cd "$crate_dir/../.." && pwd)
manifest="$crate_dir/Cargo.toml"

cargo fmt --manifest-path "$manifest" --check
cargo test --manifest-path "$manifest"
cargo clippy --manifest-path "$manifest" --all-targets -- -D warnings
bash -n \
  "$repo_dir/script/focus-session.sh" \
  "$repo_dir/script/load-theme.sh" \
  "$repo_dir/script/swap-session.sh" \
  "$repo_dir/script/status-scheduler.sh" \
  "$crate_dir/tests/client-hooks-integration.sh" \
  "$crate_dir/tests/driver-fault-integration.sh" \
  "$crate_dir/tests/focus-session-integration.sh" \
  "$crate_dir/tests/renderer-lifecycle-integration.sh" \
  "$crate_dir/tests/running-indicator-integration.sh" \
  "$crate_dir/tests/swap-session-integration.sh" \
  "$crate_dir/tests/scheduler-integration.sh"
"$crate_dir/tests/client-hooks-integration.sh"
"$crate_dir/tests/driver-fault-integration.sh"
"$crate_dir/tests/focus-session-integration.sh"
"$crate_dir/tests/renderer-lifecycle-integration.sh"
"$crate_dir/tests/running-indicator-integration.sh"
"$crate_dir/tests/swap-session-integration.sh"
"$crate_dir/tests/scheduler-integration.sh"
git -C "$repo_dir" diff --check
