#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("melodia"));
    app.setOrganizationName(QStringLiteral("melodia"));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    // Dev mode: point MELODIA_DEV_QML at a .qml on disk and it is reloaded on every save,
    // with no cmake --build in between. The C++ types stay available because they are
    // statically linked into this binary; only the QML text is re-read.
    if (qEnvironmentVariableIsSet("MELODIA_DEV_QML")) {
        const QString path = qEnvironmentVariable("MELODIA_DEV_QML");
        auto *watcher = new QFileSystemWatcher(&engine);
        watcher->addPath(path);
        auto reload = [&engine, path]() {
            engine.clearComponentCache();
            engine.load(QUrl::fromLocalFile(path));
        };
        QObject::connect(watcher, &QFileSystemWatcher::fileChanged, &engine, reload);
        reload();
    } else {
        engine.loadFromModule("Melodia.App", "Main");
    }

    return app.exec();
}
