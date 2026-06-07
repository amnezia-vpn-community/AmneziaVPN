#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
IMPORT_UI = ROOT / "client/ui/controllers/importUiController.cpp"
PROTOCOLS_MODEL = ROOT / "client/ui/models/protocolsModel.cpp"
SERVER_INFO_QML = ROOT / "client/ui/qml/Pages2/PageSettingsServerInfo.qml"
SUBSCRIPTION_KEY_QML = ROOT / "client/ui/qml/Pages2/PageSettingsApiSubscriptionKey.qml"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require(errors: list[str], condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def function_body(text: str, signature: str) -> str | None:
    match = re.search(signature + r"\s*\{", text)
    if match is None:
        return None

    depth = 0
    for index in range(match.end() - 1, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[match.end():index]

    return None


def main() -> int:
    errors: list[str] = []

    import_ui = read(IMPORT_UI)
    protocols_model = read(PROTOCOLS_MODEL)
    server_info_qml = read(SERVER_INFO_QML)
    subscription_key_qml = read(SUBSCRIPTION_KEY_QML)

    import_get_config = function_body(import_ui, r"QString\s+ImportUiController::getConfig\s*\(\s*\)")
    require(errors, import_get_config is not None, "ImportUiController::getConfig is missing")
    require(
        errors,
        import_get_config is not None and "redactConfigForDisplay(m_config)" in import_get_config,
        "ImportUiController::getConfig must redact imported config before exposing QML preview text",
    )
    for marker in (
        "vpn://",
        "PRIVATE KEY",
        "auth-user-pass",
        "tls-auth",
        "presharedkey",
        "authtoken",
        "secret",
        "token",
    ):
        require(errors, marker in import_ui, f"import preview redaction is missing marker: {marker}")

    protocol_get_raw_config = function_body(protocols_model, r"QString\s+ProtocolsModel::getRawConfig\s*\(\s*\)\s*const")
    require(errors, protocol_get_raw_config is not None, "ProtocolsModel::getRawConfig is missing")
    require(
        errors,
        protocol_get_raw_config is not None and "redactNativeConfigForDisplay(" in protocol_get_raw_config,
        "ProtocolsModel::getRawConfig must redact native config before returning RawConfigRole",
    )
    for marker in ("PrivateKey", "PresharedKey", "auth-token", "auth-user-pass", "tls-auth"):
        require(errors, marker in protocols_model, f"rawConfig redaction is missing marker: {marker}")

    header_match = re.search(
        r"HeaderTypeWithButton\s*\{[\s\S]*?descriptionText:\s*\{(?P<body>[\s\S]*?)\n\s*\}\n\s*\n\s*actionButtonFunction:",
        server_info_qml,
    )
    if header_match is None:
        errors.append("PageSettingsServerInfo.qml: could not find header descriptionText block")
    else:
        header_body = header_match.group("body")
        require(
            errors,
            "credentialsLogin" not in header_body and "secretData" not in header_body,
            "PageSettingsServerInfo header must not display credential login or secret data",
        )
        require(
            errors,
            "root.processedServer.hostName" in header_body,
            "PageSettingsServerInfo header should display hostName for non-API self-hosted servers",
        )

    processed_server_changed = re.search(
        r"function\s+onProcessedServerChanged\s*\(\s*\)\s*\{(?P<body>[\s\S]*?)\n\s*\}",
        subscription_key_qml,
    )
    if processed_server_changed is None:
        errors.append("PageSettingsApiSubscriptionKey.qml: missing onProcessedServerChanged handler")
    else:
        require(
            errors,
            "root.showQrCode = false" in processed_server_changed.group("body"),
            "subscription QR reveal state must reset when processed server changes",
        )

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1

    print("QML diagnostic credential redaction static checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
