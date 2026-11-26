// Captures the marketing screenshots from the real interface, offscreen, with
// the fonts installed on this machine. Run through bin/screenshots, which sets
// a throwaway XDG_CONFIG_HOME so nothing the app writes reaches your settings,
// and QT_SCALE_FACTOR for HiDPI output.
//
//   screenshots <output-folder>
//
// Each shot is a set of QML expressions evaluated against the window, then a
// wait for previews and fonts to load, then a grab.
#include "backend.h"
#include "catalog.h"
#include "theme.h"

#include <QDir>
#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTest>

static QVariant eval(QQmlEngine &engine, QObject *scope, const QString &js) {
    QQmlExpression expr(engine.rootContext(), scope, js);
    const QVariant v = expr.evaluate();
    if (expr.hasError()) qWarning().noquote() << "eval:" << js << "->" << expr.error().toString();
    return v;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("omatype-screenshots"));
    app.setOrganizationName(QStringLiteral("omatype-screenshots"));
    app.setApplicationVersion(QStringLiteral("0.2.0"));
    QQuickStyle::setStyle(QStringLiteral("OmaTypeStyle"));

    const QString outDir = app.arguments().value(1, QStringLiteral("screenshots"));
    QDir().mkpath(outDir);

    OmarchyTheme theme;
    Backend backend;
    Catalog catalog(&backend);
    qmlRegisterSingletonInstance("Omatype", 1, 0, "OmarchyTheme", &theme);
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/Theme.qml")), "Omatype", 1, 0, "Theme");
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/ui/icons/Icons.qml")), "Omatype", 1, 0, "Icons");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/ui/Icon.qml")), "Omatype", 1, 0, "Icon");
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/ui/Sheets.qml")), "Omatype", 1, 0, "Sheets");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);
    engine.rootContext()->setContextProperty(QStringLiteral("catalog"), &catalog);
    engine.rootContext()->setContextProperty(QStringLiteral("theme"), &theme);
    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    auto *win = engine.rootObjects().isEmpty() ? nullptr : qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    if (!win) { qCritical("Main.qml did not load"); return 1; }
    win->resize(1440, 860);
    win->show();

    backend.refresh();
    catalog.loadBlocking(false);
    for (int i = 0; i < 300 && backend.property("scanning").toBool(); ++i) QTest::qWait(100);
    QTest::qWait(1500);

    auto js = [&](const QString &s) { return eval(engine, win, s); };
    auto shot = [&](const QString &name, int settleMs) {
        if (win->activeFocusItem()) win->activeFocusItem()->setFocus(false);
        QTest::mouseMove(win, QPoint(1300, 840));
        QTest::qWait(settleMs);
        const QImage img = win->grabWindow();
        const QString path = outDir + QLatin1Char('/') + name + QStringLiteral(".png");
        img.save(path);
        qInfo().noquote() << path << img.width() << "x" << img.height();
    };

    // 1. Discover hero: the catalog with Playfair Display in the detail panel.
    win->setProperty("mode", QStringLiteral("discover"));
    js(QStringLiteral("catalog.sourceFilter = 'all'; catalog.category = ''; catalog.selectFamily('playfair-display')"));
    shot(QStringLiteral("discover-hero"), 6000);

    // 2. Gallery: detail panel closed, the grid across the window.
    js(QStringLiteral("catalog.selectFamily('')"));
    shot(QStringLiteral("discover-gallery"), 4000);

    // 3. Indie foundries with Jost*.
    js(QStringLiteral("catalog.sourceFilter = 'indie'; catalog.selectFamily('jost')"));
    shot(QStringLiteral("discover-indie"), 6000);

    // 4. Library specimen of EB Garamond.
    catalog.setProperty("sourceFilter", QStringLiteral("all"));
    win->setProperty("mode", QStringLiteral("library"));
    js(QStringLiteral("backend.source = 'all'; backend.clearRefine(); backend.view = 'specimen'; backend.selectedName = 'EB Garamond'"));
    shot(QStringLiteral("library-specimen"), 3000);

    // 5. Compare three families.
    js(QStringLiteral("backend.clearCompare(); ['EB Garamond', 'Trickster', 'Liberation Sans'].forEach(f => backend.toggleCompare(f)); backend.selectedName = 'EB Garamond'; backend.view = 'compare'"));
    shot(QStringLiteral("library-compare"), 3000);

    // 6. Tidy up over the specimen.
    js(QStringLiteral("backend.view = 'specimen'"));
    QObject *tidy = win->findChild<QObject *>(QStringLiteral("tidySheet"));
    if (tidy) QMetaObject::invokeMethod(tidy, "open");
    shot(QStringLiteral("tidy-up"), 3000);

    return 0;
}
