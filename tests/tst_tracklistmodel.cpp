#include <QtTest/QtTest>
#include <QSignalSpy>

#include "tracklistmodel.h"

class TstTrackListModel : public QObject
{
    Q_OBJECT

private:
    static QList<TrackRow> sampleRows()
    {
        TrackRow a;
        a.id = 1;
        a.path = QStringLiteral("/music/a.flac");
        a.title = QStringLiteral("Primeira");
        a.artist = QStringLiteral("Artista");
        a.album = QStringLiteral("Álbum");
        a.durationMs = 185000;

        TrackRow b;
        b.id = 2;
        b.path = QStringLiteral("/music/b.flac");
        b.title = QString(); // no title tag: the model must fall back to the file name
        b.artist = QStringLiteral("Artista");
        b.durationMs = 0;

        return {a, b};
    }

private slots:
    void rowCountAndRolesAreExposed()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.rowCount(), 2);

        const QHash<int, QByteArray> roles = model.roleNames();
        QVERIFY(roles.contains(TrackListModel::TitleRole));
        QCOMPARE(roles.value(TrackListModel::TitleRole), QByteArrayLiteral("title"));
        QCOMPARE(roles.value(TrackListModel::IsCurrentRole), QByteArrayLiteral("isCurrent"));
    }

    void untitledTrackFallsBackToFileName()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.data(model.index(1), TrackListModel::TitleRole).toString(),
                 QStringLiteral("b"));
    }

    void currentPathMarksExactlyOneRow()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QSignalSpy changed(&model, &TrackListModel::dataChanged);

        model.setCurrentPath(QStringLiteral("/music/b.flac"));
        QCOMPARE(model.data(model.index(0), TrackListModel::IsCurrentRole).toBool(), false);
        QCOMPARE(model.data(model.index(1), TrackListModel::IsCurrentRole).toBool(), true);
        QCOMPARE(changed.count(), 1); // one ranged signal, not one per row
    }

    void allPathsFeedsThePlaylistInOrder()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        const QStringList paths = model.allPaths();
        QCOMPARE(paths.size(), 2);
        QCOMPARE(paths.first(), QStringLiteral("/music/a.flac"));
    }
};

QTEST_MAIN(TstTrackListModel)
#include "tst_tracklistmodel.moc"
