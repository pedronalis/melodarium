#include "portabilityservice.h"

#include "database.h"

#include <QFile>
#include <QSaveFile>
#include <QSet>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QXmlStreamReader>
#include <QXmlStreamWriter>

#include <algorithm>

namespace {

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
