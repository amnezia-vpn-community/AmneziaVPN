#include <QTest>

#include "core/utils/api/apiUtils.h"

namespace
{
    QStringList capturedMessages;
    QtMessageHandler previousMessageHandler = nullptr;

    void captureMessages(QtMsgType, const QMessageLogContext &, const QString &message)
    {
        capturedMessages.append(message);
    }
}

class TestApiUtilsLogging : public QObject
{
    Q_OBJECT

private slots:
    void testNetworkErrorDoesNotLogResponseBody()
    {
        const QByteArray sensitiveBody =
            R"({"http_status":403,"api_key":"secret-api-key","vpn_key":"secret-vpn-key","token":"secret-token"})";

        capturedMessages.clear();
        previousMessageHandler = qInstallMessageHandler(captureMessages);

        const auto result = apiUtils::checkNetworkReplyErrors(
            {}, QStringLiteral("Forbidden"), QNetworkReply::ContentAccessDenied, 403, sensitiveBody);

        qInstallMessageHandler(previousMessageHandler);
        previousMessageHandler = nullptr;

        QCOMPARE(result, amnezia::ErrorCode::ApiConfigDownloadError);

        const QString logOutput = capturedMessages.join('\n');
        QVERIFY2(logOutput.contains(QStringLiteral("Response body omitted from logs")),
                 "Expected a redacted response body diagnostic");
        QVERIFY2(!logOutput.contains(QStringLiteral("secret-api-key")), "API key must not be logged");
        QVERIFY2(!logOutput.contains(QStringLiteral("secret-vpn-key")), "VPN key must not be logged");
        QVERIFY2(!logOutput.contains(QStringLiteral("secret-token")), "Token must not be logged");
    }
};

QTEST_MAIN(TestApiUtilsLogging)
#include "testApiUtilsLogging.moc"
