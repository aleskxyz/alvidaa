# 75U7KQ / V0000.09.09O.P0930 — root + boot-persistent native Home (MTK9618, U09.09)

**Status:** root via `fetcher` → superwatch **54/53** → IPK `postinst` (uid 0),
key-only Dropbear on **:8008** (`/bin/sh` login shell). Boot persistence via
canonical **`re_sshd`** — cold boot to SSH ~20s, re-verified 2026-11-26. Lane 3
**`free-my-tv-09o`** on CHB `operation-ui` owner-verified; rollback → reinstall
cycle confirmed the same day. Lane 1 **pairing** verified 2026-11-26
(`transport_protocol=3290`, modern profile). Lane 2 (on-TV bridge) not
exercised.

> **Applies to retail `75U7KQ` (internal platform `75U63KAVS`, serial type
> `75U6KX`; SoC MTK9618 / mt5879, aarch64 kernel + armhf userland; VIDAA `U09.09`;
> region `EU_A`, country `CZE`) on firmware `V0000.09.09O.P0930`.** Fingerprint
> read from `/hidata/critical/config/critical.ini` and `/APPS/ModelInfo.ini`
> (2026-11-26). Shares this firmware pin with
> [65E86GEVS](../../65E86GEVS/V0000.09.09O.P0930/README.md) (different root
> subclass; `EM_B`, serial type `65E8GE`). `transport_protocol=3290` (SSDP blob on
> `:18400/MediaServer/rendererdevicedesc.xml`; `:3366/dd.xml` is a stub).

> **Contributed by [@aleskxyz](https://github.com/aleskxyz).** Own-device
> material, 2026-11-25/26. Compatibility row:
> [inventory.json](../../../research/inventory.json) (`tested_by` `gh:aleskxyz`
> on `V0000.09.09O.P0930`).

## What the chain rests on

1. **Fetcher write without browser fileWrite gate.** `basic/fetcher` `fetchFile`
   stages files into writable package trees as uid 314 — the browser-installer
   path used here, same family as other MTK9618 U09.x units.
2. **Superwatch install IDs differ from 09.60/09.62 on this branch.** On this
   unit **53/54** install/uninstall work; **82/83** return invalid (604). Same
   id pair as [55E7QTUK](../../55E7QTUK/V0000.09.09D.P1001/README.md) U09.09D.
3. **Vendor IPK postinst runs as root.** Opkg-driven install executes the
   package postinst with uid 0 and full CapEff — drops patched static Dropbear
   on **:8008** when built for mtk9618 armhf.
4. **Persistence is serviceList + BaseService, not SUID.** Canonical
   `re_sshd` (from [55A7KAU findings/02](../../55A7KAU/V0000.09.09O.P1015/findings/02-root-ssh.md))
   autostarts and re-arms the IPK via superwatch after cold boot.
5. **Writable CHB operation-ui.** Native Home is a `route[0].component` swap in
   `/APPS/pkgs/tv.vidaa.app.operationui/CHB/apps/launcher/js/app.js`; app list
   uses **`getCurrentShowApps("Launcher")`**, not `getAppList` (do not use the
   75U8QTUK lane-3 adapter on this build).
6. **Different root subclass on the same firmware id.** [65E86GEVS](../../65E86GEVS/V0000.09.09O.P0930/README.md)
   on this pin uses superwatch restore injection — unrelated to this chain.

## What was measured

| Claim | Evidence | Source |
| --- | --- | --- |
| Firmware `V0000.09.09O.P0930`, retail 75U7KQ | verified | SSH / config reads 2026-11-26 |
| `transport_protocol=3290` | verified | SSDP on `:18400/.../rendererdevicedesc.xml` |
| Fetcher staged installer payload | verified | ret:true `download finished` (uid 314) |
| Superwatch **54** then **53** → root postinst | verified | postinst uid 0, Dropbear :8008 |
| Superwatch **83/82** on this unit | verified | 604 invalid (not used) |
| `re_sshd` cold boot | verified | SSH ~20s after power-on, no browser re-arm |
| Lane 3 **free-my-tv-09o** | verified | On-screen apps; marker `ALVIDAA_FREE_MY_TV_NATIVE_09O_V1` |
| Lane 3 install / switch / rollback | verified | `switch.log` OK; stock md5 restore |
| Lane 1 pairing (modern cert profile) | verified | `pair.py` PIN → broker :36669, MQTT applist |
| Lane 2 on-TV bridge | untested | not attempted |

## What this guide includes and leaves out

| Included | Left out |
| --- | --- |
| Fingerprint, firmware constants, superwatch id pairing | IPK binary, Dropbear binary, signing keys |
| Architecture of fetcher → superwatch → postinst → re_sshd | Exact shell one-liners inside postinst |
| Lane-3 variant choice (`free-my-tv-09o`) and CHB path | Pinned stock `app.js` blob (private `firmware/75u7kq/`) |
| Teardown paths for root SSH and native Home | Pairing certificates and tokens |
| Evidence table with verification labels | Vendor operation-ui bundles |

This guide follows [DISCLOSURE.md](../../../DISCLOSURE.md): method and
reversibility are published; executables and credentials stay on the owner's
machine.

## Lane 3 — Free My TV

Use variant **`free-my-tv-09o`**, not `free-my-tv-75u8qtuk`.

```sh
node tools/launcher-host/native-install.cjs install free-my-tv-09o \
  --model 75u7kq --host <tv-ip> --port 8008 --no-watcher
```

Model profile: `tools/launcher-host/models.json` (`75u7kq`). Switch script:
`switch-home-75u7kq.sh` (`status` / `install` / `switch` / `rollback`).

## Root SSH

Build Dropbear with **`tools/u7q/scripts/build_dropbear_a7k.sh`** (`/bin/sh`
login shell). Serve **`tools/u7q/web/install-u909.html`** (superwatch 53/54) from
`tools/u7q/web/server.py`. After a reboot **without** `re_sshd`, re-arm with
**`trigger-u909.html`**, not `trigger.html` (82/83 return 604). Boot persistence:

```sh
TV_HOST=<tv-ip> TV_PORT=8008 tools/u7q/scripts/install-re_sshd.sh
```

Deploys canonical `re_sshd` as documented in
[55A7KAU findings/02](../../55A7KAU/V0000.09.09O.P1015/findings/02-root-ssh.md).

## Teardown

**Native Home (lane 3):**

```sh
node tools/launcher-host/native-install.cjs rollback --model 75u7kq \
  --host <tv-ip> --port 8008 --no-watcher
```

Restores pinned stock `app.js` and clears the operation-ui JS cache via the
switch script.

**Root SSH + `re_sshd`:** Remove the installed IPK via superwatch uninstall id
**54**, delete `/APPS/.re_sshd/` (or package artefacts your install left),
remove `re_sshd` from `tv.vidaa.jsservice.basic/CHA/services/`, restore
`serviceList.json` from
`/var/local/alvidaa/re_sshd-backup/serviceList.json.pristine` (if the install
script kept one), reboot. Kill Dropbear on `:8008` if it is still listening.
Residual: files under `/var/local/alvidaa/` until manually deleted.

**Pairing:** Revoke or ignore `tokens.json` on the host; no TV-side change
required for day-to-day use.

## Open items

- Full findings tree (numbered files) — this README is the only guide file so far.
- Lane 2 (`alvidaa-bridge` on loopback) not attempted on this model.
- Lane 1 home watcher as default home not pursued (native Home is the daily UI).
- Whether every other retail name on this firmware pin matches CHB + 53/54 ids.

## Cross-reference

- [65E86GEVS operation-ui (static)](../../65E86GEVS/V0000.09.09O.P0930/findings/03-operationui-launcher.md)
- [55A7KAU root SSH / superwatch 53/54](../../55A7KAU/V0000.09.09O.P1015/findings/02-root-ssh.md)
- [Method catalogue](../../../research/EXPLOITS.md)
- [Publication policy](../../../DISCLOSURE.md)