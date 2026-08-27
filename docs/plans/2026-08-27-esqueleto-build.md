---
slug: esqueleto-build
feature: melodia
status: aprovado
depende-de: []
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Plano: esqueleto-build

**Goal:** O projeto compila e abre uma janela Qt6/QML com a estética do Noctalia — paleta
lida do `colors.json` do usuário, tipografia Inter, ícones Tabler, tokens de forma e
movimento. A janela ainda não faz nada além de existir com a cara certa.

**Arquitetura:** Um único módulo QML (`Melodia.App`) declarado por `qt_add_qml_module` sobre
`qt_add_executable`. Todo arquivo C++ e QML mora em `src/` **plano** (sem subpastas) — decisão
deliberada: `qt_add_qml_module` gera `appmelodia_qmltyperegistrations.cpp` que inclui headers
pelo nome puro em `<>`, e subpastas exigiriam um `target_include_directories` por pasta,
multiplicando a chance do erro descrito na Task 1. A paleta vem de uma classe C++
(`ColorSchemeProvider`) que lê o JSON do Noctalia com `QFileSystemWatcher`, e um singleton QML
(`Theme`) que a repassa junto com os tokens literais de tipografia/forma/movimento.

**Constraints globais:** Qt 6.10.3, C++20, CMake ≥ 3.21, Ninja, gcc 15.3.1, Fedora 43.
O app **precisa rodar sem o Noctalia instalado** (spec §Decisões: Windows depois) — toda cor
tem fallback embutido. Nenhuma dependência de Quickshell: ele é Wayland/Linux-only e está
fora por causa do requisito Windows (spec §Decisões, verbatim: "Quickshell (o do Noctalia) é
Wayland/Linux-only — não existe port").

**Research:** `docs/plans/research/2026-08-27-noctalia-visual.md` e
`docs/plans/research/2026-08-27-qt-ponte.md`.

## Arquivos

- Criar: `CMakeLists.txt` · `.gitignore` · `README.md`
- Criar: `src/main.cpp` · `src/colorschemeprovider.h` · `src/colorschemeprovider.cpp`
- Criar: `src/Theme.qml` · `src/Icons.qml` · `src/Main.qml`
- Criar: `assets/fonts/noctalia-tabler-icons.ttf` · `assets/fonts/tabler-icons-license.txt`
- Criar: `tests/CMakeLists.txt` · `tests/tst_colorscheme.cpp`
- Modificar: nenhum (repo tem só o spec e o research)
- Testar: `tests/tst_colorscheme.cpp`

## Interfaces

- **Consome:** nada (fatia folha).
- **Produz** — todas as fatias seguintes dependem destas assinaturas verbatim:
  - Módulo QML de URI `Melodia.App`, versão `1.0`. Todo QML de outra fatia começa com
    `import Melodia.App`.
  - Singleton QML `Theme` (arquivo `src/Theme.qml`), com estas propriedades:
    - cores: `mSurface`, `mOnSurface`, `mSurfaceVariant`, `mOnSurfaceVariant`, `mPrimary`,
      `mOnPrimary`, `mSecondary`, `mOnSecondary`, `mTertiary`, `mOnTertiary`, `mError`,
      `mOnError`, `mOutline`, `mShadow`, `mHover`, `mOnHover` (todas `color`)
    - tipografia: `fontFamily`, `fontFamilyFixed` (`string`); `fontSizeXXS`, `fontSizeXS`,
      `fontSizeS`, `fontSizeM`, `fontSizeL`, `fontSizeXL`, `fontSizeXXL`, `fontSizeXXXL`
      (`real`); `fontWeightRegular`, `fontWeightMedium`, `fontWeightSemiBold`,
      `fontWeightBold` (`int`)
    - forma: `radiusXXS`, `radiusXS`, `radiusS`, `radiusM`, `radiusL`, `iRadiusXS`,
      `iRadiusS`, `iRadiusM`, `borderS`, `borderM`, `borderL` (`int`)
    - espaço: `marginXXS`, `marginXS`, `marginS`, `marginM`, `marginL`, `marginXL` (`int`)
    - movimento: `animationFaster`, `animationFast`, `animationNormal`, `animationSlow`,
      `animationSlowest` (`int`); `easingType` (`int`)
    - `usingNoctalia` (`bool`) — falso quando o `colors.json` não existe (fallback ativo)
  - Singleton QML `Icons` (arquivo `src/Icons.qml`), com:
    - `readonly property string fontFamily` — família da fonte Tabler já carregada
    - `function get(name: string): string` — devolve o caractere PUA do ícone; string vazia
      se o nome não existir no mapa
  - Singleton C++ `ColorSchemeProvider` (registrado por `QML_ELEMENT` + `QML_SINGLETON`,
    header `src/colorschemeprovider.h`), com `Q_PROPERTY` `QColor` para as 16 chaves acima,
    `Q_PROPERTY(bool usingNoctalia READ usingNoctalia NOTIFY colorsChanged)` e o sinal
    `void colorsChanged()`. Consumido só pelo `Theme.qml`; nenhuma outra fatia fala com ele.
  - Alvo CMake do executável: `appmelodia`. Toda fatia que adicionar arquivo C++ acrescenta
    à lista de `qt_add_executable(appmelodia ...)` e, se o tipo for exposto ao QML, também
    ao bloco `SOURCES` de `qt_add_qml_module`.

## Tasks

### Task 1: Esqueleto CMake + janela que abre

O `target_include_directories(appmelodia PRIVATE src)` da última linha **não é opcional**:
sem ele, o `appmelodia_qmltyperegistrations.cpp` gerado falha o `__has_include(<...>)` em
silêncio e o build morre numa cascata de ~15 erros de template que não apontam para a causa.
Armadilha reproduzida no research (`qt-ponte.md` §Armadilha 1).

- [x] Criar `CMakeLists.txt`:

```cmake
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
add_subdirectory(tests)
```

- [x] Criar `src/main.cpp`:

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("melodia"));
    app.setOrganizationName(QStringLiteral("melodia"));

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    engine.loadFromModule("Melodia.App", "Main");

    return app.exec();
}
```

- [x] Criar `src/Main.qml` (placeholder desta task; a Task 4 o substitui):

```qml
import QtQuick
import QtQuick.Window

Window {
    width: 1100
    height: 700
    visible: true
    title: qsTr("melodia")
    color: "#070722"
}
```

- [x] Criar `.gitignore`:

```gitignore
build/
.cache/
compile_commands.json
*.user
```

- [x] verificação mecânica da task: `cmake -B build -G Ninja && cmake --build build` → exit 0
      e o binário existe: `test -x build/appmelodia && echo OK` → `OK`
- [x] commit:

```bash
git add CMakeLists.txt .gitignore src/main.cpp src/Main.qml
git commit -m "feat(build): Qt6 QML skeleton with CMake and empty window"
```

### Task 2: ColorSchemeProvider — a paleta do Noctalia lida em runtime

Lê `~/.config/noctalia/colors.json`. Se o arquivo não existir, estiver ilegível ou parcial,
cada cor cai no valor de fábrica do Noctalia — é isso que faz o app rodar em máquina sem
Noctalia e, depois, no Windows.

- [ ] Criar `src/colorschemeprovider.h`:

```cpp
#pragma once

#include <QColor>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QString>
#include <QtQmlIntegration/qqmlintegration.h>

class ColorSchemeProvider : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QColor mPrimary READ mPrimary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnPrimary READ mOnPrimary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSecondary READ mSecondary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSecondary READ mOnSecondary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mTertiary READ mTertiary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnTertiary READ mOnTertiary NOTIFY colorsChanged)
    Q_PROPERTY(QColor mError READ mError NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnError READ mOnError NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSurface READ mSurface NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSurface READ mOnSurface NOTIFY colorsChanged)
    Q_PROPERTY(QColor mSurfaceVariant READ mSurfaceVariant NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnSurfaceVariant READ mOnSurfaceVariant NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOutline READ mOutline NOTIFY colorsChanged)
    Q_PROPERTY(QColor mShadow READ mShadow NOTIFY colorsChanged)
    Q_PROPERTY(QColor mHover READ mHover NOTIFY colorsChanged)
    Q_PROPERTY(QColor mOnHover READ mOnHover NOTIFY colorsChanged)
    Q_PROPERTY(bool usingNoctalia READ usingNoctalia NOTIFY colorsChanged)

public:
    explicit ColorSchemeProvider(QObject *parent = nullptr);

    // Test seam: pass an explicit path instead of the user's Noctalia config.
    static ColorSchemeProvider *createForPath(const QString &path, QObject *parent = nullptr);

    QColor mPrimary() const { return at(QStringLiteral("mPrimary"), QColor("#fff59b")); }
    QColor mOnPrimary() const { return at(QStringLiteral("mOnPrimary"), QColor("#0e0e43")); }
    QColor mSecondary() const { return at(QStringLiteral("mSecondary"), QColor("#a9aefe")); }
    QColor mOnSecondary() const { return at(QStringLiteral("mOnSecondary"), QColor("#0e0e43")); }
    QColor mTertiary() const { return at(QStringLiteral("mTertiary"), QColor("#9bfece")); }
    QColor mOnTertiary() const { return at(QStringLiteral("mOnTertiary"), QColor("#0e0e43")); }
    QColor mError() const { return at(QStringLiteral("mError"), QColor("#fd4663")); }
    QColor mOnError() const { return at(QStringLiteral("mOnError"), QColor("#0e0e43")); }
    QColor mSurface() const { return at(QStringLiteral("mSurface"), QColor("#070722")); }
    QColor mOnSurface() const { return at(QStringLiteral("mOnSurface"), QColor("#f3edf7")); }
    QColor mSurfaceVariant() const { return at(QStringLiteral("mSurfaceVariant"), QColor("#11112d")); }
    QColor mOnSurfaceVariant() const { return at(QStringLiteral("mOnSurfaceVariant"), QColor("#7c80b4")); }
    QColor mOutline() const { return at(QStringLiteral("mOutline"), QColor("#21215f")); }
    QColor mShadow() const { return at(QStringLiteral("mShadow"), QColor("#070722")); }
    QColor mHover() const { return at(QStringLiteral("mHover"), QColor("#9bfece")); }
    QColor mOnHover() const { return at(QStringLiteral("mOnHover"), QColor("#0e0e43")); }

    bool usingNoctalia() const { return !m_colors.isEmpty(); }

signals:
    void colorsChanged();

private:
    QColor at(const QString &key, const QColor &fallback) const
    {
        return m_colors.value(key, fallback);
    }
    void reload();
    void armWatch();

    QHash<QString, QColor> m_colors;
    QFileSystemWatcher m_watcher;
    QString m_path;
};
```

- [ ] Criar `src/colorschemeprovider.cpp`:

```cpp
#include "colorschemeprovider.h"

#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>

ColorSchemeProvider::ColorSchemeProvider(QObject *parent)
    : ColorSchemeProvider(parent, QDir::homePath() + QStringLiteral("/.config/noctalia/colors.json"))
{
}

ColorSchemeProvider *ColorSchemeProvider::createForPath(const QString &path, QObject *parent)
{
    // Straight to the two-argument constructor: building the default one first would arm the
    // watcher on the user's real Noctalia file before we swap the path.
    return new ColorSchemeProvider(parent, path);
}

void ColorSchemeProvider::armWatch()
{
    if (!m_path.isEmpty() && QFile::exists(m_path) && !m_watcher.files().contains(m_path))
        m_watcher.addPath(m_path);
}

void ColorSchemeProvider::reload()
{
    m_colors.clear();

    QFile f(m_path);
    if (!f.open(QIODevice::ReadOnly))
        return; // no Noctalia (or unreadable): every getter falls back.

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return; // malformed JSON is treated exactly like a missing file.

    const QJsonObject obj = doc.object();
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
        const QColor c(it.value().toString());
        if (c.isValid())
            m_colors.insert(it.key(), c); // partial file: absent keys keep the fallback.
    }
}
```

- [ ] Acrescentar ao fim de `src/colorschemeprovider.cpp` o construtor delegado privado e a
      conexão do watcher (o corpo real do construtor de dois argumentos):

```cpp
// Appended to colorschemeprovider.cpp — the delegating constructor above lands here.
ColorSchemeProvider::ColorSchemeProvider(QObject *parent, const QString &path)
    : QObject(parent), m_path(path)
{
    reload();
    armWatch();
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &) {
        reload();
        emit colorsChanged();
        // Editors replace the file atomically (unlink + rename), which drops the watch.
        armWatch();
    });
}
```

- [ ] Declarar esse construtor no header, na seção `private:`, logo antes de `void reload();`:

```cpp
    ColorSchemeProvider(QObject *parent, const QString &path);
```

- [ ] verificação mecânica da task: `cmake --build build` → exit 0
- [ ] commit:

```bash
git add src/colorschemeprovider.h src/colorschemeprovider.cpp CMakeLists.txt
git commit -m "feat(theme): read Noctalia color scheme with live reload and safe fallback"
```

### Task 3: Theme singleton — os tokens visuais em QML

Valores literais extraídos de `Commons/Style.qml` do Noctalia com todos os ratios em 1.0
(research §2-4). Não portamos o sistema de `radiusRatio`/`uiScaleRatio` configurável: o
melodia não tem UI-scale ajustável nesta versão.

- [ ] Criar `src/Theme.qml`:

```qml
pragma Singleton

import QtQuick
import Melodia.App

QtObject {
    // --- Colors: passthrough from the C++ provider (falls back when Noctalia is absent) ---
    readonly property color mPrimary: ColorSchemeProvider.mPrimary
    readonly property color mOnPrimary: ColorSchemeProvider.mOnPrimary
    readonly property color mSecondary: ColorSchemeProvider.mSecondary
    readonly property color mOnSecondary: ColorSchemeProvider.mOnSecondary
    readonly property color mTertiary: ColorSchemeProvider.mTertiary
    readonly property color mOnTertiary: ColorSchemeProvider.mOnTertiary
    readonly property color mError: ColorSchemeProvider.mError
    readonly property color mOnError: ColorSchemeProvider.mOnError
    readonly property color mSurface: ColorSchemeProvider.mSurface
    readonly property color mOnSurface: ColorSchemeProvider.mOnSurface
    readonly property color mSurfaceVariant: ColorSchemeProvider.mSurfaceVariant
    readonly property color mOnSurfaceVariant: ColorSchemeProvider.mOnSurfaceVariant
    readonly property color mOutline: ColorSchemeProvider.mOutline
    readonly property color mShadow: ColorSchemeProvider.mShadow
    readonly property color mHover: ColorSchemeProvider.mHover
    readonly property color mOnHover: ColorSchemeProvider.mOnHover
    readonly property bool usingNoctalia: ColorSchemeProvider.usingNoctalia

    // --- Typography (Noctalia Style.qml, ratio 1.0) ---
    readonly property string fontFamily: "Inter"
    readonly property string fontFamilyFixed: "JetBrains Mono"
    readonly property real fontSizeXXS: 8
    readonly property real fontSizeXS: 9
    readonly property real fontSizeS: 10
    readonly property real fontSizeM: 11
    readonly property real fontSizeL: 13
    readonly property real fontSizeXL: 16
    readonly property real fontSizeXXL: 18
    readonly property real fontSizeXXXL: 24
    readonly property int fontWeightRegular: 400
    readonly property int fontWeightMedium: 500
    readonly property int fontWeightSemiBold: 600
    readonly property int fontWeightBold: 700

    // --- Shape ---
    readonly property int radiusXXS: 4
    readonly property int radiusXS: 8
    readonly property int radiusS: 12
    readonly property int radiusM: 16
    readonly property int radiusL: 20
    readonly property int iRadiusXS: 8
    readonly property int iRadiusS: 12
    readonly property int iRadiusM: 16
    readonly property int borderS: 1
    readonly property int borderM: 2
    readonly property int borderL: 3

    // --- Spacing ---
    readonly property int marginXXS: 2
    readonly property int marginXS: 4
    readonly property int marginS: 6
    readonly property int marginM: 9
    readonly property int marginL: 13
    readonly property int marginXL: 18

    // --- Motion ---
    readonly property int animationFaster: 75
    readonly property int animationFast: 150
    readonly property int animationNormal: 300
    readonly property int animationSlow: 450
    readonly property int animationSlowest: 750
    readonly property int easingType: Easing.OutCubic
}
```

- [ ] verificação mecânica da task: o qmldir gerado precisa marcar `singleton` — sem isso o
      Theme resolve para `undefined` em silêncio:
      `cmake --build build && grep -h "singleton Theme" build/Melodia/App/qmldir` →
      `singleton Theme 1.0 src/Theme.qml`
- [ ] commit:

```bash
git add src/Theme.qml CMakeLists.txt
git commit -m "feat(theme): expose Noctalia design tokens as a QML singleton"
```

### Task 4: Fonte de ícones Tabler + janela com a cara certa

A fonte é MIT (verificado em `/etc/xdg/quickshell/noctalia-shell/Assets/Fonts/tabler/tabler-icons-license.txt`,
"Tabler Admin Template and Tabler Icons are available under MIT License", Copyright (c)
2018-2025 Tabler) — pode ser redistribuída desde que o arquivo de licença acompanhe.

- [ ] Copiar a fonte e a licença para o repo:

```bash
mkdir -p assets/fonts
cp /etc/xdg/quickshell/noctalia-shell/Assets/Fonts/tabler/noctalia-tabler-icons.ttf assets/fonts/
cp /etc/xdg/quickshell/noctalia-shell/Assets/Fonts/tabler/tabler-icons-license.txt assets/fonts/
```

- [ ] Criar `src/Icons.qml` — só os ícones que um player usa; os codepoints são PUA e só
      renderizam com esta fonte carregada:

```qml
pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property FontLoader loader: FontLoader {
        source: "qrc:/qt/qml/Melodia/App/assets/fonts/noctalia-tabler-icons.ttf"
    }
    readonly property string fontFamily: loader.name

    readonly property var glyphs: ({
        "play": "",
        "pause": "",
        "stop": "",
        "skip-back": "",
        "skip-forward": "",
        "track-next": "",
        "track-prev": "",
        "repeat": "",
        "shuffle": "",
        "volume": "",
        "volume-low": "",
        "volume-off": "",
        "search": "",
        "music": "",
        "disc": "",
        "microphone": "",
        "playlist": "",
        "heart": "",
        "clock": "",
        "star": "",
        "download": "",
        "rss": "",
        "settings": "",
        "close": "",
        "plus": "",
        "more": "",
        "chevron-right": "",
        "chevron-left": "",
        "folder": "",
        "tags": "",
        "list": "",
        "history": ""
    })

    function get(name) {
        return glyphs[name] !== undefined ? glyphs[name] : ""
    }
}
```

- [ ] Substituir `src/Main.qml` pela janela com a estética aplicada:

```qml
import QtQuick
import QtQuick.Window
import Melodia.App

Window {
    id: root
    width: 1100
    height: 700
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    title: qsTr("melodia")
    color: Theme.mSurface

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.marginXL
        radius: Theme.radiusM
        color: Theme.mSurfaceVariant
        border.width: Theme.borderS
        border.color: Theme.mOutline

        Behavior on color {
            ColorAnimation { duration: Theme.animationSlowest; easing.type: Theme.easingType }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.marginM

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.get("music")
                font.family: Icons.fontFamily
                font.pointSize: Theme.fontSizeXXXL
                color: Theme.mPrimary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("melodia")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeXXL
                font.weight: Theme.fontWeightSemiBold
                color: Theme.mOnSurface
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Theme.usingNoctalia ? qsTr("paleta do Noctalia") : qsTr("paleta padrão")
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSizeS
                color: Theme.mOnSurfaceVariant
            }
        }
    }
}
```

- [ ] verificação mecânica da task: a fonte precisa estar embutida no binário —
      `cmake --build build && strings build/appmelodia | grep -c "noctalia-tabler-icons.ttf"`
      → número maior que `0`
- [ ] commit:

```bash
git add assets/fonts src/Icons.qml src/Main.qml CMakeLists.txt
git commit -m "feat(theme): load Tabler icon font and apply Noctalia look to the window"
```

### Task 5: Teste automatizado do fallback de paleta

Prova que o app não quebra sem Noctalia — o cenário do Windows e o de qualquer outra máquina.

- [ ] Criar `tests/CMakeLists.txt`:

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Test)

qt_add_executable(tst_colorscheme
    tst_colorscheme.cpp
    ../src/colorschemeprovider.h
    ../src/colorschemeprovider.cpp
)
target_include_directories(tst_colorscheme PRIVATE ../src)
target_link_libraries(tst_colorscheme PRIVATE Qt6::Core Qt6::Test Qt6::Qml)

add_test(NAME tst_colorscheme COMMAND tst_colorscheme)
set_tests_properties(tst_colorscheme PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
```

- [ ] Criar `tests/tst_colorscheme.cpp`:

```cpp
#include <QtTest/QtTest>
#include <QTemporaryDir>
#include <QFile>

#include "colorschemeprovider.h"

class TstColorScheme : public QObject
{
    Q_OBJECT

private slots:
    void missingFileFallsBackToNoctaliaDefaults()
    {
        QScopedPointer<ColorSchemeProvider> p(
            ColorSchemeProvider::createForPath(QStringLiteral("/nonexistent/colors.json")));
        QCOMPARE(p->usingNoctalia(), false);
        QCOMPARE(p->mSurface(), QColor("#070722"));
        QCOMPARE(p->mPrimary(), QColor("#fff59b"));
    }

    void validFileOverridesDefaults()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("colors.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(R"({"mSurface": "#111111", "mPrimary": "#aaaaaa"})");
        f.close();

        QScopedPointer<ColorSchemeProvider> p(ColorSchemeProvider::createForPath(path));
        QCOMPARE(p->usingNoctalia(), true);
        QCOMPARE(p->mSurface(), QColor("#111111"));
        QCOMPARE(p->mPrimary(), QColor("#aaaaaa"));
        // Key absent from the file must still fall back, not become invalid.
        QCOMPARE(p->mOnSurface(), QColor("#f3edf7"));
    }

    void malformedJsonIsTreatedAsMissing()
    {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("colors.json"));
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("{ this is not json");
        f.close();

        QScopedPointer<ColorSchemeProvider> p(ColorSchemeProvider::createForPath(path));
        QCOMPARE(p->usingNoctalia(), false);
        QCOMPARE(p->mSurface(), QColor("#070722"));
    }
};

QTEST_MAIN(TstColorScheme)
#include "tst_colorscheme.moc"
```

- [ ] verificação mecânica da task:
      `cmake --build build && ctest --test-dir build --output-on-failure` → `100% tests passed`
- [ ] commit:

```bash
git add tests/ CMakeLists.txt
git commit -m "test(theme): cover color scheme fallback for missing and malformed files"
```

### Task 6: Modo de desenvolvimento e README [sem-código]

Sem isto, cada ajuste de aparência custa um `cmake --build` — e a aparência é o requisito nº 1
do produto (spec §Pra quê: "Player feio não se abre").

- [ ] Acrescentar a `src/main.cpp`, dentro de `main()` e antes de `engine.loadFromModule(...)`,
      o bloco de modo dev, e trocar a chamada de carga por um `if/else` — o código está na
      seção 7 de `docs/plans/research/2026-08-27-qt-ponte.md` (variável de ambiente
      `MELODIA_DEV_QML`, `QFileSystemWatcher` + `engine.clearComponentCache()`).
- [ ] Criar `README.md` documentando: dependências (`qt6-qtbase-devel qt6-qtdeclarative-devel`),
      comandos de build e teste, a variável `MELODIA_DEV_QML`, e a linha de debug obrigatória
      nesta máquina — `QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/appmelodia`
      — porque o Fedora instala `/usr/share/qt6/qtlogging.ini` com `*.debug=false` e manda o
      resto para o journald, fazendo todo `qDebug`/`console.log` sumir sem erro.
- [ ] Registrar no README a licença MIT da fonte Tabler, apontando `assets/fonts/tabler-icons-license.txt`.
- [ ] verificação mecânica da task:
      `grep -c "MELODIA_DEV_QML" README.md src/main.cpp` → `README.md:1` e `src/main.cpp:2` ou mais
- [ ] commit:

```bash
git add README.md src/main.cpp
git commit -m "docs: build, test and QML dev-mode instructions"
```

## Verificação da fatia (E2E)

- `cmake -B build -G Ninja && cmake --build build` → exit 0
- `ctest --test-dir build --output-on-failure` → `100% tests passed`
- `grep -h "singleton Theme" build/Melodia/App/qmldir` → `singleton Theme 1.0 src/Theme.qml`
- `grep -h "singleton Icons" build/Melodia/App/qmldir` → `singleton Icons 1.0 src/Icons.qml`
- `QT_QPA_PLATFORM=offscreen timeout 10 ./build/appmelodia & sleep 3; kill %1` → sem erro de
  QML no stderr (nenhuma linha contendo `is not a type`, `Unable to assign` ou `undefined`)
- **Decisão humana:** o Pedro roda `./build/appmelodia` numa sessão gráfica e confirma que a
  janela abre com a paleta dele. Sem esse OK a fatia não é dada por concluída — a aparência é
  o requisito nº 1 do produto e nenhum teste automatizado a valida.

## Fora de escopo

- Qualquer reprodução de áudio (fatia `motor-audio`).
- Qualquer leitura de arquivo de música ou banco de dados (fatia `scan-biblioteca`).
- Componentes de UI reutilizáveis (botão, lista, slider) — nascem na fatia `tocador-ui`,
  quando houver uma tela real que os use. Criar uma biblioteca de componentes antes disso é
  inventar requisito.
- UI-scale configurável pelo usuário (o Noctalia tem; o melodia fixa ratio 1.0).
- Ícone da aplicação, `.desktop` file, empacotamento — o spec exclui instalador
  ("GitHub aberto, sem instalador nem suporte").
