#!/usr/bin/env bash
# Generates and imports SSH keys, authorizes them on one bench target, and logs in with each.
# Needs the bench running (make bench-up). Target: KEYS_BENCH_TARGET, default target3.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
target=${KEYS_BENCH_TARGET:-target3}
work=.dart_tool/keys_bench
host_work=$root/packages/unlock_core/$work

ctl() { docker compose -f "$root/bench/compose.yaml" exec -T "$target" bench-ctl "$@"; }
cleanup() {
	ctl clear >/dev/null || true
	rm -rf "$host_work"
}
trap cleanup EXIT

rm -rf "$host_work"
ctl clear >/dev/null
make -s -C "$root" run-dart \
	CMD="cd packages/unlock_core && dart run test/keys/bench_keys.dart $work"
for pub in "$host_work"/*.pub; do ctl authorize <"$pub"; done
make -s -C "$root" run-dart \
	DOCKER_OPTS="--network luks-bench -e BENCH=1 -e BENCH_HOST=$target -e KEYS_BENCH_DIR=$work" \
	CMD="cd packages/unlock_core && dart test -t bench -r expanded test/keys"
