cmake_minimum_required(VERSION 3.21)
project(melodia LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appmelodia
    src/main.cpp
    src/colorschemeprovider.h
    src/colorschemeprovider.cpp
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
    RESOURCES
        assets/fonts/noctalia-tabler-icons.ttf
    SOURCES
        src/colorschemeprovider.h
        src/colorschemeprovider.cpp
)

# OBRIGATORIO: sem isto o build quebra com erros de template que nao apontam a causa.
target_include_directories(appmelodia PRIVATE src)

target_link_libraries(appmelodia PRIVATE Qt6::Core Qt6::Quick)

enable_testing()
