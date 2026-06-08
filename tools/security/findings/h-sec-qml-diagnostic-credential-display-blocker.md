# h-sec-qml-diagnostic-credential-display blocker

Status: duplicate owned-repo fix already exists locally.

Inspected on: 2026-05-25T15:53Z

Finding: `h-sec-qml-diagnostic-credential-display`

Current checkout:
- Branch: `akatosh/h006-ipc-worldaccess-static-guard`
- This branch is for a different security finding, so applying another QML credential-display patch here would mix unrelated work.

Existing owned-repo fix branch:
- `akatosh/h-sec-qml-diagnostic-credential-display-20260522`
- `origin/akatosh/h-sec-qml-diagnostic-credential-display-20260522`
- Tip: `ef37c4da33a90c2998b847782a5912f7320ac297`
- Subject: `security: harden native config display redaction`

Exact local proof:
- `git branch -a --list '*h-sec-qml*'` shows both local and origin refs for the fix branch.
- `git show --name-only --format='%H%n%s' akatosh/h-sec-qml-diagnostic-credential-display-20260522 --` shows tip `ef37c4da33a90c2998b847782a5912f7320ac297`, subject `security: harden native config display redaction`, and changed paths:
  - `client/ui/controllers/importUiController.cpp`
  - `client/ui/models/protocolsModel.cpp`
- `git show akatosh/h-sec-qml-diagnostic-credential-display-20260522:client/ui/controllers/importUiController.cpp | rg -n 'redact|sensitive|PRIVATE|password|vpn://|escape|malicious|config' -C 2` confirms display redaction helpers and `getConfig()` returning `redactConfigForDisplay(m_config)`.
- `git show akatosh/h-sec-qml-diagnostic-credential-display-20260522:client/ui/models/protocolsModel.cpp | rg -n 'redact|sensitive|PRIVATE|PrivateKey|password|config' -C 2` confirms native config display redaction and `getRawConfig()` returning `redactNativeConfigForDisplay(...)`.
- Prior governance artifacts also mark this exact finding duplicate of owned-repo PR #111:
  - `/root/.openclaw/workspace/memory/security/h-sec-qml-diagnostic-credential-display-duplicate-pr111-20260524T2356Z.md`
  - `/root/.openclaw/workspace/memory/security/h-sec-qml-diagnostic-credential-display-duplicate-pr111-20260525T0616Z.md`

Decision:
- No source patch was prepared in the current checkout because the smallest safe action is to avoid duplicating an already-owned fix branch and avoid cross-contaminating the active IPC security branch.

Safety:
- Static inspection only.
- No VPN/product binaries were run.
- No SSH, firewall, network stack, or secrets were touched.
- No upstream PR was opened.
- No external message was sent.
- No Claude/Anthropic tooling was used.
