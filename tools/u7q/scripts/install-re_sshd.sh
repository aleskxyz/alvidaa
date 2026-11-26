#!/usr/bin/env bash
# Deploy the canonical 09.09O re_sshd service over root SSH (superwatch 54/53).
#
# Source: docs/models/55A7KAU/V0000.09.09O.P1015/source/re_sshd/
#   TV_HOST=<tv-ip> TV_PORT=8008 ./tools/u7q/scripts/install-re_sshd.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/../.." && pwd)"
SSHD_SRC="$REPO/docs/models/55A7KAU/V0000.09.09O.P1015/source/re_sshd"
TV="${TV_HOST:?set TV_HOST}"
PORT="${TV_PORT:-8008}"
KEY="${TV_KEY:-$REPO/server/keys/tv_root_ed25519}"
BASE=/APPS/pkgs/tv.vidaa.jsservice.basic/CHA/services
SSH=(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$PORT" -i "$KEY" "root@$TV")

test -f "$SSHD_SRC/index.js" || { echo "missing $SSHD_SRC (canonical 09.09O re_sshd)" >&2; exit 1; }

echo "== backing up serviceList.json =="
"${SSH[@]}" "export PATH=/bin:/usr/bin:/sbin:/usr/sbin; mkdir -p /var/local/alvidaa/re_sshd-backup /APPS/.re_sshd; test -f /var/local/alvidaa/re_sshd-backup/serviceList.json.pristine || cp -p $BASE/serviceList.json /var/local/alvidaa/re_sshd-backup/serviceList.json.pristine; touch /APPS/.re_sshd/boot_marker.txt; chown 314:314 /APPS/.re_sshd/boot_marker.txt"

echo "== uploading re_sshd service =="
"${SSH[@]}" "export PATH=/bin:/usr/bin:/sbin:/usr/sbin; mkdir -p $BASE/re_sshd"
for name in index.js package.json; do
  "${SSH[@]}" "cat > $BASE/re_sshd/$name" < "$SSHD_SRC/$name"
done

echo "== merging serviceList.json =="
CUR="$("${SSH[@]}" "cat $BASE/serviceList.json")"
node -e "
const cur=JSON.parse(process.argv[1]);
const frag={id:'re_sshd',autoStart:true,isKeepAlive:false};
if(!cur.find(e=>e.id==='re_sshd')) cur.push(frag);
process.stdout.write(JSON.stringify(cur,null,4)+'\n');
" "$CUR" > /tmp/serviceList-merged.json

"${SSH[@]}" "cat > $BASE/serviceList.json" < /tmp/serviceList-merged.json
rm -f /tmp/serviceList-merged.json

echo "== fixing ownership =="
"${SSH[@]}" "export PATH=/bin:/usr/bin:/sbin:/usr/sbin; chown -R 314:314 $BASE/re_sshd; chmod 640 $BASE/re_sshd/*.json $BASE/re_sshd/*.js; chmod 755 $BASE/re_sshd; chown 314:314 $BASE/serviceList.json; chmod 640 $BASE/serviceList.json"

echo "== verify =="
"${SSH[@]}" "export PATH=/bin:/usr/bin:/sbin:/usr/sbin; grep re_sshd $BASE/serviceList.json; ls -ln $BASE/re_sshd; test -f /APPS/installer.ipk && echo installer.ipk ok"

echo "Done. re_sshd autostarts on next cold boot (~30s until 8008 is up)."