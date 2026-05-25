#ifndef IPC_H
#define IPC_H

#if defined(__linux__) && !defined(_GNU_SOURCE)
    #define _GNU_SOURCE
#endif

#include <QByteArray>
#include <QDebug>
#include <QLocalSocket>
#include <QObject>
#include <QString>

#include "../client/core/utils/utilities.h"

#ifdef Q_OS_LINUX
    #include <sys/socket.h>
    #include <sys/types.h>
    #include <unistd.h>
#endif

#define IPC_SERVICE_URL "local:AmneziaVpnIpcInterface"

namespace amnezia {

enum PermittedProcess {
    Invalid,
    OpenVPN,
    Wireguard,
    Tun2Socks,
    CertUtil
};

inline QString permittedProcessPath(PermittedProcess pid)
{
    switch (pid) {
        case PermittedProcess::OpenVPN:
            return Utils::openVpnExecPath();
        case PermittedProcess::Wireguard:
            return Utils::wireguardExecPath();
        case PermittedProcess::CertUtil:
            return Utils::certUtilPath();
        case PermittedProcess::Tun2Socks:
            return Utils::tun2socksPath();
        default:
            return "";
    }
}


inline QString getIpcServiceUrl() {
#ifdef Q_OS_WIN
    return IPC_SERVICE_URL;
#else
    return QString("/tmp/%1").arg(IPC_SERVICE_URL);
#endif
}

inline QString getIpcProcessUrl(int pid) {
#ifdef Q_OS_WIN
    return QString("%1_%2").arg(IPC_SERVICE_URL).arg(pid);
#else
    return QString("/tmp/%1_%2").arg(IPC_SERVICE_URL).arg(pid);
#endif
}

inline bool authorizeLocalIpcSocket(QLocalSocket *socket, const char *scope)
{
    if (!socket) {
        qWarning() << "Rejected null IPC socket for" << scope;
        return false;
    }

    const QByteArray allowedUid = qgetenv("AMNEZIAVPN_IPC_AUTH_UID");
    if (allowedUid.isEmpty()) {
        return true;
    }

#ifdef Q_OS_LINUX
    bool ok = false;
    const qulonglong expectedUid = allowedUid.toULongLong(&ok);
    if (!ok) {
        qWarning() << "Rejected IPC socket for" << scope << "because AMNEZIAVPN_IPC_AUTH_UID is invalid";
        return false;
    }

    const qintptr descriptor = socket->socketDescriptor();
    if (descriptor < 0) {
        qWarning() << "Rejected IPC socket for" << scope << "because peer credentials are unavailable";
        return false;
    }

    struct ucred credentials {};
    socklen_t length = sizeof(credentials);
    if (::getsockopt(static_cast<int>(descriptor), SOL_SOCKET, SO_PEERCRED, &credentials, &length) != 0) {
        qWarning() << "Rejected IPC socket for" << scope << "because SO_PEERCRED failed";
        return false;
    }

    if (static_cast<qulonglong>(credentials.uid) != expectedUid) {
        qWarning() << "Rejected IPC socket for" << scope << "from uid" << credentials.uid;
        return false;
    }

    return true;
#else
    qWarning() << "Rejected IPC socket for" << scope << "because AMNEZIAVPN_IPC_AUTH_UID is only supported on Linux";
    return false;
#endif
}

inline QStringList sanitizeArguments(PermittedProcess proc, const QStringList &args) {
    using Validator = std::function<bool(const QString&)>;
    QMap<QString, Validator> namedArgs;
    QList<Validator> positionalArgs;

    switch (proc) {
    case Tun2Socks:
        namedArgs["-device"] = [](const QString& v) { return v.startsWith("tun://"); };
        namedArgs["-proxy"] = [](const QString& v) { return v.startsWith("socks5://"); };
        break;
    default:
        //FIXME
        return args;
    }


    QStringList sanitized;

    for (int i = 0, pos = 0; i < args.size(); i++) {
        const auto& key = args[i];

        if (const auto found = namedArgs.find(key); found != namedArgs.end()) {
            const auto validator = found.value();

            if (validator) {
                if (i + 1 < args.size()) {
                    const auto& value = args[i+1];
                    if (validator(value)) {
                        sanitized << key << value;
                        i++;
                    }
                }
            } else {
                sanitized << key;
            }
        } else if (pos < positionalArgs.size()) {
            if (const auto validator = positionalArgs[pos]; validator && validator(key)) {
                sanitized << key;
                pos++;
            }
        }
    }

    return sanitized;
}

} // namespace amnezia

#endif // IPC_H
