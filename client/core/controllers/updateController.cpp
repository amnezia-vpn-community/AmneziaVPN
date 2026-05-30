#include "updateController.h"

#include <QNetworkReply>
#include <QVersionNumber>
#include <QUrl>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSysInfo>
#include <QTimer>

#include "amneziaApplication.h"
#include "logger.h"
#include "version.h"
#include "core/controllers/gatewayController.h"
#include "core/utils/constants/apiKeys.h"
#include "core/utils/errorStrings.h"

namespace
{
    Logger logger("UpdateController");

    bool isHttpsUrlSafeForUpdater(const QUrl &url)
    {
        if (!url.isValid() || url.scheme().compare(QStringLiteral("https"), Qt::CaseInsensitive) != 0) {
            return false;
        }
        if (url.host().isEmpty() || !url.userName().isEmpty() || !url.password().isEmpty()) {
            return false;
        }
        return true;
    }

#if defined(Q_OS_WINDOWS)
    const QLatin1String kInstallerRemoteFileNamePattern("AmneziaVPN_%1_x64.exe");
#elif defined(Q_OS_MACOS)
    const QLatin1String kInstallerRemoteFileNamePattern("AmneziaVPN_%1_macos.pkg");
#elif defined(Q_OS_LINUX) && !defined(Q_OS_ANDROID)
    const QLatin1String kInstallerRemoteFileNamePattern("AmneziaVPN_%1_linux_x64.tar");
#endif
}

UpdateController::UpdateController(SecureAppSettingsRepository* appSettingsRepository, QObject *parent)
    : QObject(parent), m_appSettingsRepository(appSettingsRepository)
{
}

QString UpdateController::getRawChangelogText() const
{
    return m_changelogText;
}

QString UpdateController::getReleaseDate() const
{
    return m_releaseDate;
}

QString UpdateController::getVersion() const
{
    return m_version;
}

void UpdateController::checkForUpdates()
{
    if (m_updateCheckRunning || !m_appSettingsRepository) {
        return;
    }
    m_updateCheckRunning = true;

    fetchGatewayUrl();
}

void UpdateController::finishUpdateCheck()
{
    m_updateCheckRunning = false;
}

void UpdateController::doGetAsync(const QString &endpoint, std::function<void(bool, QByteArray)> onDone)
{
    const QUrl url(m_baseUrl + endpoint);
    if (!isValidUpdaterUrl(url)) {
        logger.error() << "Refusing unsafe updater URL:" << url.toDisplayString(QUrl::RemoveUserInfo);
        onDone(false, QByteArray());
        return;
    }

    QNetworkRequest req;
    req.setTransferTimeout(7000);
    req.setMaximumRedirectsAllowed(3);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setUrl(url);

    QNetworkReply *reply = amnApp->networkManager()->get(req);
    setupNetworkErrorHandling(reply, endpoint);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, endpoint, onDone]() {
        const bool ok = (reply->error() == QNetworkReply::NoError);
        QByteArray data;
        if (ok) {
            const QUrl finalUrl = reply->url();
            if (!isValidUpdaterUrl(finalUrl)) {
                logger.error() << "Refusing updater response after unsafe redirect target:" << finalUrl.toDisplayString(QUrl::RemoveUserInfo);
                reply->deleteLater();
                onDone(false, QByteArray());
                return;
            }
            data = reply->readAll();
        } else {
            handleNetworkError(reply, endpoint);
        }
        reply->deleteLater();
        onDone(ok, data);
    });
}

void UpdateController::fetchGatewayUrl()
{
    auto gatewayController = QSharedPointer<GatewayController>::create(m_appSettingsRepository->getGatewayEndpoint(),
                                                                       m_appSettingsRepository->isDevGatewayEnv(),
                                                                       7000,
                                                                       m_appSettingsRepository->isStrictKillSwitchEnabled());

    QJsonObject apiPayload;
    apiPayload[apiDefs::key::cliVersion] = QString(APP_VERSION);
    apiPayload[apiDefs::key::osVersion] = QSysInfo::productType();
    apiPayload[apiDefs::key::installationUuid] = m_appSettingsRepository->getInstallationUuid(true);

    // Workaround: wait before contacting gateway to avoid rate limit triggered by other requests (news etc.)
    QTimer::singleShot(1000, this, [this, gatewayController, apiPayload]() {
        gatewayController->postAsync(QStringLiteral("%1v1/updater_endpoint"), apiPayload)
            .then(this, [this](QPair<ErrorCode, QByteArray> result) {
                auto [err, gatewayResponse] = result;
                if (err != ErrorCode::NoError) {
                    logger.error() << errorString(err);
                    finishUpdateCheck();
                    return;
                }

                QJsonObject gatewayData = QJsonDocument::fromJson(gatewayResponse).object();

                QString baseUrl = gatewayData.value("url").toString().trimmed();
                if (baseUrl.endsWith('/')) {
                    baseUrl.chop(1);
                }

                if (!isValidUpdaterBaseUrl(baseUrl)) {
                    logger.error() << "Refusing unsafe updater base URL from gateway:" << QUrl(baseUrl).toDisplayString(QUrl::RemoveUserInfo);
                    finishUpdateCheck();
                    return;
                }
                m_baseUrl = baseUrl;

                fetchVersionInfo();
            });
    });
}

void UpdateController::fetchVersionInfo()
{
    doGetAsync("/VERSION", [this](bool ok, QByteArray data) {
        if (!ok) {
            finishUpdateCheck();
            return;
        }
        m_version = QString::fromUtf8(data).trimmed();
        
        if (!isNewVersionAvailable()) {
            finishUpdateCheck();
            return;
        }
        fetchChangelog();
    });
}

void UpdateController::fetchChangelog()
{
    doGetAsync("/CHANGELOG", [this](bool ok, QByteArray data) {
        if (!ok) {
            m_changelogText.clear();
        } else {
            m_changelogText = QString::fromUtf8(data);
        }
        fetchReleaseDate();
    });
}

void UpdateController::fetchReleaseDate()
{
    doGetAsync("/RELEASE_DATE", [this](bool ok, QByteArray data) {
        if (ok) {
            m_releaseDate = QString::fromUtf8(data).trimmed();
        } else {
            m_releaseDate = QString();
        }

        m_downloadUrl = composeDownloadUrl();
        if (m_downloadUrl.isEmpty()) {
            logger.error() << "Refusing update because installer download URL is unsafe";
            finishUpdateCheck();
            return;
        }
        emit updateFound();
        finishUpdateCheck();
    });
}

bool UpdateController::isNewVersionAvailable() const
{
    auto currentVersion = QVersionNumber::fromString(QString(APP_VERSION));
    auto newVersion = QVersionNumber::fromString(m_version);
    return newVersion > currentVersion;
}

void UpdateController::setupNetworkErrorHandling(QNetworkReply* reply, const QString& operation)
{
    QObject::connect(reply, &QNetworkReply::errorOccurred, [reply, operation](QNetworkReply::NetworkError error) {
        logger.error() << QString("Network error occurred while fetching %1: %2 %3")
                          .arg(operation, reply->errorString(), QString::number(error));
    });
    
    QObject::connect(reply, &QNetworkReply::sslErrors, [operation](const QList<QSslError> &errors) {
        QStringList errorStrings;
        for (const QSslError &err : errors) {
            errorStrings << err.errorString();
        }
        logger.error() << QString("SSL errors while fetching %1: %2").arg(operation, errorStrings.join("; "));
    });
}

void UpdateController::handleNetworkError(QNetworkReply* reply, const QString& operation)
{
    if (reply->error() == QNetworkReply::NetworkError::OperationCanceledError
        || reply->error() == QNetworkReply::NetworkError::TimeoutError) {
        logger.error() << errorString(ErrorCode::ApiConfigTimeoutError);
    } else {
        QString err = reply->errorString();
        logger.error() << "Network error code:" << QString::number(static_cast<int>(reply->error()));
        logger.error() << "Error message:" << err;
        logger.error() << "HTTP status:" << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        logger.error() << errorString(ErrorCode::ApiConfigDownloadError);
    }
}

bool UpdateController::isValidUpdaterBaseUrl(const QString &baseUrl)
{
    const QUrl url(baseUrl);
    if (!isHttpsUrlSafeForUpdater(url)) {
        return false;
    }
    if (url.hasQuery() || url.hasFragment()) {
        return false;
    }

    // Do not pin a release host here until the product owns a stable update CDN contract.
    // Immediate invariant: updater metadata and installers must never come from plaintext
    // HTTP, credentials-bearing URLs, or HTTPS->HTTP redirects.
    return true;
}

bool UpdateController::isValidUpdaterUrl(const QUrl &url)
{
    return isHttpsUrlSafeForUpdater(url);
}

bool UpdateController::isUpdaterInstallerExecutionAllowed()
{
    // Fail closed until updater artifacts are authenticated with a signed manifest
    // or an equivalent local verification gate before execution.
    return false;
}

QString UpdateController::composeDownloadUrl() const
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    const QString fileName = QString(kInstallerRemoteFileNamePattern).arg(m_version);
    QUrl baseUrl(m_baseUrl);
    if (!isValidUpdaterBaseUrl(m_baseUrl)) {
        return QString();
    }
    QString path = baseUrl.path();
    if (!path.endsWith('/')) {
        path += '/';
    }
    path += fileName;
    baseUrl.setPath(path);
    baseUrl.setQuery(QString());
    baseUrl.setFragment(QString());
    if (!isValidUpdaterUrl(baseUrl)) {
        return QString();
    }
    return baseUrl.toString(QUrl::FullyEncoded);
#else
    return QString();
#endif
}

void UpdateController::runInstaller()
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS)
    logger.error() << "Refusing to run updater installer without artifact authenticity verification";
#endif
}
