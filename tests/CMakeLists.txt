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
