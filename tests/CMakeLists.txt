# Gui is required for QColor, which colorschemeprovider.h exposes.
find_package(Qt6 REQUIRED COMPONENTS Concurrent Core Gui Network Test)

qt_add_executable(tst_colorscheme
    tst_colorscheme.cpp
    ../src/colorschemeprovider.h
    ../src/colorschemeprovider.cpp
)
target_include_directories(tst_colorscheme PRIVATE ../src)
target_link_libraries(tst_colorscheme PRIVATE Qt6::Core Qt6::Gui Qt6::Test Qt6::Qml)

add_test(NAME tst_colorscheme COMMAND tst_colorscheme)
set_tests_properties(tst_colorscheme PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_audioengine
    tst_audioengine.cpp
    ../src/audioengine.h
    ../src/audioengine.cpp
)
target_include_directories(tst_audioengine PRIVATE ../src)
target_link_libraries(tst_audioengine PRIVATE Qt6::Core Qt6::Test Qt6::Qml PkgConfig::MPV)

add_test(NAME tst_audioengine COMMAND tst_audioengine)
set_tests_properties(tst_audioengine PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 60)

add_test(NAME tst_audio_preferences
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-audio-preferences.sh")
set_tests_properties(tst_audio_preferences PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_data_paths
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-data-paths.sh")
set_tests_properties(tst_data_paths PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_legacy_migration
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-legacy-migration.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_legacy_migration PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

qt_add_executable(tst_library
    tst_library.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
)
target_include_directories(tst_library PRIVATE ../src)
target_link_libraries(tst_library PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_library COMMAND tst_library)
set_tests_properties(tst_library PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 120)

qt_add_executable(tst_tracklistmodel
    tst_tracklistmodel.cpp
    ../src/tracklistmodel.h ../src/tracklistmodel.cpp
    ../src/covercache.h ../src/covercache.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
)
target_include_directories(tst_tracklistmodel PRIVATE ../src)
target_link_libraries(tst_tracklistmodel PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB PkgConfig::MPV)

add_test(NAME tst_tracklistmodel COMMAND tst_tracklistmodel)
set_tests_properties(tst_tracklistmodel PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_librarybrowser
    tst_librarybrowser.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/librarybrowser.h ../src/librarybrowser.cpp
    ../src/playstatsrecorder.h ../src/playstatsrecorder.cpp
    ../src/tracklistmodel.h ../src/tracklistmodel.cpp
    ../src/covercache.h ../src/covercache.cpp
)
target_include_directories(tst_librarybrowser PRIVATE ../src)
target_link_libraries(tst_librarybrowser PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_librarybrowser COMMAND tst_librarybrowser)
set_tests_properties(tst_librarybrowser PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_collections
    tst_collections.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/librarybrowser.h ../src/librarybrowser.cpp
    ../src/collectionmanager.h ../src/collectionmanager.cpp
)
target_include_directories(tst_collections PRIVATE ../src)
target_link_libraries(tst_collections PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_collections COMMAND tst_collections)
set_tests_properties(tst_collections PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_podcast
    tst_podcast.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/podcastlibrary.h ../src/podcastlibrary.cpp
    ../src/podcastepisodemodel.h ../src/podcastepisodemodel.cpp
    ../src/podcastfeedfetcher.h ../src/podcastfeedfetcher.cpp
    ../src/episodedownloader.h ../src/episodedownloader.cpp
)
target_include_directories(tst_podcast PRIVATE ../src)
target_link_libraries(tst_podcast PRIVATE
    Qt6::Concurrent Qt6::Core Qt6::Network Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_podcast COMMAND tst_podcast)
set_tests_properties(tst_podcast PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_feedparser
    tst_feedparser.cpp
    ../src/podcastfeedfetcher.h ../src/podcastfeedfetcher.cpp
)
target_include_directories(tst_feedparser PRIVATE ../src)
target_link_libraries(tst_feedparser PRIVATE Qt6::Core Qt6::Test Qt6::Network)

add_test(NAME tst_feedparser COMMAND tst_feedparser)
set_tests_properties(tst_feedparser PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_ytdlp
    tst_ytdlp.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/librarybrowser.h ../src/librarybrowser.cpp
    ../src/collectionmanager.h ../src/collectionmanager.cpp
    ../src/ytdlpdownloader.h ../src/ytdlpdownloader.cpp
)
target_include_directories(tst_ytdlp PRIVATE ../src)
target_link_libraries(tst_ytdlp PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_ytdlp COMMAND tst_ytdlp)
set_tests_properties(tst_ytdlp PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 60)

qt_add_executable(tst_folderbrowser
    tst_folderbrowser.cpp
    ../src/folderbrowser.h ../src/folderbrowser.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/database.h ../src/database.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/tagreader.h ../src/tagreader.cpp
)
target_include_directories(tst_folderbrowser PRIVATE ../src)
target_link_libraries(tst_folderbrowser PRIVATE
    Qt6::Concurrent Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_folderbrowser COMMAND tst_folderbrowser)
set_tests_properties(tst_folderbrowser PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_librarywatcher
    tst_librarywatcher.cpp
    ../src/librarywatcher.h ../src/librarywatcher.cpp
    ../src/database.h ../src/database.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/tagreader.h ../src/tagreader.cpp
)
target_include_directories(tst_librarywatcher PRIVATE ../src)
target_link_libraries(tst_librarywatcher PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_librarywatcher COMMAND tst_librarywatcher)
set_tests_properties(tst_librarywatcher PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_dominantcolor
    tst_dominantcolor.cpp
    ../src/dominantcolor.h ../src/dominantcolor.cpp
)
target_include_directories(tst_dominantcolor PRIVATE ../src)
target_link_libraries(tst_dominantcolor PRIVATE Qt6::Core Qt6::Gui Qt6::Test)

add_test(NAME tst_dominantcolor COMMAND tst_dominantcolor)
set_tests_properties(tst_dominantcolor PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_roundedimage
    tst_roundedimage.cpp
    ../src/roundedimage.h ../src/roundedimage.cpp
    ../src/dominantcolor.h ../src/dominantcolor.cpp
)
target_include_directories(tst_roundedimage PRIVATE ../src)
target_link_libraries(tst_roundedimage PRIVATE Qt6::Core Qt6::Gui Qt6::Quick Qt6::Test)

add_test(NAME tst_roundedimage COMMAND tst_roundedimage)
set_tests_properties(tst_roundedimage PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(tst_gradientblock
    tst_gradientblock.cpp
    ../src/gradientblock.h ../src/gradientblock.cpp
)
target_include_directories(tst_gradientblock PRIVATE ../src)
target_link_libraries(tst_gradientblock PRIVATE Qt6::Core Qt6::Gui Qt6::Quick Qt6::Test)

add_test(NAME tst_gradientblock COMMAND tst_gradientblock)
set_tests_properties(tst_gradientblock PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

add_test(NAME tst_resize_shadow
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-resize-shadow.sh")
set_tests_properties(tst_resize_shadow PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_halo_intensity
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-halo-intensity.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_halo_intensity PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_halo_activity
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-halo-activity.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_halo_activity PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_search_covers
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-search-covers.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_search_covers PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_cover_crossfade
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-cover-crossfade.sh")
set_tests_properties(tst_cover_crossfade PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_cover_switch
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-cover-switch.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_cover_switch PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_resume_queue
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-resume-queue.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_resume_queue PROPERTIES WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}")

add_test(NAME tst_contextual_ui
    COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-contextual-ui.sh" "$<TARGET_FILE:melodarium>")
set_tests_properties(tst_contextual_ui PROPERTIES
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    TIMEOUT 90)

if(TARGET Qt6::DBus)
    add_test(NAME tst_mpris
        COMMAND bash "${CMAKE_SOURCE_DIR}/tools/check-mpris.sh" "$<TARGET_FILE:melodarium>")
    set_tests_properties(tst_mpris PROPERTIES
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        TIMEOUT 60)
endif()

qt_add_executable(tst_covercache
    tst_covercache.cpp
    ../src/covercache.h ../src/covercache.cpp
    ../src/tagreader.h ../src/tagreader.cpp
)
target_include_directories(tst_covercache PRIVATE ../src)
target_link_libraries(tst_covercache PRIVATE
    Qt6::Concurrent Qt6::Core Qt6::Gui Qt6::Test PkgConfig::TAGLIB)

add_test(NAME tst_covercache COMMAND tst_covercache)
set_tests_properties(tst_covercache PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
