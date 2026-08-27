cmake_minimum_required(VERSION 3.21)
project(melodia LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Concurrent Core Network Qml Quick QuickControls2 QuickDialogs2 Sql)
find_package(PkgConfig REQUIRED)
pkg_check_modules(MPV REQUIRED IMPORTED_TARGET mpv)
pkg_check_modules(TAGLIB REQUIRED IMPORTED_TARGET taglib)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appmelodia
    src/main.cpp
    src/colorschemeprovider.h
    src/colorschemeprovider.cpp
    src/audioengine.h
    src/audioengine.cpp
    src/tagreader.h
    src/tagreader.cpp
    src/database.h
    src/database.cpp
    src/libraryscanner.h
    src/libraryscanner.cpp
    src/covercache.h
    src/covercache.cpp
    src/tracklistmodel.h
    src/tracklistmodel.cpp
    src/librarybrowser.h
    src/librarybrowser.cpp
    src/playstatsrecorder.h
    src/playstatsrecorder.cpp
    src/collectionmanager.h
    src/collectionmanager.cpp
    src/podcastlibrary.h
    src/podcastlibrary.cpp
    src/podcastepisodemodel.h
    src/podcastepisodemodel.cpp
    src/podcastfeedfetcher.h
    src/podcastfeedfetcher.cpp
    src/episodedownloader.h
    src/episodedownloader.cpp
    src/ytdlpdownloader.h
    src/ytdlpdownloader.cpp
)

# Theme.qml e Icons.qml usam `pragma Singleton`. O qt_add_qml_module NAO detecta o pragma
# sozinho: sem esta propriedade o qmldir gerado registra o arquivo como tipo comum, e todo
# acesso (Theme.mSurface) resolve para `undefined` SEM erro de compilacao nem de runtime.
# Verificado empiricamente em 2026-08-27 no Qt 6.10.3.
set_source_files_properties(src/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(src/Icons.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appmelodia
    URI Melodia.App
    VERSION 1.0
    QML_FILES
        src/Main.qml
        src/Theme.qml
        src/Icons.qml
        src/IconButton.qml
        src/IconRail.qml
        src/MelodiaButton.qml
        src/TrackRow.qml
        src/NowPlayingPanel.qml
        src/LibraryPane.qml
        src/Chip.qml
        src/FilterChips.qml
        src/SearchOverlay.qml
        src/PodcastPane.qml
        src/EmptyPane.qml
        src/LibraryEmptyState.qml
        src/Sidebar.qml
        src/SidebarItem.qml
        src/SearchField.qml
        src/QueuePanel.qml
        src/CollectionsSection.qml
        src/NewCollectionDialog.qml
        src/TagChip.qml
        src/TagEditor.qml
        src/EpisodeRow.qml
        src/SpeedControl.qml
        src/SubscribeDialog.qml
        src/FeedStatusRow.qml
        src/AddFromLinkDialog.qml
        src/DownloadProgressRow.qml
        src/SourceBadge.qml
    RESOURCES
        assets/fonts/noctalia-tabler-icons.ttf
    SOURCES
        src/colorschemeprovider.h
        src/colorschemeprovider.cpp
        src/audioengine.h
        src/audioengine.cpp
        src/database.h
        src/database.cpp
        src/covercache.h
        src/covercache.cpp
        src/tracklistmodel.h
        src/tracklistmodel.cpp
        src/librarybrowser.h
        src/librarybrowser.cpp
        src/playstatsrecorder.h
        src/playstatsrecorder.cpp
        src/collectionmanager.h
        src/collectionmanager.cpp
        src/podcastlibrary.h
        src/podcastlibrary.cpp
        src/podcastepisodemodel.h
        src/podcastepisodemodel.cpp
        src/podcastfeedfetcher.h
        src/podcastfeedfetcher.cpp
        src/episodedownloader.h
        src/episodedownloader.cpp
        src/ytdlpdownloader.h
        src/ytdlpdownloader.cpp
)

# O baixador do YouTube e um programa EXTERNO: nao ha find_package(yt-dlp) aqui de proposito,
# e nao pode haver. O app chama por QProcess o yt-dlp que ja estiver instalado na maquina do
# usuario; embutir ou exigir o yt-dlp no build o traria para dentro do pacote publicado, que e
# exatamente o risco que o spec manda evitar. Se um dia aparecer uma dependencia de build com
# esse nome, a decisao do spec foi revertida sem querer.
#
# OBRIGATORIO: sem isto o build quebra com erros de template que nao apontam a causa.
target_include_directories(appmelodia PRIVATE src)

target_link_libraries(appmelodia PRIVATE
    Qt6::Concurrent Qt6::Core Qt6::Network Qt6::Qml Qt6::Quick Qt6::QuickControls2
    Qt6::QuickDialogs2 Qt6::Sql
    PkgConfig::MPV PkgConfig::TAGLIB)

enable_testing()
add_subdirectory(tests)
