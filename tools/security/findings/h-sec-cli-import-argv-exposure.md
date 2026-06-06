# H-SEC: CLI import argv exposure

Status: resolved in owned-repo history by `507a2b6c` (`Redact import and process argument logging (#105)`) with a 2026-06-06 source follow-up that keeps the safe import branch independent from the legacy argv option value.

Finding: passing profile data through `AmneziaVPN --import <data>` exposes that data to process-list readers because argv is OS-visible.

Evidence checked:
- `client/amneziaApplication.cpp` now exposes `--import-file <path>` and reads profile bytes with `QFile` instead of requiring plaintext config data in argv.
- `client/amneziaApplication.cpp` also exposes `--import-stdin` and reads profile bytes from standard input.
- The legacy `--import <data>` path is blocked before import processing and exits with a warning that the value is visible in process arguments.
- The active import branch initializes `data` empty and fills it only from `--import-file` or `--import-stdin`; it does not read `m_parser.value(m_optImport)`.
- `ipc/ipcserverprocess.cpp` logs only the privileged child process argument count, not full argument values.

Residual risk:
- `--import <data>` remains registered for compatibility and diagnostics, so a caller can still place secrets in argv before the process starts. The client now refuses to consume that data and directs callers to `--import-file` or `--import-stdin`; fully removing the option would be a compatibility-breaking product decision.

Validation commands:
```bash
git show --stat --oneline 507a2b6c
rg -n -- "import-file|import-stdin|process arguments|m_parser\\.value\\(m_optImport\\)|argumentCount|arguments\\(\\)" client/amneziaApplication.cpp client/amneziaApplication.h ipc/ipcserverprocess.cpp
git diff -- client/amneziaApplication.cpp client/amneziaApplication.h ipc/ipcserverprocess.cpp
```
