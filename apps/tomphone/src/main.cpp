#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QIcon>
#include "backend.h"
#include "theme.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("tomphone"); app.setApplicationVersion("0.1.0");
    app.setDesktopFileName("tomphone"); app.setWindowIcon(QIcon::fromTheme("tomphone"));
    QQuickStyle::setStyle("Material");
    Theme theme; Backend backend; QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    return app.exec();
}
