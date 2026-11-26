#!/bin/sh
# 75U7KQ / V0000.09.09O.P0930 — same CHB operationui lane as 65a85qevs.
# STOCK_MD5 pinned from owner unit 2026-11-25.
#
# MODES:
#   status    print the current bundle hash and engine pid; changes nothing
#   dry       stock-only restart; no file or cache changes (the gate)
#   install   atomic launcher swap + JS-cache reset, then restart
#   switch    swap candidate when native home is already installed
#   rollback  restore stock app.js + JS-cache, then restart
PATH=/basic/bin:/bin:/usr/bin:/sbin:/usr/sbin
export PATH
trap "" HUP

MODE="${1:-status}"
DIR=/var/local/alvidaa
APP=/APPS/pkgs/tv.vidaa.app.operationui/CHB/apps/launcher/js/app.js
CACHE=/var/local/hisenseUI/cobalt_home/.cache/cobalt
BACKUP=$DIR/backup
CANDIDATE=$DIR/candidate-native-home.js
ENVF=$DIR/systemui.env
LOG=$DIR/switch.log
DONE=$DIR/switch.done
STOCK_MD5=8131f9a4ac93a001c27bbdf6c6e7b395
CANDIDATE_MD5=$(/bin/cat "$DIR/candidate.md5" 2>/dev/null)

log() { printf '%s\n' "$*" >> "$LOG"; }
fail() { log "FAIL $*"; printf '%s\n' "FAIL $*" > "$DONE"; exit 1; }
md5of() { /bin/md5sum "$1" | /bin/sed 's/[^0-9a-f].*//'; }

live_systemui() {
  out=""
  for p in $(/bin/pidof SystemUI); do
    st=$(/bin/grep '^State:' "/proc/$p/status" 2>/dev/null)
    case "$st" in *Z*) ;; *) out="$out $p" ;; esac
  done
  set -- $out
  printf '%s\n' "$*"
}

if [ "$MODE" = status ]; then
  printf 'app.js md5 %s\n' "$(md5of "$APP")"
  printf 'stock md5  %s\n' "$STOCK_MD5"
  printf 'engine pid %s\n' "$(live_systemui)"
  printf 'phase      %s\n' "$(/bin/cat "$DIR/phase" 2>/dev/null || echo unknown)"
  exit 0
fi

/bin/rm -f "$DONE"
log "=== switch-home mode=$MODE ==="

case "$MODE" in
  dry)
    [ "$(md5of "$APP")" = "$STOCK_MD5" ] || fail "dry run requires stock app.js"
    ;;
  install)
    [ "$(md5of "$APP")" = "$STOCK_MD5" ] || fail "install requires stock app.js"
    [ "$(md5of "$CANDIDATE")" = "$CANDIDATE_MD5" ] || fail "candidate hash mismatch"
    [ -f "$BACKUP/app.js.stock" ] || fail "stock backup missing"
    [ ! -e "$BACKUP/compiled_js" ] || fail "cache backup already present"
    ;;
  switch)
    [ "$(md5of "$CANDIDATE")" = "$CANDIDATE_MD5" ] || fail "candidate hash mismatch"
    [ -f "$BACKUP/app.js.stock" ] || fail "stock backup missing"
    [ -d "$BACKUP/compiled_js" ] || fail "no stock cache backup; run install first"
    ;;
  rollback)
    [ -f "$BACKUP/app.js.stock" ] || fail "stock backup missing"
    ;;
  *) fail "unknown mode: $MODE" ;;
esac

old=$(live_systemui)
set -- $old
old=$1
[ -n "$old" ] && [ -r "/proc/$old/environ" ] || fail "no live SystemUI to capture"

creds_before=$(/bin/grep -E '^(Uid|Gid|Groups|CapEff):' "/proc/$old/status")
/bin/cat "/proc/$old/environ" > "$ENVF" || fail "cannot capture SystemUI env"
printf '\0' >> "$ENVF"
log "captured env from pid=$old"

/bin/kill -TERM "$old" 2>/dev/null

i=0
while [ "$i" -lt 20 ]; do
  [ -z "$(live_systemui)" ] && [ -z "$(/bin/pidof SystemUI)" ] && break
  /bin/sleep 1
  i=$((i + 1))
done
if [ -n "$(/bin/pidof SystemUI)" ]; then
  fail "SIGTERM did not clear SystemUI; refusing to launch a second engine"
fi
log "SystemUI stopped (wait ${i}s)"

if [ "$MODE" = install ] || [ "$MODE" = switch ]; then
  tmp="$APP.alvidaa-tmp"
  /bin/cp "$CANDIDATE" "$tmp" || fail "cannot stage candidate"
  /bin/chown 305:909 "$tmp" || fail "cannot set owner 305:909"
  /bin/chmod 0640 "$tmp" || fail "cannot set mode 0640"
  /bin/mv -f "$tmp" "$APP" || fail "cannot install candidate"
  for d in compiled_js uncompiled_js; do
    if [ "$MODE" = install ]; then
      /bin/mv "$CACHE/$d" "$BACKUP/$d" || fail "cannot back up $d"
    else
      /bin/rm -rf "$CACHE/$d" || fail "cannot clear $d"
    fi
    /bin/mkdir "$CACHE/$d" || fail "cannot recreate $d"
    /bin/chown 311:311 "$CACHE/$d" || fail "cannot own $d"
    /bin/chmod 0751 "$CACHE/$d" || fail "cannot chmod $d"
  done
  log "$MODE complete; JS cache dirs reset (originals in $BACKUP)"
elif [ "$MODE" = rollback ]; then
  tmp="$APP.alvidaa-tmp"
  /bin/cp -p "$BACKUP/app.js.stock" "$tmp" || fail "cannot stage stock app.js"
  /bin/chown 305:909 "$tmp" || fail "cannot set owner 305:909"
  /bin/chmod 0640 "$tmp" || fail "cannot set mode 0640"
  /bin/mv -f "$tmp" "$APP" || fail "cannot restore stock app.js"
  for d in compiled_js uncompiled_js; do
    if [ -d "$BACKUP/$d" ]; then
      /bin/rm -rf "$CACHE/$d" || fail "cannot clear $d"
      /bin/mv "$BACKUP/$d" "$CACHE/$d" || fail "cannot restore $d"
    else
      log "WARN no backup for $d; leaving regenerated cache"
    fi
  done
  log "restored stock app.js and JS cache dirs"
fi

respawned=$(live_systemui)
if [ -n "$respawned" ]; then
  log "INFO SystemUI respawned without our launch: $respawned"
else
  (
    cd /opt/hisenseUI || exit 1
    while IFS= read -r -d '' item; do
      case "$item" in *=*) export "$item" ;; esac
    done < "$ENVF"
    trap "" HUP
    exec /usr/local/bin/secure_exec SystemUI /opt/hisenseUI/startgui.sh \
      >/dev/null 2>&1 </dev/null
  ) >/dev/null 2>&1 </dev/null &
  log "launched secure_exec SystemUI (bg pid $!)"
fi

i=0
new=""
while [ "$i" -lt 40 ]; do
  new=$(live_systemui)
  [ -n "$new" ] && [ "$new" != "$old" ] && break
  /bin/sleep 1
  i=$((i + 1))
done
set -- $new
new=$1
[ -n "$new" ] || fail "SystemUI did not start within ${i}s; rshell stays up, retry launch manually"

printf '%s\n' -1000 > "/proc/$new/oom_score_adj" 2>/dev/null || true
creds_after=$(/bin/grep -E '^(Uid|Gid|Groups|CapEff):' "/proc/$new/status")
[ "$creds_after" = "$creds_before" ] || log "WARN restarted credentials differ"
ppid=$(/bin/grep '^PPid:' "/proc/$new/status" | /bin/sed 's/[^0-9]*//g')
log "OK mode=$MODE old=$old new=$new ppid=$ppid wait=${i}s"
log "app.js md5 now $(md5of "$APP")"
printf '%s\n' "OK mode=$MODE new=$new" > "$DONE"