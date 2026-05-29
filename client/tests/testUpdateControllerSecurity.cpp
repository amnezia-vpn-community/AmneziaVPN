#include <QTest>
#include <QUrl>

#include "core/controllers/updateController.h"

class TestUpdateControllerSecurity : public QObject
{
    Q_OBJECT

private slots:
    void rejectsPlainHttpUpdaterBaseUrl()
    {
        QVERIFY(!UpdateController::isValidUpdaterBaseUrl(QStringLiteral("http://updates.amnezia.org")));
        QVERIFY(!UpdateController::isValidUpdaterBaseUrl(QStringLiteral("http://updates.amnezia.org:80/releases")));
    }

    void rejectsCredentialsQueryAndFragmentInBaseUrl()
    {
        QVERIFY(!UpdateController::isValidUpdaterBaseUrl(QStringLiteral("https://user:pass@updates.amnezia.org")));
        QVERIFY(!UpdateController::isValidUpdaterBaseUrl(QStringLiteral("https://updates.amnezia.org/releases?channel=stable")));
        QVERIFY(!UpdateController::isValidUpdaterBaseUrl(QStringLiteral("https://updates.amnezia.org/releases#latest")));
    }

    void acceptsHttpsUpdaterBaseUrl()
    {
        QVERIFY(UpdateController::isValidUpdaterBaseUrl(QStringLiteral("https://updates.amnezia.org/releases")));
    }

    void rejectsUnsafeInstallerUrl()
    {
        QVERIFY(!UpdateController::isValidUpdaterUrl(QUrl(QStringLiteral("http://updates.amnezia.org/AmneziaVPN.exe"))));
        QVERIFY(!UpdateController::isValidUpdaterUrl(QUrl(QStringLiteral("https://user@updates.amnezia.org/AmneziaVPN.exe"))));
    }

    void acceptsHttpsInstallerUrl()
    {
        QVERIFY(UpdateController::isValidUpdaterUrl(QUrl(QStringLiteral("https://updates.amnezia.org/AmneziaVPN_1.2.3_x64.exe"))));
    }

    void blocksInstallerExecutionUntilArtifactsAreAuthenticated()
    {
        QVERIFY(!UpdateController::isUpdaterInstallerExecutionAllowed());
    }
};

QTEST_MAIN(TestUpdateControllerSecurity)
#include "testUpdateControllerSecurity.moc"
