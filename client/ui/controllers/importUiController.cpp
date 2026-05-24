#include "importUiController.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QMutex>
#include <QRegularExpression>

#include "systemController.h"

#ifdef Q_OS_ANDROID
    #include "platforms/android/android_controller.h"
#endif

#if defined Q_OS_ANDROID
ImportUiController* ImportUiController::mInstance = nullptr;
static QMutex qrDecodeMutex;
#endif

namespace
{
QJsonValue redactConfigForDisplay(const QJsonValue &value, const QString &key = {});

bool isSensitiveConfigKey(const QString &key)
{
    const QString lowerKey = key.toLower();
    QString compactKey = lowerKey;
    compactKey.remove('_');
    compactKey.remove('-');
    compactKey.remove(' ');

    return lowerKey == "password"
        || lowerKey == "api_key"
        || lowerKey == "vpn_key"
        || lowerKey == "client_priv_key"
        || lowerKey == "server_priv_key"
        || lowerKey == "psk_key"
        || lowerKey == "presharedkey"
        || lowerKey == "pre_shared_key"
        || lowerKey == "auth-token"
        || lowerKey == "auth_token"
        || compactKey == "apikey"
        || compactKey == "vpnkey"
        || compactKey == "clientprivkey"
        || compactKey == "serverprivkey"
        || compactKey == "pskkey"
        || compactKey == "presharedkey"
        || compactKey == "authtoken"
        || (lowerKey.contains("private") && lowerKey.contains("key"))
        || lowerKey.contains("secret")
        || lowerKey.contains("token");
}

QString redactSensitiveStringForDisplay(QString value)
{
    if (value.startsWith("vpn://", Qt::CaseInsensitive)) {
        return QStringLiteral("[hidden]");
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(value.toUtf8(), &parseError);
    if (parseError.error == QJsonParseError::NoError && !document.isNull()) {
        if (document.isObject()) {
            return QString::fromUtf8(QJsonDocument(redactConfigForDisplay(document.object()).toObject()).toJson(QJsonDocument::Compact));
        }
        if (document.isArray()) {
            QJsonArray redactedArray;
            const QJsonArray array = document.array();
            for (const auto &item : array) {
                redactedArray.append(redactConfigForDisplay(item));
            }
            return QString::fromUtf8(QJsonDocument(redactedArray).toJson(QJsonDocument::Compact));
        }
    }

    static const QRegularExpression sensitiveLinePattern(
            QStringLiteral(R"((^|\n)(\s*(PrivateKey|PresharedKey|PreSharedKey|client_priv_key|server_priv_key|psk_key|password|api_key|vpn_key|auth-token|auth_token)\s*[:=]\s*)[^\n\r]*)"),
            QRegularExpression::CaseInsensitiveOption);
    value.replace(sensitiveLinePattern, QStringLiteral("\\1\\2[hidden]"));

    static const QRegularExpression privateKeyBlockPattern(
            QStringLiteral(R"(-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----)"));
    value.replace(privateKeyBlockPattern, QStringLiteral("[hidden private key]"));

    return value;
}

QJsonValue redactConfigForDisplay(const QJsonValue &value, const QString &key)
{
    if (isSensitiveConfigKey(key)) {
        return QStringLiteral("[hidden]");
    }

    if (value.isString()) {
        return redactSensitiveStringForDisplay(value.toString());
    }

    if (value.isObject()) {
        QJsonObject redactedObject;
        const QJsonObject object = value.toObject();
        for (auto it = object.constBegin(); it != object.constEnd(); ++it) {
            redactedObject.insert(it.key(), redactConfigForDisplay(it.value(), it.key()));
        }
        return redactedObject;
    }

    if (value.isArray()) {
        QJsonArray redactedArray;
        const QJsonArray array = value.toArray();
        for (const auto &item : array) {
            redactedArray.append(redactConfigForDisplay(item));
        }
        return redactedArray;
    }

    return value;
}
}

ImportUiController::ImportUiController(ImportController* importController, QObject *parent)
    : QObject(parent),
      m_importController(importController),
      m_isNativeWireGuardConfig(false)
{
#if defined Q_OS_ANDROID
    mInstance = this;
#endif

    connect(m_importController, &ImportController::importFinished, this, &ImportUiController::importFinished);
    connect(m_importController, &ImportController::importErrorOccurred, this, &ImportUiController::importErrorOccurred);
    connect(m_importController, &ImportController::restoreAppConfig, this, &ImportUiController::restoreAppConfig);
}

bool ImportUiController::extractConfigFromFile(const QString &fileName)
{
    QString data;
    if (!SystemController::readFile(fileName, data)) {
        emit importErrorOccurred(ErrorCode::ImportOpenConfigError, false);
        return false;
    }
    
    QString configFileName = QFileInfo(QFile(fileName).fileName()).fileName();
#ifdef Q_OS_ANDROID
    if (configFileName.isEmpty()) {
        configFileName = AndroidController::instance()->getFileName(fileName);
    }
#endif
    
    auto result = m_importController->extractConfigFromData(data, configFileName);
    
    if (result.errorCode != ErrorCode::NoError) {
        emit importErrorOccurred(result.errorCode, false);
        return false;
    }
    
    m_config = result.config;
    m_configFileName = result.configFileName;
    m_maliciousWarningText = result.maliciousWarningText;
    m_isNativeWireGuardConfig = result.isNativeWireGuardConfig;
    
    emit importConfigChanged();
    return true;
}

bool ImportUiController::extractConfigFromData(QString data)
{
    auto result = m_importController->extractConfigFromData(data);
    
    if (result.errorCode != ErrorCode::NoError) {
        emit importErrorOccurred(result.errorCode, false);
        return false;
    }
    
    m_config = result.config;
    m_configFileName = result.configFileName;
    m_maliciousWarningText = result.maliciousWarningText;
    m_isNativeWireGuardConfig = result.isNativeWireGuardConfig;
    
    emit importConfigChanged();
    return true;
}

bool ImportUiController::extractConfigFromQr(const QByteArray &data)
{
    auto result = m_importController->extractConfigFromQr(data);
    
    if (result.errorCode != ErrorCode::NoError) {
        emit importErrorOccurred(result.errorCode, false);
        return false;
    }
    
    m_config = result.config;
    m_configFileName = result.configFileName;
    m_maliciousWarningText = result.maliciousWarningText;
    m_isNativeWireGuardConfig = result.isNativeWireGuardConfig;
    
    emit importConfigChanged();
    return true;
}

QString ImportUiController::getConfig()
{
    return QJsonDocument(redactConfigForDisplay(m_config).toObject()).toJson(QJsonDocument::Indented);
}

QString ImportUiController::getConfigFileName()
{
    return m_configFileName;
}

QString ImportUiController::getMaliciousWarningText()
{
    return m_maliciousWarningText;
}

bool ImportUiController::isNativeWireGuardConfig()
{
    return m_isNativeWireGuardConfig;
}

void ImportUiController::processNativeWireGuardConfig()
{
    m_config = m_importController->processNativeWireGuardConfig(m_config);
    emit importConfigChanged();
}

void ImportUiController::importConfig()
{
    m_importController->importConfig(m_config);
    
    m_config = {};
    m_configFileName.clear();
    m_maliciousWarningText.clear();
    m_isNativeWireGuardConfig = false;
    
    emit importConfigChanged();
}

void ImportUiController::clearConfigFileName()
{
    m_configFileName.clear();
    emit importConfigChanged();
}

#if defined Q_OS_ANDROID || defined Q_OS_IOS
void ImportUiController::startDecodingQr()
{
    m_importController->startDecodingQr();
#if defined Q_OS_ANDROID
    AndroidController::instance()->startQrReaderActivity();
#endif
}

void ImportUiController::stopDecodingQr()
{
    emit qrDecodingFinished();
}

bool ImportUiController::parseQrCodeChunk(const QString &code)
{
    auto parseResult = m_importController->parseQrCodeChunk(code);
    if (parseResult.success) {
        m_config = parseResult.importResult.config;
        m_configFileName = parseResult.importResult.configFileName;
        m_maliciousWarningText = parseResult.importResult.maliciousWarningText;
        m_isNativeWireGuardConfig = parseResult.importResult.isNativeWireGuardConfig;
        emit importConfigChanged();
        stopDecodingQr();
        return true;
    }
    return false;
}

double ImportUiController::getQrCodeScanProgressBarValue()
{
    const int total = m_importController->qrChunksTotal();
    if (total == 0) {
        return 0.0;
    }
    return (1.0 / total) * m_importController->qrChunksReceived();
}

QString ImportUiController::getQrCodeScanProgressString()
{
    return tr("Scanned %1 of %2.").arg(m_importController->qrChunksReceived()).arg(m_importController->qrChunksTotal());
}
#endif

#if defined Q_OS_ANDROID
bool ImportUiController::decodeQrCode(const QString &code)
{
    QMutexLocker lock(&qrDecodeMutex);

    if (!mInstance) {
        return false;
    }

    if (!mInstance->m_importController->isQrDecodingActive()) {
        mInstance->m_importController->startDecodingQr();
    }
    return mInstance->parseQrCodeChunk(code);
}
#endif
