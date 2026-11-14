#!/bin/bash
# Host-side relay for bench tests in a container: runs bench-ctl (target1/target2 only) for request files in DIR.
set -u
DIR=$1 COMPOSE=$2
mkdir -p "$DIR"
rm -f "$DIR"/req.* "$DIR"/res.* "$DIR"/.res.*

answer() {
	local target=$1 cmd=$2
	shift 2
	case $target in target1 | target2) ;; *) echo "relay: target $target not allowed"; return 2 ;; esac
	case $cmd in
		reset | set | clear | rotate-hostkey | status | fingerprint)
			docker compose -f "$COMPOSE" exec -T "$target" bench-ctl "$cmd" "$@" 2>&1 ;;
		logs) docker compose -f "$COMPOSE" logs --no-log-prefix --since "$1" "$target" 2>&1 ;;
		*) echo "relay: command $cmd not allowed"; return 2 ;;
	esac
}

while :; do
	for f in "$DIR"/req.*; do
		[ -f "$f" ] || continue
		id=${f##*/req.}
		mapfile -t args <"$f"
		rm -f "$f"
		out=$(answer "${args[@]}")
		printf '%s\n%s' "$?" "$out" >"$DIR/.res.$id" && mv "$DIR/.res.$id" "$DIR/res.$id"
	done
	sleep 0.05
done
