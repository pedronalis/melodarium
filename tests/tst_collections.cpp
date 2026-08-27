#include <QtTest/QtTest>
#include <QSqlError>
#include <QSqlQuery>
#include <QTemporaryDir>

#include "collectionmanager.h"
#include "database.h"

class TstCollections : public QObject
{
    Q_OBJECT

private:
    QTemporaryDir m_dir;

    void exec(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        QVERIFY2(q.exec(sql), qPrintable(q.lastError().text()));
    }

    int scalar(const QString &sql)
    {
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        QSqlQuery q(db);
        return (q.exec(sql) && q.next()) ? q.value(0).toInt() : -1;
    }

    // collections() is ordered by name, not by insertion, so a collection is looked up by
    // name here instead of by position.
    static int idOf(CollectionManager &cm, const QString &name)
    {
        const QVariantList all = cm.collections();
        for (const QVariant &entry : all) {
            const QVariantMap row = entry.toMap();
            if (row.value(QStringLiteral("name")).toString().compare(name, Qt::CaseInsensitive) == 0)
                return row.value(QStringLiteral("id")).toInt();
        }
        return 0;
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
        QVERIFY(Database::openConnection(QLatin1String(Database::kUiConnection),
                                         m_dir.filePath(QStringLiteral("t.db"))));
        QSqlDatabase db = QSqlDatabase::database(QLatin1String(Database::kUiConnection));
        Database::applyPragmas(db);
        QVERIFY(Database::migrate(db));
        for (int i = 1; i <= 3; ++i) {
            exec(QStringLiteral("INSERT INTO tracks (id, path, mtime, size, title, added_at) "
                                "VALUES (%1, '/m/%1.flac', 1, 1, 'F%1', 100)")
                     .arg(i));
        }
    }

    // "At least 3", not "exactly 3": what this slice needs is that ITS migration ran. Later
    // slices append migrations, and an equality here would turn every one of them into a
    // false failure in a file that has nothing to do with them.
    void schemaIncludesTheCollectionsMigration()
    {
        QVERIFY(scalar(QStringLiteral("PRAGMA user_version")) >= 3);
    }

    void createRejectsDuplicateNameRegardlessOfCase()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Pra codar"));
        QVERIFY(id > 0);
        QCOMPARE(cm.createCollection(QStringLiteral("pra CODAR")), 0);
        QCOMPARE(cm.createCollection(QStringLiteral("  Pra   codar  ")), 0); // simplified()
        QCOMPARE(cm.createCollection(QString()), 0);
    }

    void oneTrackLivesInSeveralCollections()
    {
        CollectionManager cm;
        const int night = cm.createCollection(QStringLiteral("Madrugada"));
        const int code = idOf(cm, QStringLiteral("Pra codar"));
        QVERIFY(night > 0);
        QVERIFY(code > 0);
        QVERIFY(night != code);

        QVERIFY(cm.addTrackToCollection(night, 1));
        QVERIFY(cm.addTrackToCollection(code, 1));
        QCOMPARE(cm.collectionsForTrack(1).size(), 2); // the whole point of the product
    }

    void addingTheSameTrackTwiceIsANoOp()
    {
        CollectionManager cm;
        const int id = idOf(cm, QStringLiteral("Pra codar"));
        QVERIFY(id > 0);
        QVERIFY(cm.addTrackToCollection(id, 2));
        QVERIFY(cm.addTrackToCollection(id, 2)); // must not fail, must not duplicate
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM collection_tracks WHERE collection_id = %1 AND track_id = 2")
                     .arg(id)),
                 1);
    }

    void positionsUseGapsOfAThousand()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Ordem"));
        cm.addTrackToCollection(id, 1);
        cm.addTrackToCollection(id, 2);
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT MAX(position) FROM collection_tracks WHERE collection_id = %1").arg(id)),
                 2 * CollectionManager::kPositionStep);
    }

    void deletingCollectionDropsItsLinksButKeepsTracks()
    {
        CollectionManager cm;
        const int id = cm.createCollection(QStringLiteral("Descartável"));
        cm.addTrackToCollection(id, 3);
        QVERIFY(cm.deleteCollection(id));
        QCOMPARE(scalar(QStringLiteral(
                     "SELECT COUNT(*) FROM collection_tracks WHERE collection_id = %1").arg(id)),
                 0);
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tracks WHERE id = 3")), 1);
    }

    void tagsAreCaseInsensitiveAndAutocomplete()
    {
        CollectionManager cm;
        QVERIFY(cm.addTagToTrack(1, QStringLiteral("codar")));
        QVERIFY(cm.addTagToTrack(2, QStringLiteral("CODAR"))); // same tag, different case
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags")), 1);

        cm.addTagToTrack(3, QStringLiteral("concentração"));
        const QStringList hits = cm.completeTag(QStringLiteral("co"));
        QCOMPARE(hits.size(), 2);
        QVERIFY(cm.completeTag(QStringLiteral("zzz")).isEmpty());
    }

    void removingTheLastUseDropsTheOrphanTag()
    {
        CollectionManager cm;
        QVERIFY(cm.addTagToTrack(1, QStringLiteral("efêmera")));
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags WHERE name = 'efêmera'")), 1);
        QVERIFY(cm.removeTagFromTrack(1, QStringLiteral("efêmera")));
        QCOMPARE(scalar(QStringLiteral("SELECT COUNT(*) FROM tags WHERE name = 'efêmera'")), 0);
    }
};

QTEST_MAIN(TstCollections)
#include "tst_collections.moc"
