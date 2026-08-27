# Gui is required for QColor, which colorschemeprovider.h exposes.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Test)

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

qt_add_executable(tst_library
    tst_library.cpp
    ../src/database.h ../src/database.cpp
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
    ../src/tagreader.h ../src/tagreader.cpp
    ../src/libraryscanner.h ../src/libraryscanner.cpp
    ../src/librarybrowser.h ../src/librarybrowser.cpp
    ../src/playstatsrecorder.h ../src/playstatsrecorder.cpp
)
target_include_directories(tst_librarybrowser PRIVATE ../src)
target_link_libraries(tst_librarybrowser PRIVATE
    Qt6::Core Qt6::Test Qt6::Qml Qt6::Sql PkgConfig::TAGLIB)

add_test(NAME tst_librarybrowser COMMAND tst_librarybrowser)
set_tests_properties(tst_librarybrowser PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
