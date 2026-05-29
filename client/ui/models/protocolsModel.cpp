#include "protocolsModel.h"

#include "core/utils/protocolEnum.h"
#include "core/protocols/protocolUtils.h"
#include "core/utils/constants/configKeys.h"
#include "core/utils/constants/protocolConstants.h"
#include "core/utils/containerEnum.h"
#include "core/utils/containers/containerUtils.h"
#include "core/models/protocols/awgProtocolConfig.h"
#include "core/models/protocols/wireGuardProtocolConfig.h"
#include "core/models/protocols/openVpnProtocolConfig.h"
#include "core/models/protocols/xrayProtocolConfig.h"

#include <QRegularExpression>
#include <QStringList>

using namespace ProtocolUtils;

namespace
{
bool isSensitiveInlineConfigLine(const QString &line)
{
    static const QRegularExpression sensitiveOptionPattern(
            QStringLiteral(R"(^\s*(PrivateKey|PresharedKey|PreSharedKey|client_priv_key|server_priv_key|psk_key|password|api_key|vpn_key|auth-token|auth_token)\s*(:|=|\s+).*)"),
            QRegularExpression::CaseInsensitiveOption);

    return sensitiveOptionPattern.match(line).hasMatch();
}

QString redactNativeConfigForDisplay(QString configString)
{
    static const QRegularExpression sensitiveBlockStartPattern(
            QStringLiteral(R"(^\s*<(key|tls-auth|auth-user-pass)>\s*$)"),
            QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression sensitiveBlockEndPattern(
            QStringLiteral(R"(^\s*</(key|tls-auth|auth-user-pass)>\s*$)"),
            QRegularExpression::CaseInsensitiveOption);

    QStringList lines = configString.replace("\r", "").split("\n");
    QStringList redactedLines;
    redactedLines.reserve(lines.size());

    bool redactingSensitiveBlock = false;
    for (const QString &line : lines) {
        if (redactingSensitiveBlock) {
            if (sensitiveBlockEndPattern.match(line).hasMatch()) {
                redactingSensitiveBlock = false;
                redactedLines.append(line);
            } else {
                redactedLines.append(QStringLiteral("[hidden]"));
            }
            continue;
        }

        if (sensitiveBlockStartPattern.match(line).hasMatch()) {
            redactingSensitiveBlock = true;
            redactedLines.append(line);
            continue;
        }

        redactedLines.append(isSensitiveInlineConfigLine(line) ? QStringLiteral("[hidden]") : line);
    }

    return redactedLines.join('\n');
}
}

ProtocolsModel::ProtocolsModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int ProtocolsModel::rowCount(const QModelIndex &parent) const
{
    Q_UNUSED(parent);
    return m_containerConfig.container != DockerContainer::None ? 1 : 0;
}

QHash<int, QByteArray> ProtocolsModel::roleNames() const
{
    QHash<int, QByteArray> roles;

    roles[ProtocolNameRole] = "protocolName";
    roles[ServerProtocolPageRole] = "serverProtocolPage";
    roles[ClientProtocolPageRole] = "clientProtocolPage";
    roles[ProtocolIndexRole] = "protocolIndex";
    roles[ProtocolStringRole] = "protocolString";
    roles[RawConfigRole] = "rawConfig";
    roles[IsClientProtocolExistsRole] = "isClientProtocolExists";
    roles[IsWireGuardRole] = "isWireGuard";
    roles[IsAwgRole] = "isAwg";
    roles[IsOpenVpnRole] = "isOpenVpn";
    roles[IsXrayRole] = "isXray";
    roles[IsSftpRole] = "isSftp";
    roles[IsIpsecRole] = "isIpsec";
    roles[IsSocks5ProxyRole] = "isSocks5Proxy";

    return roles;
}

QVariant ProtocolsModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= rowCount()) {
        return QVariant();
    }

    Proto proto = getProtocolType();
    
    switch (role) {
    case ProtocolNameRole: {
        return ProtocolUtils::protocolHumanNames().value(proto);
    }
    case ServerProtocolPageRole:
        return static_cast<int>(serverProtocolPage(proto));
    case ClientProtocolPageRole:
        return static_cast<int>(clientProtocolPage(proto));
    case ProtocolIndexRole: return static_cast<int>(proto);
    case ProtocolStringRole: return ProtocolUtils::protoToString(proto);
    case IsWireGuardRole: return proto == Proto::WireGuard;
    case IsAwgRole: return proto == Proto::Awg;
    case IsOpenVpnRole: return proto == Proto::OpenVpn;
    case IsXrayRole: return proto == Proto::Xray;
    case IsSftpRole: return proto == Proto::Sftp;
    case IsIpsecRole: return proto == Proto::Ikev2;
    case IsSocks5ProxyRole: return proto == Proto::Socks5Proxy;
    case RawConfigRole:
        return getRawConfig();
    case IsClientProtocolExistsRole:
        return isClientProtocolExists();
    }

    return QVariant();
}

void ProtocolsModel::updateModel(const amnezia::ContainerConfig &containerConfig)
{
    beginResetModel();
    m_containerConfig = containerConfig;
    endResetModel();
}

Proto ProtocolsModel::getProtocolType() const
{
    return m_containerConfig.getProtocolType();
}

QString ProtocolsModel::getRawConfig() const
{
    return redactNativeConfigForDisplay(m_containerConfig.protocolConfig.nativeConfig()) + "\n";
}

bool ProtocolsModel::isClientProtocolExists() const
{
    return m_containerConfig.protocolConfig.hasClientConfig() && 
           !m_containerConfig.protocolConfig.nativeConfig().isEmpty();
}

PageLoader::PageEnum ProtocolsModel::serverProtocolPage(Proto protocol) const
{
    switch (protocol) {
    case Proto::OpenVpn: return PageLoader::PageEnum::PageProtocolOpenVpnSettings;
    case Proto::WireGuard: return PageLoader::PageEnum::PageProtocolWireGuardSettings;
    case Proto::Awg: return PageLoader::PageEnum::PageProtocolAwgSettings;
    case Proto::Ikev2: return PageLoader::PageEnum::PageProtocolIKev2Settings;
    case Proto::Xray: return PageLoader::PageEnum::PageProtocolXraySettings;
    
    // non-vpn
    case Proto::TorWebSite: return PageLoader::PageEnum::PageServiceTorWebsiteSettings;
    case Proto::Dns: return PageLoader::PageEnum::PageServiceDnsSettings;
    case Proto::Sftp: return PageLoader::PageEnum::PageServiceSftpSettings;
    case Proto::Socks5Proxy: return PageLoader::PageEnum::PageServiceSocksProxySettings;
    default: return PageLoader::PageEnum::PageProtocolOpenVpnSettings;
    }
}

PageLoader::PageEnum ProtocolsModel::clientProtocolPage(Proto protocol) const
{
    switch (protocol) {
    case Proto::WireGuard: return PageLoader::PageEnum::PageProtocolWireGuardClientSettings;
    case Proto::Awg: return PageLoader::PageEnum::PageProtocolAwgClientSettings;
    default: return PageLoader::PageEnum::PageProtocolOpenVpnSettings;
    }
}
