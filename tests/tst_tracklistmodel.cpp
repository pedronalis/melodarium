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

    // O cabeçalho da biblioteca anuncia "N faixas · 3 d 11 h": a soma vem do modelo, e uma
    // lista vazia tem de somar zero em vez de herdar o total da lista anterior.
    void totalDurationSumsTheLoadedRows()
    {
        TrackListModel model;
        QCOMPARE(model.totalDurationMs(), 0);

        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.totalDurationMs(), 185000);

        model.setRowsForTesting({});
        QCOMPARE(model.totalDurationMs(), 0);
    }

    // O coração da lista não reagia ao clique: o banco gravava, o modelo não avisava
    // ninguém, e a linha só mudava quando a lista inteira era recarregada. dataChanged
    // com UM papel é o que evita repintar 1.200 linhas por causa de uma.
    void applyLikedTouchesOnlyTheRowAndTheRole()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), false);

        QSignalSpy spy(&model, &QAbstractItemModel::dataChanged);
        model.applyLiked(1, true);

        QCOMPARE(model.data(model.index(0), TrackListModel::LikedRole).toBool(), true);
        QCOMPARE(spy.count(), 1);
        const QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        const QList<int> roles = args.at(2).value<QList<int>>();
        QCOMPARE(roles.size(), 1);
        QCOMPARE(roles.first(), int(TrackListModel::LikedRole));
    }

    // Curtir uma faixa que não está na lista aberta (por exemplo, curtida pela busca) não
    // pode emitir sinal nenhum: um índice inválido num dataChanged derruba a ListView.
    void applyLikedIgnoresIdsOutsideTheLoadedList()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        QSignalSpy spy(&model, &QAbstractItemModel::dataChanged);
        model.applyLiked(999, true);
        QCOMPARE(spy.count(), 0);
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

    // The bulk "+ Coleção" gesture reads ids, in the same order the rows are shown: a
    // collection stores ids, and the playlist stores paths.
    void allTrackIdsFeedsCollectionsInTheSameOrder()
    {
        TrackListModel model;
        model.setRowsForTesting(sampleRows());
        const QVariantList ids = model.allTrackIds();
        QCOMPARE(ids.size(), 2);
        QCOMPARE(ids.first().toInt(), 1);
        QCOMPARE(ids.last().toInt(), 2);
    }
};

QTEST_MAIN(TstTrackListModel)
#include "tst_tracklistmodel.moc"
