#!/usr/bin/env bash
# Bench self-test: stock OpenSSH client in a container on the bench network; leaves the bench down.
set -uo pipefail
cd "$(dirname "$0")"

P=correct-horse-bench
W=wrong-horse-bench
P2=other-horse-bench
DC=(docker compose -f compose.yaml --profile test)
SSH="ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=5 -o IdentitiesOnly=yes"
GOOD=/root/.ssh/id_ed25519_bench
BAD=/root/.ssh/id_ed25519_wrong
FAILS=0
TMP=$(mktemp -d)
trap 'sec "bench down"; "${DC[@]}" down -v --remove-orphans >/dev/null 2>&1; rm -rf "$TMP"' EXIT

sec() { echo "== $* [${SECONDS}s]"; }
pass() { echo "PASS $1"; }
fail() { echo "FAIL $1${2:+ -- $2}"; FAILS=$((FAILS + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1" "${3:-}"; fi; }
ms() { echo $(($(date +%s%N) / 1000000)); }
ctl() { "${DC[@]}" exec -T "$1" bench-ctl "${@:2}"; }
cl() { "${DC[@]}" exec -T client "$@"; }
phase() { ctl "$1" status | head -n1; }
keyscan() { cl ssh-keyscan -T 3 -t ed25519 -p "$2" "$1" 2>/dev/null | awk '{print $2, $3}'; }
port_open() { cl timeout 2 bash -c "</dev/tcp/$1/$2" 2>/dev/null; }
fp_of() { cl sh -c 'echo "x $1" | ssh-keygen -lf - | cut -d" " -f2' _ "$1"; }
ctl_fp() { ctl "$1" fingerprint | awk -v p="$2" '$1 == p && $2 == "ssh-ed25519" { print $3 }'; }

# unlock TARGET PASSPHRASE [KEY]: passphrase piped on stdin, no TTY; sets RC OUT ERR
unlock() {
	cl sh -c 'printf %s "$1" | '"$SSH"' -T -i "$2" -p 2222 root@"$3" cryptroot-unlock' _ "$2" "${3:-$GOOD}" "$1" \
		>"$TMP/out" 2>"$TMP/err"
	RC=$?
	OUT=$(<"$TMP/out")
	ERR=$(<"$TMP/err")
}
expect_run() { # NAME RC STDOUT STDERR
	if [[ $RC == "$2" && $OUT == "$3" && $ERR == "$4" ]]; then pass "$1"; else fail "$1" "rc=$RC stdout=[$OUT] stderr=[$ERR]"; fi
}
ok_line() { echo "cryptsetup: $1 set up successfully"; }
BADPW="cryptsetup: cryptsetup failed, bad password or options?"

sec "bench up"
if ! "${DC[@]}" up -d --build --wait >"$TMP/up.log" 2>&1; then
	cat "$TMP/up.log"
	exit 1
fi

sec "1/5: right passphrase, then boot (target1)"
ctl target1 reset
PRE1=$(keyscan target1 2222)
check "5a port 22 closed in pre-boot" '! port_open target1 22'
unlock target1 "$P"
T0=$(ms)
expect_run "1 right passphrase on stdin without TTY -> prompt on stdout, success on stderr, exit 0" \
	0 "Please unlock disk sda3_crypt" "$(ok_line sda3_crypt)"
check "5b port 2222 stops accepting after success" \
	"cl bash -c 'for i in \$(seq 50); do (</dev/tcp/target1/2222) 2>/dev/null || exit 0; sleep 0.1; done; exit 1'"
check "5c port 22 still closed while booting" '! port_open target1 22'
POST1=$(cl bash -c 'end=$((SECONDS + 9)); while ((SECONDS < end)); do
	k=$(ssh-keyscan -T 2 -t ed25519 -p 22 target1 2>/dev/null) && [ -n "$k" ] && { echo "$k" | cut -d" " -f2-; exit 0; }
	sleep 0.2; done; exit 1')
T1=$(ms)
check "5d port 22 answers within BOOT_DELAY+5 s ($((T1 - T0)) ms)" '[ -n "$POST1" ] && [ $((T1 - T0)) -le 8000 ]'
check "5e post-boot host key differs from Dropbear's" '[ -n "$PRE1" ] && [ "$POST1" != "$PRE1" ]' "pre=[$PRE1] post=[$POST1]"
check "5f status says booted" '[ "$(phase target1)" = booted ]'

sec "2: wrong passphrase, tries (target3)"
ctl target3 reset
unlock target3 "$W"
expect_run "2a wrong passphrase -> bad password line, exit 1" 1 "Please unlock disk sda3_crypt" "$BADPW"
unlock target3 "$W"
expect_run "2b second wrong passphrase -> bad password line, exit 1" 1 "Please unlock disk sda3_crypt" "$BADPW"
unlock target3 "$W"
expect_run "2c third wrong passphrase -> maximum number of tries exceeded, exit 1" \
	1 "Please unlock disk sda3_crypt" "cryptsetup: maximum number of tries exceeded for sda3_crypt"
unlock target3 "$P"
expect_run "2d after tries are used up -> askpass timeout (10 s), exit 1" \
	1 "" "Error: Timeout reached while waiting for askpass."

sec "3: trailing newline (target3)"
ctl target3 reset
unlock target3 "$P"$'\n'
expect_run "3a passphrase + newline -> wrong" 1 "Please unlock disk sda3_crypt" "$BADPW"
unlock target3 "$P"
expect_run "3b next try with the exact passphrase -> success" 0 "Please unlock disk sda3_crypt" "$(ok_line sda3_crypt)"

sec "4: two disks (target2)"
ctl target2 reset
unlock target2 "$P"
expect_run "4a first invocation unlocks sda3_crypt" 0 "Please unlock disk sda3_crypt" "$(ok_line sda3_crypt)"
check "4b still pre-boot with one disk left" '[ "$(phase target2)" = preboot ]'
unlock target2 "$P"
expect_run "4c second invocation unlocks sdb1_crypt" 0 "Please unlock disk sdb1_crypt" "$(ok_line sdb1_crypt)"
unlock target2 "$P"
if [[ $RC == 255 ]]; then
	pass "4d third invocation refused, server booting ($ERR)"
elif [[ $RC == 0 && -z $OUT && -z $ERR ]]; then
	pass "4d third invocation exits 0 silently"
else
	fail "4d third invocation" "rc=$RC stdout=[$OUT] stderr=[$ERR]"
fi

sec "6: not ready yet (target3)"
ctl target3 set NOT_READY_SECONDS=5
T0=$(ms)
unlock target3 "$P"
expect_run "6a within NOT_READY_SECONDS -> Try again later, exit 1" 1 "" "Try again later"
for _ in $(seq 12); do
	sleep 1
	unlock target3 "$P"
	[[ $RC == 1 && $ERR == "Try again later" ]] || break
done
T1=$(ms)
expect_run "6b later the same passphrase succeeds (after $((T1 - T0)) ms)" 0 "Please unlock disk sda3_crypt" "$(ok_line sda3_crypt)"
check "6c not before NOT_READY_SECONDS" '[ $((T1 - T0)) -ge 4500 ]'
ctl target3 clear

sec "7: interactive with TTY (target3)"
ctl target3 reset
cat >"$TMP/t7.exp" <<'EOF'
lassign $argv right wrong
set timeout 20
log_user 0
log_file -a -noappend /tmp/t7.log
spawn {*}[lrange $argv 2 end]
expect -re {Please unlock disk sda3_crypt: $} {} timeout {exit 10} eof {exit 10}
send -- "$wrong\r"
expect "bad password or options?" {} timeout {exit 11} eof {exit 11}
expect -re {Please unlock disk sda3_crypt: $} {} timeout {exit 12} eof {exit 12}
send -- "$right\r"
set ok 0
expect "sda3_crypt set up successfully" {set ok 1; exp_continue} eof {} timeout {exit 13}
if {!$ok} {exit 14}
exit [lindex [wait] 3]
EOF
cl sh -c 'cat >/tmp/t7.exp' <"$TMP/t7.exp"
cl expect /tmp/t7.exp "$P" "$W" $SSH -tt -i "$GOOD" -p 2222 root@target3 cryptroot-unlock
RC=$?
T7=$(cl cat /tmp/t7.log)
check "7a prompt 'Please unlock disk sda3_crypt: ', wrong then right, exit 0 (rc=$RC)" '[ $RC = 0 ]' "$T7"
check "7b no echo of either passphrase" '[[ $T7 != *"$P"* && $T7 != *"$W"* ]]' "$T7"

sec "8: reset and rotate-hostkey (target1)"
FP1=$(ctl_fp target1 preboot)
POSTFP1=$(ctl_fp target1 postboot)
T0=$(ms)
ctl target1 reset
T1=$(ms)
check "8a reset < 2 s ($((T1 - T0)) ms)" '[ $((T1 - T0)) -lt 2000 ]'
ST=$(ctl target1 status)
check "8b status after reset: preboot, nothing unlocked" '[ "$(sed -n 1,2p <<<"$ST" | tr "\n" " ")" = "preboot unlocked: " ]' "$ST"
check "8c port 2222 open, port 22 closed" 'port_open target1 2222 && ! port_open target1 22'
PRE1B=$(keyscan target1 2222)
check "8d same Dropbear host key after reset" '[ -n "$PRE1B" ] && [ "$PRE1B" = "$PRE1" ]'
check "8e bench-ctl fingerprint matches the scanned key" '[ "$(fp_of "$PRE1B")" = "$FP1" ]' "ctl=$FP1"
ctl target1 rotate-hostkey
PRE1C=$(keyscan target1 2222)
FP2=$(ctl_fp target1 preboot)
check "8f rotate-hostkey serves a new key" '[ -n "$PRE1C" ] && [ "$PRE1C" != "$PRE1" ]'
check "8g fingerprint follows rotation" '[ "$FP2" != "$FP1" ] && [ "$(fp_of "$PRE1C")" = "$FP2" ]'
check "8h post-boot key unchanged by rotation" '[ "$(ctl_fp target1 postboot)" = "$POSTFP1" ]'

sec "9: authentication (target1)"
unlock target1 "$P" "$BAD"
check "9a unauthorized key rejected" '[ $RC = 255 ] && [[ $ERR == *"Permission denied (publickey)"* ]]' "rc=$RC stderr=[$ERR]"
cl $SSH -T -o PubkeyAuthentication=no -o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes \
	-p 2222 root@target1 true >/dev/null 2>"$TMP/err"
ERR=$(tr -d '\r' <"$TMP/err")
check "9b only publickey offered, no password" '[[ $ERR == *"Permission denied (publickey)." ]]' "stderr=[$ERR]"
ST=$(ctl target1 status)
check "9c no unlock attempt was made" 'grep -qx "tries: sda3_crypt=0/3" <<<"$ST"' "$ST"

sec "extra: DISK_PASSPHRASES, PREBOOT_DELAY, authorize"
ctl target2 set "DISK_PASSPHRASES=sdb1_crypt=$P2"
unlock target2 "$P"
expect_run "10a default passphrase opens sda3_crypt" 0 "Please unlock disk sda3_crypt" "$(ok_line sda3_crypt)"
unlock target2 "$P"
expect_run "10b default passphrase is wrong for sdb1_crypt" 1 "Please unlock disk sdb1_crypt" "$BADPW"
unlock target2 "$P2"
expect_run "10c per-disk passphrase opens sdb1_crypt" 0 "Please unlock disk sdb1_crypt" "$(ok_line sdb1_crypt)"
ctl target2 clear

ctl target3 set PREBOOT_DELAY=3
T0=$(ms)
check "11a port 2222 closed during PREBOOT_DELAY" '! port_open target3 2222'
check "11b port 2222 opens after PREBOOT_DELAY" \
	"cl bash -c 'for i in \$(seq 60); do (</dev/tcp/target3/2222) 2>/dev/null && exit 0; sleep 0.1; done; exit 1'"
T1=$(ms)
check "11c not before PREBOOT_DELAY ($((T1 - T0)) ms)" '[ $((T1 - T0)) -ge 2500 ]'
ctl target3 clear

ctl target1 authorize <fixtures/id_ed25519_wrong.pub
unlock target1 "$W" "$BAD"
expect_run "12a authorize lets a new key log in" 1 "Please unlock disk sda3_crypt" "$BADPW"
ctl target1 clear
unlock target1 "$W" "$BAD"
check "12b clear removes it again" '[ $RC = 255 ]' "rc=$RC stderr=[$ERR]"

echo
if [ "$FAILS" -eq 0 ]; then echo "ALL PASS"; else echo "$FAILS FAILED"; fi
[ "$FAILS" -eq 0 ]
