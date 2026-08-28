#include "database.h"
#include "libraryscanner.h"

#include <QCoreApplication>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QSqlDatabase>
#include <QTextStream>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("melodia"));
    app.setOrganizationName(QStringLiteral("melodia"));

    // --scan varre a biblioteca configurada e sai, sem abrir janela. Existe porque a
    // varredura só tinha um botão: sem isto não há como reproduzir um problema de scanner
    // numa sessão sem tela, nem semear o banco antes de um teste.
    if (app.arguments().contains(QStringLiteral("--scan"))) {
        QTextStream out(stdout);
        const QString root = QSettings().value(QStringLiteral("library/path")).toString();
        if (root.isEmpty()) {
            out << "nenhuma pasta de música configurada\n";
            return 2;
        }
        if (!Database::openConnection(QLatin1String(Database::kScannerConnection),
                                      Database::defaultDatabasePath())) {
            out << "não abriu o banco em " << Database::defaultDatabasePath() << "\n";
            return 3;
        }
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kScannerConnection));
        if (!Database::migrate(db)) {
            out << "migração falhou\n";
            return 4;
        }
        LibraryScanner scanner;
        QObject::connect(&scanner, &LibraryScanner::finished,
                         [&out](int added, int updated, int removed) {
                             out << "varredura: " << added << " novas, " << updated
                                 << " atualizadas, " << removed << " sumidas\n";
                             out.flush();
                             QCoreApplication::quit();
                         });
        QObject::connect(&scanner, &LibraryScanner::failed, [&out](const QString &m) {
            out << "varredura falhou: " << m << "\n";
            out.flush();
            QCoreApplication::exit(5);
        });
        out << "varrendo " << root << "…\n";
        out.flush();
        // run() é síncrono: quando volta, os sinais já foram emitidos.
        scanner.run(root, Database::defaultDatabasePath());
        return 0;
    }

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
