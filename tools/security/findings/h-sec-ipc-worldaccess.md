# H-SEC: IPC world-access blocker

Status: covered by owned-repo PR #119.

Inspected on: 2026-05-26T12:24Z

Finding: `h-sec-ipc-worldaccess`

Owned PR:
- Repo: `amnezia-vpn-community/AmneziaVPN`
- PR: #119 `Harden privileged IPC QtRO socket handoff`
- URL: https://github.com/amnezia-vpn-community/AmneziaVPN/pull/119
- Branch: `akatosh/h006-ipc-worldaccess-static-guard`
- Base: `dev`
- State: open, clean, not draft

Evidence:
- `ipc/ipc.h` adds `authorizeLocalIpcSocket(...)`.
- On Linux, missing `AMNEZIAVPN_IPC_AUTH_UID`, invalid UID, unavailable peer credentials, `SO_PEERCRED` failure, or UID mismatch all return `false`.
- `service/server/localserver.cpp`, `ipc/ipcserver.cpp`, and `client/daemon/daemonlocalserver.cpp` call `authorizeLocalIpcSocket(...)` before handing sockets to QtRO or daemon connection handling.
- `deploy/data/linux/AmneziaVPN.service` loads `/etc/AmneziaVPN/ipc-auth.env`.
- `deploy/data/linux/post_install.sh` resolves a non-root installer/user UID and refuses to start the service if it cannot provision `AMNEZIAVPN_IPC_AUTH_UID`.
- `.github/workflows/security-static.yml` runs `tools/security/check_ipc_auth_gate.py`.

Checked gates:
- Local static gate: `python3 tools/security/check_ipc_auth_gate.py` -> `rc=0`, `IPC auth gate static checks passed`.
- GitHub PR #119 checks all passing at inspection time:
  - Host Isolation Check / Check workflow runner isolation
  - Security Static Checks / IPC auth gate
  - L1 Sanity Tests: 4.8.14.5, 4.8.15.0, 4.8.15.4
  - L2 Integration Tests / l2-integration
  - L2 OpenVPN Integration Tests

Next allowed gate:
- Merge PR #119 only after final owned-repo review confirms the Linux installer UID selection is acceptable for supported install paths.
- Do not run AmneziaVPN, VPN tunnels, SSH/firewall/network probes, or product binaries on the OpenClaw host.

Safety:
- Static inspection only.
- No VPN/product binaries were run.
- No SSH, firewall, network stack, or secrets were touched.
- No upstream PR was opened.
- No external message was sent.
