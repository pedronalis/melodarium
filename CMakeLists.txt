cmake_minimum_required(VERSION 3.21)
project(melodia LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appmelodia
    src/main.cpp
)

qt_add_qml_module(appmelodia
    URI Melodia.App
    VERSION 1.0
    QML_FILES
        src/Main.qml
)

# OBRIGATORIO: sem isto o build quebra com erros de template que nao apontam a causa.
target_include_directories(appmelodia PRIVATE src)

target_link_libraries(appmelodia PRIVATE Qt6::Core Qt6::Quick)

enable_testing()
