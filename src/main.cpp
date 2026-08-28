#include "database.h"
#include "libraryscanner.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSettings>
#include <QSqlDatabase>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>

namespace {

// O projeto se chamou "melodia" até 28/08/2026. Todo caminho de dados do Qt sai do nome da
// aplicação, então trocar o nome move a biblioteca varrida, as capas em cache, os downloads e
// os podcasts para um endereço novo — e o app abriria pela primeira vez com a tela vazia, como
// se nada existisse. Esta função existe para que a troca de nome não custe nada a quem já
// usava: na primeira abertura com o nome novo, ela traz a casa antiga junto.
//
// Roda uma vez só: assim que o diretório novo existe, ela não faz mais nada.
void migrarDoNomeAntigo()
{
    const QString antigo = QStringLiteral("melodia");
    const QString atual = QCoreApplication::applicationName();

    struct Caminho {
        QString novo;
        QString velho;
    };
    const QList<Caminho> caminhos = {
        { QStandardPaths::writableLocation(QStandardPaths::AppDataLocation),
          QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
              + QLatin1Char('/') + antigo + QLatin1Char('/') + antigo },
        { QStandardPaths::writableLocation(QStandardPaths::CacheLocation),
          QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
              + QLatin1Char('/') + antigo + QLatin1Char('/') + antigo },
    };

    for (const Caminho &c : caminhos) {
        if (c.novo.isEmpty() || QDir(c.novo).exists() || !QDir(c.velho).exists())
            continue;
        QDir().mkpath(QFileInfo(c.novo).absolutePath());
        if (!QDir().rename(c.velho, c.novo))
            continue;
        // O arquivo do banco leva o nome do app no próprio nome; mover a pasta não basta.
        QDir destino(c.novo);
        const QStringList sufixos = { QString(), QStringLiteral("-wal"), QStringLiteral("-shm") };
        for (const QString &sufixo : sufixos) {
            const QString de = destino.filePath(antigo + QStringLiteral(".db") + sufixo);
            if (QFile::exists(de))
                QFile::rename(de, destino.filePath(atual + QStringLiteral(".db") + sufixo));
        }
        // A pasta da organização antiga fica para trás vazia; rmdir só remove se estiver.
        QDir().rmdir(QFileInfo(c.velho).absolutePath());
    }
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("melodarium"));
    app.setOrganizationName(QStringLiteral("melodarium"));

    // Antes de qualquer coisa que leia disco: é ela que decide de onde o banco vai ser aberto.
    migrarDoNomeAntigo();

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
        engine.loadFromModule("Melodarium.App", "Main");
    }

    return app.exec();
}
