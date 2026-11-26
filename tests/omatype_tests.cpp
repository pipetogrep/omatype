#include "backend.h"
#include "catalog.h"
#include "theme.h"

#include <QFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QtTest>

class OmatypeTests : public QObject {
    Q_OBJECT
private slots:
    void initTestCase()
    {
        // Main.qml keeps layout state in QtCore Settings, which needs an
        // application identity; a separate one keeps tests off real settings.
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("omatype-tests"));
        QCoreApplication::setApplicationName(QStringLiteral("omatype-tests"));
    }
    void stripXssiPrefix() {
        QCOMPARE(Catalog::stripXssiPrefix(")]}'\n{\"ok\":true}"), QByteArray("{\"ok\":true}"));
        QCOMPARE(Catalog::stripXssiPrefix("{\"ok\":true}"), QByteArray("{\"ok\":true}"));
    }

    void normalizeId() {
        QCOMPARE(Catalog::normalizeId("Playfair Display"), QStringLiteral("playfair-display"));
        QCOMPARE(Catalog::normalizeId("  Jost*  "), QStringLiteral("jost"));
        QCOMPARE(Catalog::normalizeId("IBM Plex Sans"), QStringLiteral("ibm-plex-sans"));
    }

    void parseGoogleMetadata() {
        const QByteArray sample =
            ")]}'\n"
            "{\n"
            "  \"familyMetadataList\": [\n"
            "    {\n"
            "      \"family\": \"Playfair Display\",\n"
            "      \"designers\": [\"Claus Eggers Sørensen\"],\n"
            "      \"category\": \"Serif\",\n"
            "      \"subsets\": [\"latin\", \"latin-ext\", \"menu\"],\n"
            "      \"axes\": [{\"tag\": \"wght\", \"min\": 400, \"max\": 900, \"defaultValue\": 400}],\n"
            "      \"fonts\": {\"400\": {}, \"400i\": {}, \"700\": {}, \"700i\": {}},\n"
            "      \"popularity\": 12,\n"
            "      \"trending\": 5,\n"
            "      \"dateAdded\": \"2011-06-08\",\n"
            "      \"isNoto\": false\n"
            "    }\n"
            "  ]\n"
            "}\n";
        const auto list = Catalog::parseGoogleMetadata(sample);
        QCOMPARE(list.size(), 1);
        const CatalogFamily &f = list.first();
        QCOMPARE(f.id, QStringLiteral("playfair-display"));
        QCOMPARE(f.family, QStringLiteral("Playfair Display"));
        QCOMPARE(f.designersText(), QStringLiteral("Claus Eggers Sørensen"));
        QCOMPARE(f.category, QStringLiteral("Serif"));
        QVERIFY(f.variable);
        QCOMPARE(f.axes.size(), 1);
        QCOMPARE(f.styles.size(), 4);
        QCOMPARE(f.weightRangeText(), QStringLiteral("400–700"));
        QVERIFY(!f.subsets.contains(QStringLiteral("menu")));
    }

    void parseGoogleDownloadManifest() {
        const QByteArray sample =
            ")]}'\n"
            "{\n"
            "  \"zipName\": \"Inter.zip\",\n"
            "  \"manifest\": {\n"
            "    \"files\": [\n"
            "      {\"filename\": \"OFL.txt\", \"contents\": \"SIL Open Font License 1.1\"}\n"
            "    ],\n"
            "    \"fileRefs\": [\n"
            "      {\"filename\": \"Inter-VariableFont_opsz,wght.ttf\", \"url\": \"https://fonts.gstatic.com/s/inter/v20/var.ttf\"},\n"
            "      {\"filename\": \"static/Inter_18pt-Regular.ttf\", \"url\": \"https://fonts.gstatic.com/s/inter/v20/reg.ttf\"},\n"
            "      {\"filename\": \"static/Inter_18pt-BoldItalic.ttf\", \"url\": \"https://fonts.gstatic.com/s/inter/v20/bi.ttf\"}\n"
            "    ]\n"
            "  }\n"
            "}\n";
        QList<CatalogFile> files;
        QString lic;
        QVERIFY(Catalog::parseGoogleDownloadManifest(sample, &files, &lic));
        QCOMPARE(files.size(), 3);
        QVERIFY(files.first().variable);
        QCOMPARE(files.at(1).weight, 400);
        QVERIFY(!files.at(1).italic);
        QCOMPARE(files.at(2).weight, 700);
        QVERIFY(files.at(2).italic);
        QVERIFY(lic.contains(QStringLiteral("SIL Open Font License")));
    }

    void curatedCatalogIsValid() {
        QFile f(QStringLiteral(":/data/curated-catalog.json"));
        QVERIFY(f.open(QIODevice::ReadOnly));
        const auto list = Catalog::parseCuratedCatalog(f.readAll());
        QVERIFY2(list.size() >= 20, "Expected at least 20 curated open-source families");
        for (const CatalogFamily &e : list) {
            QVERIFY2(!e.family.isEmpty(), "Empty family name");
            QVERIFY2(!e.designers.isEmpty(), qPrintable("Missing designer for " + e.family));
            QVERIFY2(!e.license.isEmpty(), qPrintable("Missing license for " + e.family));
            QVERIFY2(!e.files.isEmpty(), qPrintable("No downloadable files for " + e.family));
            QVERIFY2(e.previewUrl.startsWith(QStringLiteral("https://")), qPrintable("Invalid previewUrl for " + e.family));
        }
    }

    void cssAndMagicDetection() {
        const QByteArray css = "@font-face { font-family: 'Inter'; src: url(https://fonts.gstatic.com/l/font?kit=abc) format('truetype'); }";
        QCOMPARE(Catalog::extractCssFontUrl(css), QStringLiteral("https://fonts.gstatic.com/l/font?kit=abc"));

        QVERIFY(Catalog::looksLikeFontFile(QByteArray("\x00\x01\x00\x00\x00\x0f\x00\x80\x00\x03\x00\x70", 12)));
        QVERIFY(Catalog::looksLikeFontFile(QByteArray("OTTO0123456789", 14)));
        QVERIFY(!Catalog::looksLikeFontFile(QByteArray("<html>404 Not Found</html>")));
    }

    void registeredAppsAndExecParsing() {
        QString proc;
        QCOMPARE(Backend::cleanDesktopExec(QStringLiteral("/usr/bin/inkscape %F"), &proc), QStringLiteral("/usr/bin/inkscape"));
        QCOMPARE(proc, QStringLiteral("inkscape"));

        QCOMPARE(Backend::cleanDesktopExec(QStringLiteral("env GDK_BACKEND=wayland gimp-2.99 %U"), &proc), QStringLiteral("env GDK_BACKEND=wayland gimp-2.99"));
        QCOMPARE(proc, QStringLiteral("gimp-2.99"));

        QCOMPARE(Backend::cleanDesktopExec(QStringLiteral("uwsm app -- figcraft %u"), &proc), QStringLiteral("uwsm app -- figcraft"));
        QCOMPARE(proc, QStringLiteral("figcraft"));

        Library lib;
        RegisteredApp a;
        a.id = QStringLiteral("app12345");
        a.name = QStringLiteral("Inkscape");
        a.processName = QStringLiteral("inkscape");
        a.launchCommand = QStringLiteral("inkscape");
        a.reloadCommand = QString();
        a.autoReload = true;
        lib.apps.append(a);

        Library roundTrip;
        roundTrip.fromJson(lib.toJson());
        QCOMPARE(roundTrip.apps.size(), 1);
        QCOMPARE(roundTrip.apps.first().id, QStringLiteral("app12345"));
        QCOMPARE(roundTrip.apps.first().name, QStringLiteral("Inkscape"));
        QCOMPARE(roundTrip.apps.first().processName, QStringLiteral("inkscape"));
        QCOMPARE(roundTrip.apps.first().launchCommand, QStringLiteral("inkscape"));
        QVERIFY(roundTrip.apps.first().autoReload);
    }

    void qmlLoadsCleanly() {
        QQuickStyle::setStyle(QStringLiteral("OmaTypeStyle"));
        OmarchyTheme theme;
        Backend backend;
        Catalog catalog(&backend);

        qmlRegisterSingletonInstance("Omatype", 1, 0, "OmarchyTheme", &theme);
        qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/Theme.qml")), "Omatype", 1, 0, "Theme");
        qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/ui/icons/Icons.qml")), "Omatype", 1, 0, "Icons");
        qmlRegisterType(QUrl(QStringLiteral("qrc:/ui/Icon.qml")), "Omatype", 1, 0, "Icon");
        qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/ui/Sheets.qml")), "Omatype", 1, 0, "Sheets");

        QQmlApplicationEngine engine;
        QStringList warnings;
        QObject::connect(&engine, &QQmlApplicationEngine::warnings, this, [&](const QList<QQmlError> &errs) {
            for (const QQmlError &e : errs) warnings.append(e.toString());
        });
        engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
        engine.rootContext()->setContextProperty(QStringLiteral("catalog"), &catalog);
        engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
        engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));

        QVERIFY2(!engine.rootObjects().isEmpty(), "Main.qml failed to load");
        QVERIFY2(warnings.isEmpty(), qPrintable("QML warnings:\n" + warnings.join('\n')));

        // Select a curated font and verify Inspector updates cleanly.
        catalog.selectFamily(QStringLiteral("jost"));
        QCOMPARE(catalog.selectedFamily().value(QStringLiteral("family")).toString(), QStringLiteral("Jost*"));

        // Toggle shortlist and verify count.
        catalog.clearShortlist();
        catalog.toggleShortlist(QStringLiteral("jost"));
        QCOMPARE(catalog.shortlistCount(), 1);

        const QString shotPath = qEnvironmentVariable("OMATYPE_GRAB_SCREENSHOT");
        if (!shotPath.isEmpty()) {
            catalog.clearShortlist();
            catalog.loadBlocking(false);
            catalog.selectFamily(QStringLiteral("playfair-display"));
            catalog.toggleShortlist(QStringLiteral("geist"));
            catalog.toggleShortlist(QStringLiteral("playfair-display"));
            if (auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first())) {
                if (win->activeFocusItem()) win->activeFocusItem()->setFocus(false);
                // Move virtual pointer off (0,0) so the File menu isn't hovered in captures.
                QTest::mouseMove(win, QPoint(720, 430));
                // Give all visible cards (Google + indie foundries) time to finish loading.
                QTest::qWait(5000);
                win->grabWindow().save(shotPath);
            }
        }

        catalog.clearShortlist();
        QCOMPARE(catalog.shortlistCount(), 0);

        // Tab strips fold what does not fit behind a "more" button instead of
        // running under the right panel.
        auto *win = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(win);
        QObject *tabs = win->findChild<QObject *>(QStringLiteral("categoryTabs"));
        QVERIFY(tabs);
        const int total = tabs->property("count").toInt();
        QVERIFY(total > 1);
        win->resize(2400, 900);
        QTRY_VERIFY(!tabs->property("overflowing").toBool());
        QCOMPARE(tabs->property("fitCount").toInt(), total);
        win->resize(760, 900);
        QTRY_VERIFY(tabs->property("overflowing").toBool());
        QVERIFY(tabs->property("fitCount").toInt() < total);

        const QString narrowShot = qEnvironmentVariable("OMATYPE_GRAB_NARROW");
        if (!narrowShot.isEmpty()) {
            win->setProperty("mode", QStringLiteral("library"));
            win->resize(1100, 700);
            QTest::qWait(1500);
            win->grabWindow().save(narrowShot);
            win->setProperty("mode", QStringLiteral("discover"));
            catalog.selectFamily(QStringLiteral("jost"));
            QTest::qWait(1500);
            win->grabWindow().save(QString(narrowShot).replace(QStringLiteral(".png"), QStringLiteral("-discover.png")));
        }
    }
};

QTEST_MAIN(OmatypeTests)
#include "omatype_tests.moc"
