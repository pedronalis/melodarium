#include "portabilityservice.h"

#include "database.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDataStream>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSet>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStorageInfo>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUuid>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

#include <algorithm>

namespace {

constexpr int kBundleVersion = 1;
constexpr qint64 kMaximumManifestSize = 1024 * 1024;
const QByteArray kBundleMagic = QByteArrayLiteral("MELOBACK");

bool validFeedUrl(const QUrl &url)
{
    const QString scheme = url.scheme().toLower();
    return url.isValid() && !url.host().isEmpty()
           && (scheme == QStringLiteral("http") || scheme == QStringLiteral("https"))
           && url.userName().isEmpty() && url.password().isEmpty();
}

QString normalisedFeedUrl(const QUrl &url)
{
    QUrl normalised = url.adjusted(QUrl::NormalizePathSegments | QUrl::RemoveFragment);
    normalised.setScheme(normalised.scheme().toLower());
    normalised.setHost(normalised.host().toLower());
    return normalised.toString(QUrl::FullyEncoded);
}

QString deterministicTextKey(const QString &text)
{
    QString key;
    const QString decomposed = text.normalized(QString::NormalizationForm_D).toCaseFolded();
    key.reserve(decomposed.size());
    for (const QChar character : decomposed) {
        const QChar::Category category = character.category();
        if (category != QChar::Mark_NonSpacing
            && category != QChar::Mark_SpacingCombining
            && category != QChar::Mark_Enclosing)
            key.append(character);
    }
    return key;
}

QVariantMap opmlSummary(int imported, int duplicates, int failed, const QString &error = {})
{
    return {{QStringLiteral("imported"), imported},
            {QStringLiteral("duplicates"), duplicates},
            {QStringLiteral("failed"), failed},
            {QStringLiteral("error"), error}};
}

Portability::BundleResult bundleFailure(const QString &error,
                                        const QString &rollbackPath = {})
{
    return {false, error, rollbackPath, false};
}

QByteArray hashFile(const QString &path, QString *error)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error)
            *error = QObject::tr("Não foi possível ler %1.").arg(path);
        return {};
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    while (!file.atEnd()) {
        const QByteArray chunk = file.read(1024 * 1024);
        if (chunk.isEmpty() && file.error() != QFile::NoError) {
            if (error)
                *error = QObject::tr("Falha ao calcular o hash de %1.").arg(path);
            return {};
        }
        hash.addData(chunk);
    }
    return hash.result();
}

bool appendFile(QIODevice *output, const QString &path, QString *error)
{
    QFile input(path);
    if (!input.open(QIODevice::ReadOnly)) {
        if (error)
            *error = QObject::tr("Não foi possível ler %1.").arg(path);
        return false;
    }
    while (!input.atEnd()) {
        const QByteArray chunk = input.read(1024 * 1024);
        if ((chunk.isEmpty() && input.error() != QFile::NoError)
            || output->write(chunk) != chunk.size()) {
            if (error)
                *error = QObject::tr("Falha ao copiar dados para o bundle.");
            return false;
        }
    }
    return true;
}

QString sqlString(const QString &value)
{
    QString escaped = value;
    escaped.replace(QLatin1Char('\''), QStringLiteral("''"));
    return QLatin1Char('\'') + escaped + QLatin1Char('\'');
}

bool consistentDatabaseCopy(const QString &sourcePath, const QString &destinationPath,
                            QString *error)
{
    QFile::remove(destinationPath);
    const QString connectionName = QStringLiteral("melodarium-bundle-")
                                   + QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool ok = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setDatabaseName(sourcePath);
        if (!db.open()) {
            if (error)
                *error = db.lastError().text();
        } else {
            QSqlQuery snapshot(db);
            ok = snapshot.exec(QStringLiteral("VACUUM INTO %1")
                                   .arg(sqlString(destinationPath)));
            if (!ok && error)
                *error = snapshot.lastError().text();
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connectionName);
    return ok;
}

bool extractPayload(QFile *bundle, qint64 size, const QString &destination,
                    QByteArray *digest, QString *error)
{
    QFile output(destination);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error)
            *error = QObject::tr("Não foi possível preparar a restauração.");
        return false;
    }
    QCryptographicHash hash(QCryptographicHash::Sha256);
    qint64 remaining = size;
    while (remaining > 0) {
        const QByteArray chunk = bundle->read(qMin<qint64>(1024 * 1024, remaining));
        if (chunk.isEmpty() || output.write(chunk) != chunk.size()) {
            if (error)
                *error = QObject::tr("Bundle truncado durante a extração.");
            return false;
        }
        hash.addData(chunk);
        remaining -= chunk.size();
    }
    output.close();
    *digest = hash.result();
    return true;
}

bool sqliteQuickCheck(const QString &databasePath, QString *error)
{
    const QString connectionName = QStringLiteral("melodarium-quick-check-")
                                   + QUuid::createUuid().toString(QUuid::WithoutBraces);
    bool ok = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY"));
        db.setDatabaseName(databasePath);
        if (!db.open()) {
            if (error)
                *error = db.lastError().text();
        } else {
            QSqlQuery check(db);
            ok = check.exec(QStringLiteral("PRAGMA quick_check")) && check.next()
                 && check.value(0).toString() == QLatin1String("ok") && !check.next();
            if (!ok && error)
                *error = QObject::tr("O banco do bundle falhou no quick_check.");
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connectionName);
    return ok;
}

bool copyToStage(const QString &source, const QString &destination, QString *error)
{
    QFile::remove(destination);
    if (QFile::copy(source, destination))
        return true;
    if (error)
        *error = QObject::tr("Não foi possível preparar a troca de arquivos.");
    return false;
}

void closeDatabaseConnectionsFor(const QString &databasePath)
{
    const QString target = QFileInfo(databasePath).absoluteFilePath();
    const QStringList connections = QSqlDatabase::connectionNames();
    for (const QString &name : connections) {
        bool matches = false;
        {
            QSqlDatabase db = QSqlDatabase::database(name, false);
            matches = db.isValid()
                      && QFileInfo(db.databaseName()).absoluteFilePath() == target;
            if (matches)
                db.close();
        }
        if (matches)
            QSqlDatabase::removeDatabase(name);
    }
}

bool moveIfPresent(const QString &source, const QString &destination, QString *error)
{
    if (!QFileInfo::exists(source))
        return true;
    QFile::remove(destination);
    if (QFile::rename(source, destination))
        return true;
    if (error)
        *error = QObject::tr("Não foi possível mover %1.").arg(source);
    return false;
}

void restoreMovedFile(const QString &oldPath, const QString &targetPath)
{
    if (!QFileInfo::exists(oldPath))
        return;
    QFile::remove(targetPath);
    QFile::rename(oldPath, targetPath);
}

QVariantMap bundleResultMap(const Portability::BundleResult &result)
{
    return {{QStringLiteral("ok"), result.ok},
            {QStringLiteral("error"), result.error},
            {QStringLiteral("rollbackPath"), result.rollbackBundlePath},
            {QStringLiteral("restartRequired"), result.restartRequired}};
}

QString liveDatabasePath()
{
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    const QString applicationName = QCoreApplication::applicationName().isEmpty()
                                        ? QStringLiteral("melodarium")
                                        : QCoreApplication::applicationName();
    return directory + QLatin1Char('/') + applicationName + QStringLiteral(".db");
}

} // namespace

Portability::OpmlParseResult Portability::parseOpml(QIODevice *device)
{
    OpmlParseResult result;
    if (!device || !device->isReadable()) {
        result.error = QObject::tr("Não foi possível ler o arquivo OPML.");
        return result;
    }

    QSet<QString> seen;
    QXmlStreamReader xml(device);
    while (!xml.atEnd()) {
        xml.readNext();
        if (!xml.isStartElement() || xml.name().compare(QLatin1String("outline"),
                                                        Qt::CaseInsensitive) != 0)
            continue;

        QString rawUrl;
        QString title;
        for (const QXmlStreamAttribute &attribute : xml.attributes()) {
            if (attribute.name().compare(QLatin1String("xmlUrl"),
                                         Qt::CaseInsensitive) == 0)
                rawUrl = attribute.value().toString().trimmed();
            else if (attribute.name().compare(QLatin1String("title"),
                                              Qt::CaseInsensitive) == 0
                     || (title.isEmpty()
                         && attribute.name().compare(QLatin1String("text"),
                                                     Qt::CaseInsensitive) == 0))
                title = attribute.value().toString().trimmed();
        }

        const QUrl url(rawUrl, QUrl::StrictMode);
        if (rawUrl.isEmpty() || !validFeedUrl(url)) {
            ++result.invalidCount;
            continue;
        }
        const QString key = normalisedFeedUrl(url);
        if (seen.contains(key)) {
            ++result.duplicateCount;
            continue;
        }
        seen.insert(key);
        result.subscriptions.append({title.isEmpty() ? url.host() : title, QUrl(key)});
    }

    if (xml.hasError()) {
        result.subscriptions.clear();
        result.duplicateCount = 0;
        result.invalidCount = 0;
        result.error = QObject::tr("OPML malformado: %1").arg(xml.errorString());
    }
    return result;
}

bool Portability::writeOpml(QIODevice *device, QList<OpmlSubscription> subscriptions,
                            QString *error)
{
    if (!device || !device->isWritable()) {
        if (error)
            *error = QObject::tr("Não foi possível escrever o arquivo OPML.");
        return false;
    }

    std::sort(subscriptions.begin(), subscriptions.end(),
              [](const OpmlSubscription &left, const OpmlSubscription &right) {
                  const int titleOrder = QString::compare(deterministicTextKey(left.title),
                                                          deterministicTextKey(right.title));
                  if (titleOrder != 0)
                      return titleOrder < 0;
                  return normalisedFeedUrl(left.feedUrl)
                         < normalisedFeedUrl(right.feedUrl);
              });

    QXmlStreamWriter xml(device);
    xml.setAutoFormatting(true);
    xml.writeStartDocument(QStringLiteral("1.0"));
    xml.writeStartElement(QStringLiteral("opml"));
    xml.writeAttribute(QStringLiteral("version"), QStringLiteral("2.0"));
    xml.writeStartElement(QStringLiteral("head"));
    xml.writeTextElement(QStringLiteral("title"), QObject::tr("Assinaturas do Melodarium"));
    xml.writeEndElement();
    xml.writeStartElement(QStringLiteral("body"));
    for (const OpmlSubscription &subscription : std::as_const(subscriptions)) {
        xml.writeStartElement(QStringLiteral("outline"));
        xml.writeAttribute(QStringLiteral("type"), QStringLiteral("rss"));
        xml.writeAttribute(QStringLiteral("text"), subscription.title);
        xml.writeAttribute(QStringLiteral("title"), subscription.title);
        xml.writeAttribute(QStringLiteral("xmlUrl"), normalisedFeedUrl(subscription.feedUrl));
        xml.writeEndElement();
    }
    xml.writeEndElement();
    xml.writeEndElement();
    xml.writeEndDocument();
    if (xml.hasError()) {
        if (error)
            *error = QObject::tr("Falha ao escrever o arquivo OPML.");
        return false;
    }
    return true;
}

Portability::M3uWriteResult Portability::writeM3u(QIODevice *device,
                                                  const QStringList &paths)
{
    M3uWriteResult result;
    if (!device || !device->isWritable()) {
        result.error = QObject::tr("Não foi possível escrever a playlist M3U.");
        return result;
    }

    if (device->write("#EXTM3U\n") < 0) {
        result.error = QObject::tr("Falha ao escrever o cabeçalho M3U.");
        return result;
    }

    QSet<QString> seen;
    for (const QString &path : paths) {
        const QFileInfo info(path);
        const QString cleanPath = QDir::cleanPath(info.absoluteFilePath());
        if (!info.isAbsolute() || !info.exists() || !info.isFile()
            || seen.contains(cleanPath)) {
            ++result.skipped;
            continue;
        }
        seen.insert(cleanPath);
        const QByteArray line = cleanPath.toUtf8() + '\n';
        if (device->write(line) != line.size()) {
            result.error = QObject::tr("Falha ao escrever uma faixa na playlist M3U.");
            return result;
        }
        ++result.written;
    }
    return result;
}

Portability::BundleResult Portability::createBundle(const QString &bundlePath,
                                                     const QString &databasePath,
                                                     const QString &settingsPath)
{
    if (!QFileInfo::exists(databasePath))
        return bundleFailure(QObject::tr("O banco de dados de origem não existe."));

    QTemporaryDir staging;
    if (!staging.isValid())
        return bundleFailure(QObject::tr("Não foi possível criar a área temporária."));
    const QString databaseSnapshot = staging.filePath(QStringLiteral("database.sqlite"));
    QString error;
    if (!consistentDatabaseCopy(databasePath, databaseSnapshot, &error))
        return bundleFailure(QObject::tr("Falha ao criar snapshot do banco: %1").arg(error));

    const QString settingsSnapshot = staging.filePath(QStringLiteral("settings.ini"));
    if (QFileInfo::exists(settingsPath)) {
        if (!QFile::copy(settingsPath, settingsSnapshot))
            return bundleFailure(QObject::tr("Falha ao copiar as preferências."));
    } else {
        QFile empty(settingsSnapshot);
        if (!empty.open(QIODevice::WriteOnly))
            return bundleFailure(QObject::tr("Falha ao preparar as preferências."));
    }

    const QByteArray databaseHash = hashFile(databaseSnapshot, &error);
    if (databaseHash.isEmpty() && QFileInfo(databaseSnapshot).size() > 0)
        return bundleFailure(error);
    const QByteArray settingsHash = hashFile(settingsSnapshot, &error);
    if (settingsHash.isEmpty() && QFileInfo(settingsSnapshot).size() > 0)
        return bundleFailure(error);

    const QJsonObject manifest = {
        {QStringLiteral("version"), kBundleVersion},
        {QStringLiteral("createdAt"),
         QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs)},
        {QStringLiteral("databaseSize"), double(QFileInfo(databaseSnapshot).size())},
        {QStringLiteral("settingsSize"), double(QFileInfo(settingsSnapshot).size())},
        {QStringLiteral("databaseSha256"), QString::fromLatin1(databaseHash.toHex())},
        {QStringLiteral("settingsSha256"), QString::fromLatin1(settingsHash.toHex())},
    };
    const QByteArray manifestBytes = QJsonDocument(manifest).toJson(QJsonDocument::Compact);

    QSaveFile bundle(bundlePath);
    if (!bundle.open(QIODevice::WriteOnly))
        return bundleFailure(QObject::tr("Não foi possível criar o bundle."));
    if (bundle.write(kBundleMagic) != kBundleMagic.size())
        return bundleFailure(QObject::tr("Falha ao escrever o cabeçalho do bundle."));
    QDataStream header(&bundle);
    header.setByteOrder(QDataStream::BigEndian);
    header << quint32(manifestBytes.size());
    if (header.status() != QDataStream::Ok
        || bundle.write(manifestBytes) != manifestBytes.size()
        || !appendFile(&bundle, databaseSnapshot, &error)
        || !appendFile(&bundle, settingsSnapshot, &error)
        || !bundle.commit())
        return bundleFailure(error.isEmpty()
                                 ? QObject::tr("Não foi possível finalizar o bundle.") : error);
    return {true, {}, {}, false};
}

Portability::BundleResult Portability::restoreBundle(const QString &bundlePath,
                                                      const QString &databasePath,
                                                      const QString &settingsPath,
                                                      bool failAfterDatabaseSwap)
{
    QFile bundle(bundlePath);
    if (!bundle.open(QIODevice::ReadOnly))
        return bundleFailure(QObject::tr("Não foi possível abrir o bundle."));
    if (bundle.read(kBundleMagic.size()) != kBundleMagic)
        return bundleFailure(QObject::tr("Cabeçalho de bundle inválido."));

    QDataStream header(&bundle);
    header.setByteOrder(QDataStream::BigEndian);
    quint32 manifestSize = 0;
    header >> manifestSize;
    if (header.status() != QDataStream::Ok || manifestSize == 0
        || manifestSize > kMaximumManifestSize)
        return bundleFailure(QObject::tr("Manifesto de bundle inválido."));
    const QByteArray manifestBytes = bundle.read(manifestSize);
    if (manifestBytes.size() != int(manifestSize))
        return bundleFailure(QObject::tr("Bundle truncado no manifesto."));

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(manifestBytes, &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return bundleFailure(QObject::tr("Manifesto JSON inválido."));
    const QJsonObject manifest = document.object();
    const int version = manifest.value(QStringLiteral("version")).toInt(-1);
    if (version != kBundleVersion)
        return bundleFailure(QObject::tr("Versão de bundle não suportada: %1.").arg(version));
    const qint64 databaseSize = qint64(manifest.value(QStringLiteral("databaseSize")).toDouble(-1));
    const qint64 settingsSize = qint64(manifest.value(QStringLiteral("settingsSize")).toDouble(-1));
    if (databaseSize <= 0 || settingsSize < 0
        || bundle.size() != bundle.pos() + databaseSize + settingsSize)
        return bundleFailure(QObject::tr("Bundle truncado ou com tamanhos inválidos."));

    QTemporaryDir extracted;
    if (!extracted.isValid())
        return bundleFailure(QObject::tr("Não foi possível preparar a validação."));
    const QString extractedDatabase = extracted.filePath(QStringLiteral("database.sqlite"));
    const QString extractedSettings = extracted.filePath(QStringLiteral("settings.ini"));
    QString error;
    QByteArray databaseHash;
    QByteArray settingsHash;
    if (!extractPayload(&bundle, databaseSize, extractedDatabase, &databaseHash, &error)
        || !extractPayload(&bundle, settingsSize, extractedSettings, &settingsHash, &error))
        return bundleFailure(error);
    if (QString::fromLatin1(databaseHash.toHex())
            != manifest.value(QStringLiteral("databaseSha256")).toString()
        || QString::fromLatin1(settingsHash.toHex())
               != manifest.value(QStringLiteral("settingsSha256")).toString())
        return bundleFailure(QObject::tr("Hash do bundle inválido."));
    if (!sqliteQuickCheck(extractedDatabase, &error))
        return bundleFailure(error);

    const qint64 currentBytes = QFileInfo(databasePath).size() + QFileInfo(settingsPath).size();
    const qint64 requiredBytes = databaseSize + settingsSize + currentBytes + 1024 * 1024;
    const QStorageInfo storage(QFileInfo(databasePath).absolutePath());
    if (storage.isValid() && storage.isReady() && storage.bytesAvailable() < requiredBytes)
        return bundleFailure(QObject::tr("Espaço insuficiente para restaurar com rollback."));

    const QString rollbackPath = databasePath + QStringLiteral(".before-restore-")
                                 + QDateTime::currentDateTimeUtc().toString(
                                     QStringLiteral("yyyyMMdd-HHmmsszzz"))
                                 + QStringLiteral(".melodarium-backup");
    const BundleResult rollback = createBundle(rollbackPath, databasePath, settingsPath);
    if (!rollback.ok)
        return bundleFailure(QObject::tr("Não foi possível criar o backup de retorno: %1")
                                 .arg(rollback.error));

    const QString token = QUuid::createUuid().toString(QUuid::WithoutBraces);
    const QString stagedDatabase = databasePath + QStringLiteral(".restore-new-") + token;
    const QString stagedSettings = settingsPath + QStringLiteral(".restore-new-") + token;
    if (!copyToStage(extractedDatabase, stagedDatabase, &error)
        || !copyToStage(extractedSettings, stagedSettings, &error)) {
        QFile::remove(stagedDatabase);
        QFile::remove(stagedSettings);
        return bundleFailure(error, rollbackPath);
    }

    closeDatabaseConnectionsFor(databasePath);
    const QString oldDatabase = databasePath + QStringLiteral(".restore-old-") + token;
    const QString oldWal = oldDatabase + QStringLiteral("-wal");
    const QString oldShm = oldDatabase + QStringLiteral("-shm");
    const QString oldSettings = settingsPath + QStringLiteral(".restore-old-") + token;

    auto rollbackSwap = [&]() {
        QFile::remove(databasePath);
        QFile::remove(databasePath + QStringLiteral("-wal"));
        QFile::remove(databasePath + QStringLiteral("-shm"));
        restoreMovedFile(oldDatabase, databasePath);
        restoreMovedFile(oldWal, databasePath + QStringLiteral("-wal"));
        restoreMovedFile(oldShm, databasePath + QStringLiteral("-shm"));
        if (QFileInfo::exists(oldSettings)) {
            QFile::remove(settingsPath);
            restoreMovedFile(oldSettings, settingsPath);
        }
        QFile::remove(stagedDatabase);
        QFile::remove(stagedSettings);
    };

    if (!moveIfPresent(databasePath, oldDatabase, &error)
        || !moveIfPresent(databasePath + QStringLiteral("-wal"), oldWal, &error)
        || !moveIfPresent(databasePath + QStringLiteral("-shm"), oldShm, &error)
        || !QFile::rename(stagedDatabase, databasePath)) {
        rollbackSwap();
        return bundleFailure(error.isEmpty() ? QObject::tr("Falha ao trocar o banco.") : error,
                             rollbackPath);
    }
    if (failAfterDatabaseSwap) {
        rollbackSwap();
        return bundleFailure(QObject::tr("Falha simulada depois da troca do banco."),
                             rollbackPath);
    }

    if (!moveIfPresent(settingsPath, oldSettings, &error)
        || !QFile::rename(stagedSettings, settingsPath)) {
        rollbackSwap();
        return bundleFailure(error.isEmpty()
                                 ? QObject::tr("Falha ao trocar as preferências.") : error,
                             rollbackPath);
    }

    QFile::remove(oldDatabase);
    QFile::remove(oldWal);
    QFile::remove(oldShm);
    QFile::remove(oldSettings);
    return {true, {}, rollbackPath, true};
}

PortabilityService::PortabilityService(QObject *parent)
    : QObject(parent)
{
}

QVariantMap PortabilityService::importOpml(const QUrl &fileUrl)
{
    if (!fileUrl.isLocalFile())
        return opmlSummary(0, 0, 0, tr("Escolha um arquivo OPML local."));

    QFile file(fileUrl.toLocalFile());
    if (!file.open(QIODevice::ReadOnly))
        return opmlSummary(0, 0, 0, tr("Não foi possível abrir o arquivo OPML."));
    const Portability::OpmlParseResult parsed = Portability::parseOpml(&file);
    if (!parsed.error.isEmpty())
        return opmlSummary(0, 0, 0, parsed.error);

    QSet<QString> existing;
    if (QSqlDatabase::contains(QLatin1String(Database::kUiConnection))) {
        QSqlQuery query(QSqlDatabase::database(QLatin1String(Database::kUiConnection)));
        if (query.exec(QStringLiteral(
                "SELECT feed_url FROM podcast_shows WHERE feed_url IS NOT NULL"))) {
            while (query.next())
                existing.insert(normalisedFeedUrl(QUrl(query.value(0).toString())));
        }
    }

    int imported = 0;
    int duplicates = parsed.duplicateCount;
    for (const Portability::OpmlSubscription &subscription : parsed.subscriptions) {
        const QString key = normalisedFeedUrl(subscription.feedUrl);
        if (existing.contains(key)) {
            ++duplicates;
            continue;
        }
        existing.insert(key);
        emit subscriptionRequested(subscription.feedUrl);
        ++imported;
    }
    return opmlSummary(imported, duplicates, parsed.invalidCount);
}

QVariantMap PortabilityService::exportOpml(const QUrl &fileUrl)
{
    if (!fileUrl.isLocalFile())
        return opmlSummary(0, 0, 0, tr("Escolha um destino local para o OPML."));
    if (!QSqlDatabase::contains(QLatin1String(Database::kUiConnection)))
        return opmlSummary(0, 0, 0, tr("O banco de dados não está disponível."));

    QList<Portability::OpmlSubscription> subscriptions;
    QSqlQuery query(QSqlDatabase::database(QLatin1String(Database::kUiConnection)));
    if (!query.exec(QStringLiteral(
            "SELECT title, feed_url FROM podcast_shows WHERE feed_url IS NOT NULL "
            "ORDER BY title COLLATE NOCASE, feed_url")))
        return opmlSummary(0, 0, 0, tr("Não foi possível ler as assinaturas."));
    while (query.next())
        subscriptions.append({query.value(0).toString(), QUrl(query.value(1).toString())});

    QSaveFile file(fileUrl.toLocalFile());
    if (!file.open(QIODevice::WriteOnly))
        return opmlSummary(0, 0, 0, tr("Não foi possível criar o arquivo OPML."));
    QString error;
    if (!Portability::writeOpml(&file, subscriptions, &error) || !file.commit())
        return opmlSummary(0, 0, 0,
                           error.isEmpty() ? tr("Não foi possível salvar o arquivo OPML.")
                                           : error);
    return opmlSummary(subscriptions.size(), 0, 0);
}

QVariantMap PortabilityService::exportCollectionM3u(int collectionId, const QUrl &fileUrl)
{
    auto resultMap = [](int exported, int skipped, const QString &error = QString()) {
        return QVariantMap{{QStringLiteral("exported"), exported},
                           {QStringLiteral("skipped"), skipped},
                           {QStringLiteral("error"), error}};
    };

    if (collectionId <= 0 || !fileUrl.isLocalFile())
        return resultMap(0, 0, tr("Escolha uma coleção e um destino local."));
    if (!QSqlDatabase::contains(QLatin1String(Database::kUiConnection)))
        return resultMap(0, 0, tr("O banco de dados não está disponível."));

    QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
    QSqlQuery collection(db);
    collection.prepare(QStringLiteral("SELECT 1 FROM collections WHERE id = ?"));
    collection.addBindValue(collectionId);
    if (!collection.exec() || !collection.next())
        return resultMap(0, 0, tr("A coleção não existe mais."));

    QStringList paths;
    QSqlQuery query(db);
    query.prepare(QStringLiteral(
        "SELECT t.path FROM collection_tracks ct "
        "JOIN tracks t ON t.id = ct.track_id "
        "WHERE ct.collection_id = ? AND t.removed_at IS NULL "
        "ORDER BY ct.position, ct.track_id"));
    query.addBindValue(collectionId);
    if (!query.exec())
        return resultMap(0, 0, tr("Não foi possível ler a coleção."));
    while (query.next())
        paths.append(query.value(0).toString());

    QSaveFile file(fileUrl.toLocalFile());
    if (!file.open(QIODevice::WriteOnly))
        return resultMap(0, 0, tr("Não foi possível criar a playlist M3U."));
    const Portability::M3uWriteResult result = Portability::writeM3u(&file, paths);
    if (!result.error.isEmpty() || !file.commit())
        return resultMap(0, result.skipped,
                         result.error.isEmpty()
                             ? tr("Não foi possível salvar a playlist M3U.") : result.error);
    return resultMap(result.written, result.skipped);
}

QVariantMap PortabilityService::createBackup(const QUrl &fileUrl)
{
    if (!fileUrl.isLocalFile())
        return bundleResultMap(bundleFailure(tr("Escolha um destino local para o backup.")));
    QSettings settings;
    settings.sync();
    return bundleResultMap(Portability::createBundle(fileUrl.toLocalFile(),
                                                      liveDatabasePath(),
                                                      settings.fileName()));
}

QVariantMap PortabilityService::restoreBackup(const QUrl &fileUrl)
{
    if (!fileUrl.isLocalFile())
        return bundleResultMap(bundleFailure(tr("Escolha um bundle local para restaurar.")));
    QSettings settings;
    settings.sync();
    return bundleResultMap(Portability::restoreBundle(fileUrl.toLocalFile(),
                                                       liveDatabasePath(),
                                                       settings.fileName()));
}
