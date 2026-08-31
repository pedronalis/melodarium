#include "database.h"
#include "audioengine.h"
#include "libraryscanner.h"
#ifdef MELODARIUM_HAS_MPRIS
#include "mprisservice.h"
#endif

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
#include <QSurfaceFormat>
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

    // As preferências vêm antes, e por outro caminho: o QSettings cria o arquivo novo (vazio)
    // logo na primeira leitura, então "mover se o destino não existe" nunca dispararia — o app
    // esqueceria a pasta de música e os dois compromissos de qualidade de áudio, e o usuário
    // veria a tela de "escolha uma pasta" com a biblioteca inteira já varrida atrás dela.
    // Copiar chave a chave é idempotente e não sobrescreve nada que já tenha sido escolhido.
    {
        QSettings atuais;
        // NativeFormat, e não IniFormat: pedir Ini explicitamente faz o Qt procurar
        // `melodia.ini`, e o arquivo que existe de verdade é `melodia.conf` — o nativo no
        // Unix. A diferença é uma palavra, e ela custou a pasta de música do usuário.
        QSettings velhas(QSettings::NativeFormat, QSettings::UserScope, antigo, antigo);
        const QStringList chaves = velhas.allKeys();
        for (const QString &chave : chaves) {
            if (!atuais.contains(chave))
                atuais.setValue(chave, velhas.value(chave));
        }
        atuais.sync();
    }

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
    // Sem isto a janela sai em RGB565 e o app inteiro fica esverdeado — não por engano de
    // paleta, por falta de bits. O QSurfaceFormat padrão deixa os canais em -1 ("tanto faz"),
    // e a regra de desempate do eglChooseConfig prefere o menor buffer que atenda ao pedido:
    // nesta máquina (NVIDIA, Wayland) isso devolve 5/6/5. O verde ganha o dobro de degraus dos
    // outros dois, então todo cinza neutro do tema chega à tela com R=B e G acima — #151515
    // vira #101410 — e a escada de cinzas do desenho colapsa: o degradê do painel, de 9 níveis,
    // vira 3. Pedir 8/8/8 elimina os configs de 16 bits da seleção. Alfa fica em 0 de propósito:
    // a janela é opaca, e pedir alfa acionaria o blur do compositor por baixo dela.
    //
    // Isto NÃO é pego por teste nenhum que fotografe o app por dentro: com QT_QPA_PLATFORM=
    // offscreen o Qt usa o rasterizador de software, que sempre é 8 bits. Só medindo a janela
    // real, pelo compositor, o defeito aparece.
    QSurfaceFormat fmt = QSurfaceFormat::defaultFormat();
    fmt.setRedBufferSize(8);
    fmt.setGreenBufferSize(8);
    fmt.setBlueBufferSize(8);
    fmt.setAlphaBufferSize(0);
    QSurfaceFormat::setDefaultFormat(fmt);

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

#ifdef MELODARIUM_HAS_MPRIS
    if (auto *audio = engine.singletonInstance<AudioEngine *>(QStringLiteral("Melodarium.App"),
                                                              QStringLiteral("AudioEngine")))
        new MprisService(audio, &engine);
#endif

    return app.exec();
}
