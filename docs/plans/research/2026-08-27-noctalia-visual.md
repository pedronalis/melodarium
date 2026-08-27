# Research: a "cara" do Noctalia traduzida para Qt6/QML puro

Fonte: `/etc/xdg/quickshell/noctalia-shell` (418 arquivos QML). Todos os números e trechos
abaixo foram lidos direto dos arquivos citados — sem inventar API. Onde não pude confirmar,
marquei **NAO VERIFICADO**.

---

## 1. Mapa de cor (16 chaves)

Fonte: `Commons/Color.qml` (valores default, linhas 399-421) + uso real em
`Widgets/NButton.qml`, `Widgets/NTabButton.qml`, `Widgets/NSlider.qml`, `Widgets/NBox.qml`,
`Modules/Tooltip/Tooltip.qml`, `Modules/MainScreen/Backgrounds/PanelBackground.qml`.

| Chave               | Hex default (dark)           | Papel real observado no código                                                                                                                                                                         |
| ------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `mSurface`          | `#070722`                    | Fundo de janela/painel (`PanelBackground.defaultBackgroundColor`), fundo de trilho de slider, cor do "cutout"/knob do slider, fundo de tooltip (`Tooltip.qml:645`)                                     |
| `mOnSurface`        | `#f3edf7`                    | Texto principal — cor default de `NText` (`NText.qml:28`) e de `NIcon` (`NIcon.qml:27`); texto de tab não-selecionada                                                                                  |
| `mSurfaceVariant`   | `#11112d`                    | Fundo de "card"/grupo (`NBox.color` default, linha 11) — um tom acima do fundo de janela; cor de gradiente de máscara de scroll em listas                                                              |
| `mOnSurfaceVariant` | `#7c80b4`                    | Texto secundário/apagado — usado como cor de texto em tooltip (linhas 662, 686) e como cor de conteúdo quando um botão está desabilitado (`NButton.qml:36`)                                            |
| `mPrimary`          | `#fff59b` (amarelo)          | Cor de destaque/marca — fundo de botão default (`NButton.backgroundColor`), fundo de tab selecionada, cor de preenchimento de slider. **Em um player: a cor do que está tocando agora / estado ativo** |
| `mOnPrimary`        | `#0e0e43` (azul quase-preto) | Texto/ícone sobre `mPrimary` — texto de botão default, texto de tab selecionada                                                                                                                        |
| `mSecondary`        | `#a9aefe` (lilás)            | Acento secundário (menos usado nos widgets-base lidos; aparece em paletas de cor alternativas) — **NAO VERIFICADO** um uso de widget-base específico além da paleta                                    |
| `mOnSecondary`      | `#0e0e43`                    | Texto sobre `mSecondary`                                                                                                                                                                               |
| `mTertiary`         | `#9BFECE` (verde-água)       | Terceiro acento; também é o valor default de `mHover` na paleta (mesma cor, coincidência de paleta, não de papel)                                                                                      |
| `mOnTertiary`       | `#0e0e43`                    | Texto sobre `mTertiary`                                                                                                                                                                                |
| `mError`            | `#FD4663` (vermelho)         | Estado de erro/perigo — resolvido via `Color.resolveColorKey("error")`; usado em toasts de erro                                                                                                        |
| `mOnError`          | `#0e0e43`                    | Texto sobre `mError`                                                                                                                                                                                   |
| `mOutline`          | `#21215F`                    | Borda — borda de botão outlined desabilitado (`NButton.qml:74`), borda de trilho de slider (`Qt.alpha(Color.mOutline, 0.5)`), borda de tooltip, borda de tab não-selecionada                           |
| `mShadow`           | `#070722`                    | Cor de sombra (mesma tonalidade do fundo — sombra "escura profunda", não preto puro)                                                                                                                   |
| `mHover`            | `#9BFECE`                    | Cor de fundo/traço em estado hover — fundo de botão em hover (`NButton.qml:66`), cor de knob de slider pressionado, cor da alça de scrollbar (`NListView.qml:9`, com alpha 0.8)                        |
| `mOnHover`          | `#0e0e43`                    | Texto/ícone sobre estado hover — texto de tab em hover, texto de botão em hover                                                                                                                        |

**Leitura prática para o player:** fundo de janela = `mSurface`; fundo de card/lista =
`mSurfaceVariant`; texto principal = `mOnSurface`; texto secundário (artista, metadados) =
`mOnSurfaceVariant`; cor da faixa tocando agora / botão play ativo = `mPrimary` +
`mOnPrimary` para o conteúdo por cima; hover de item de lista = `mHover`/`mOnHover`; borda de
card/separador = `mOutline`.

Todas as 16 propriedades em `Color.qml` têm `Behavior on <cor> { ColorAnimation { duration:
Style.animationSlowest; easing.type: Easing.OutCubic } }` — a troca de tema/paleta é
animada (750ms/`animationSpeed`), não instantânea.

---

## 2. Tipografia

Fonte: `Commons/Style.qml` (linhas 11-24), `Widgets/NText.qml`, `Commons/Settings.qml`
(linhas 355-358, 87-88), config viva do usuário em `~/.config/noctalia/settings.json`.

- **Família confirmada:** `Settings.data.ui.fontDefault` no config do usuário é literalmente
  `"Inter"` (não é hardcoded no shell — o default de fábrica em `Settings.qml:87` é
  `Qt.application.font.family`, ou seja, a fonte do sistema; **quem fixa Inter é o usuário**).
  Fonte de largura fixa: `"JetBrains Mono"` (`fontFixed`, linha 88 default é `"monospace"`,
  mas o usuário sobrescreveu). Ambas instaladas em `/usr/share/fonts/rsms-inter-fonts/` e
  `/usr/share/fonts/rsms-inter-vf-fonts/` (Inter Variable também presente).
- **Escala de tamanho (pt, literal do `Style.qml`):**
  `fontSizeXXS=8, fontSizeXS=9, fontSizeS=10, fontSizeM=11, fontSizeL=13, fontSizeXL=16,
fontSizeXXL=18, fontSizeXXXL=24`
- **Pesos:** `fontWeightRegular=400, fontWeightMedium=500, fontWeightSemiBold=600,
fontWeightBold=700`. `NText` usa `Style.fontWeightMedium` (500) como peso base do corpo de
  texto; botões (`NButton`) usam `Style.fontWeightSemiBold` (600) para o rótulo.
- **Escala aplicada:** todo tamanho de fonte é multiplicado por `Style.uiScaleRatio`
  (`Settings.data.general.scaleRatio`, default `1.0`) e por um fator próprio
  (`fontDefaultScale`/`fontFixedScale`, no config do usuário `0.95` para Inter, `1.0` para
  o monoespaçado) — ver `NText.qml:14-20`.
- Onde cada tamanho aparece: `fontSizeM` (11) é o corpo padrão de `NButton`/texto de UI geral;
  `fontSizeL` (13) aparece em ícones de botão (`iconSize` default) e tabs; `fontSizeS` (10) em
  tooltips; `fontSizeXXXL` (24) em títulos grandes (relógio, cabeçalhos) — **NAO VERIFICADO**
  caso-a-caso além do que os arquivos lidos mostram (Style.qml não documenta "onde", isso é
  inferido do uso nos widgets lidos).

---

## 3. Forma e ritmo

Fonte: `Commons/Style.qml` linhas 26-65, 78-83, 97-99.

- **Raios de contêiner** (cards/painéis, multiplicados por `radiusRatio`, default 1.0):
  `radiusXXXS=3, radiusXXS=4, radiusXS=8, radiusS=12, radiusM=16, radiusL=20`.
  `NBox` (card) usa `radius: Style.radiusM` (16).
- **Raios de elemento interativo** (multiplicados por `iRadiusRatio`, default 1.0):
  `iRadiusXXXS=3, iRadiusXXS=4, iRadiusXS=8, iRadiusS=12, iRadiusM=16, iRadiusL=20`.
  `NButton` usa `iRadiusS` (12) como raio padrão de botão.
- **Raio de tela/janela:** `screenRadius = round(20 * screenRadiusRatio)`.
- **Bordas** (multiplicadas por `uiScaleRatio`): `borderS = max(1, round(1*ratio))`,
  `borderM = max(1, round(2*ratio))`, `borderL = max(1, round(3*ratio))`. Com ratio 1.0:
  1px / 2px / 3px. `NButton` outlined usa `borderS`; knob de slider usa `borderL` (3px).
- **Espaçamentos** (multiplicados por `uiScaleRatio`):
  `marginXXXS=1, marginXXS=2, marginXS=4, marginS=6, marginM=9, marginL=13, marginXL=18`.
  Existem versões "double" (`margin2*` = o dobro) só para dimensionar contêineres.
- **Escala de UI global:** `uiScaleRatio = Settings.data.general.scaleRatio` (default `1.0`) —
  um único fator que escala bordas e espaçamentos (mas não os raios, que têm seus próprios
  `radiusRatio`/`iRadiusRatio` independentes).
- **Sombra:** `shadowOpacity=0.85, shadowBlur=1.0, shadowBlurMax=22`; offset configurável
  (`shadowOffsetX` default `2`, `shadowOffsetY` default `3`). Cor da sombra = `mShadow`.
  **NAO VERIFICADO** qual `QtQuick.Effects` component real aplica isso (não abri o
  consumidor da sombra) — para Qt6 puro, o equivalente é `MultiEffect { shadowEnabled: true,
shadowColor, shadowBlur, shadowHorizontalOffset, shadowVerticalOffset }` do módulo
  `QtQuick.Effects` (já disponível, `qt6-qtdeclarative-devel` está instalado).

---

## 4. Movimento

Fonte: `Style.qml` linhas 85-95.

- **Durações (ms)**, todas divididas por `Settings.data.general.animationSpeed` (default 1.0)
  e zeradas se `animationDisabled` ou modo de performance ativo:
  `animationFaster=75, animationFast=150, animationNormal=300, animationSlow=450,
animationSlowest=750`.
- **Curva:** `Easing.OutCubic` é a curva usada em praticamente toda `Behavior on color`/
  `ColorAnimation` observada (`NButton`, `NTabButton`, transições de cor em `Color.qml`).
  Scroll suave em listas usa a mesma curva (`NListView.qml:259`).
- **Delays:** `tooltipDelay=300ms`, `tooltipDelayLong=1200ms`, `pillDelay=500ms`.
- Padrão de uso: cor muda com `Behavior on color { ColorAnimation { duration:
Style.animationFast; easing.type: Easing.OutCubic } }` — hover/seleção reagem em 150ms;
  transição de paleta inteira (troca de tema) usa `animationSlowest` (750ms).

---

## 5. Ícones Tabler

Fonte: `Commons/Icons.qml`, `Commons/IconsTabler.qml` (6204 linhas), `Widgets/NIcon.qml`.

- **É uma fonte de ícone** (glyph font), não SVG em disco por ícone. Arquivo real:
  `Assets/Fonts/tabler/noctalia-tabler-icons.ttf` (existe em disco, confirmado com `find`).
  Licença ao lado: `Assets/Fonts/tabler/tabler-icons-license.txt`.
- **Mecanismo de resolução** (`Icons.qml`):
  1. `IconsTabler.icons` é um objeto JS gigante `{ "nome-do-icone": "\u{codepoint}", ... }`
     (ex.: `"user": "\u{eb4d}"`, `"volume-2": "\u{eb4f}"`) — mapa nome→char Unicode na PUA.
  2. `IconsTabler.aliases` é um segundo mapa que traduz nomes semânticos do próprio Noctalia
     (ex.: `"media-play"`) para o nome real do ícone Tabler (`"player-play-filled"`).
  3. `Icons.get(iconName)`: resolve alias primeiro, depois busca em `icons`; devolve o
     caractere Unicode pronto para render.
  4. `Icons.qml` carrega a fonte via **`FontLoader`** dinâmico
     (`currentFontLoader`, propriedade `name` exposta como `Icons.fontFamily`) com uma
     técnica de "cache busting" (`Quickshell.shellDir + fontPath + "?v=" + fontVersion`) —
     a parte de cache-busting é específica de Quickshell/dev-reload, **não precisa ser
     copiada**.
  5. `Widgets/NIcon.qml` é só um `Text` com `font.family: Icons.fontFamily`,
     `text: Icons.get(icon)`, cor default `Color.mOnSurface`.

- **O que um app Qt6 puro precisa fazer** (equivalente exato, sem Quickshell):
  1. Copiar o arquivo `noctalia-tabler-icons.ttf` para os assets do app (respeitar a licença
     do arquivo `.txt` ao lado — **checar os termos antes de redistribuir**, não lida aqui).
  2. Carregar com `FontLoader { id: tablerFont; source: "qrc:/fonts/noctalia-tabler-icons.ttf" }`
     (ou `file://` local) — `FontLoader` é tipo QML padrão de `QtQuick`, existe em Qt6 puro
     sem Quickshell.
  3. Um `Text { font.family: tablerFont.name; text: "\u{eb4d}" }` renderiza o ícone.
  4. Portar (ou reduzir) o mapa `icons`/`aliases` de `IconsTabler.qml` para um `pragma
Singleton` próprio do melodia — é puro JS/QML, nenhuma API de Quickshell nele.

---

## 6. Fronteira Quickshell → substituto exato em Qt6 puro

Confirmado por grep em `Commons/*.qml` e `Modules/Tooltip/Tooltip.qml`:

| Construção Quickshell (usada no Noctalia)                                                                                                          | Onde aparece                                                                 | Substituto em Qt6/QML puro                                                                                                                                                                                                                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pragma Singleton` + `qmldir`                                                                                                                      | Todo `Commons/*.qml` (`Style`, `Color`, `Icons`...)                          | **Igual** — `pragma Singleton` é padrão QtQuick, não é exclusivo de Quickshell. Só precisa do `qmldir` com `singleton Style 1.0 Style.qml` etc. Nenhuma mudança necessária.                                                                                                                                                                             |
| `import Quickshell` (símbolo `Quickshell.*`, ex. `Quickshell.shellDir`, `Quickshell.execDetached`, `Quickshell.screens`)                           | `Icons.qml`, `ShellState.qml`, `Tooltip.qml`                                 | `Quickshell.shellDir` → `Qt.application.applicationDirPath` ou um caminho de recurso fixo do app. `Quickshell.execDetached([...])` → `QProcess::startDetached(...)` em C++ exposto ao QML, ou `Qt.openUrlExternally` para casos simples. `Quickshell.screens` → `Qt.application.screens` / `Window.screen` (API nativa do QtQuick.Window).              |
| `import Quickshell.Io` → `FileView` (leitura/escrita reativa de arquivo, com `watchChanges`, `onFileChanged`, `JsonAdapter`)                       | `Color.qml` (le `colors.json`), `Settings.qml`, `I18n.qml`, `ShellState.qml` | Não existe em Qt6 puro. Rota recomendada: uma classe C++ (`QObject` com `Q_PROPERTY`) que lê/escreve o arquivo com `QFile`+`QJsonDocument`, expõe as propriedades ao QML via `qmlRegisterSingletonType`, e usa `QFileSystemWatcher` para observar mudanças externas (o equivalente do `watchChanges`). Ver seção 7 para o código concreto do Theme.qml. |
| `PopupWindow` (`Modules/Tooltip/Tooltip.qml:7`)                                                                                                    | Tooltip customizado, posicionado livre sobre a tela                          | `Qt.labs.platform` não tem popup window leve equivalente fora de Quickshell; em Qt6 puro **QtQuick.Controls `ToolTip`** cobre o caso comum (attached property `ToolTip.text`/`ToolTip.visible`), ou uma `Popup` de `QtQuick.Controls` para layouts customizados (grid, texto rico) — ambos suportados nativamente pelo `qtdeclarative` já instalado.    |
| `PanelWindow`, `ShellRoot` (não vistos nos arquivos lidos aqui, mas são a base de todo shell Quickshell — o próprio `noctalia-shell.qml` raiz usa) | Janela de painel sem decoração ancorada a uma borda de tela (barra, dock)    | `ApplicationWindow` ou `Window` de `QtQuick.Window`/`QtQuick.Controls`, com `flags: Qt.FramelessWindowHint \| Qt.WindowStaysOnTopHint` e posicionamento manual via `x`/`y`/`Screen.desktopAvailableWidth` etc. Para o melodia (app de janela única, não shell de desktop) isso não é sequer necessário — um `ApplicationWindow` comum resolve.          |
| `IpcHandler` (não visto nos arquivos lidos; é usado no restante do shell para IPC entre instâncias)                                                | Comunicação inter-processo do Quickshell                                     | Não existe em Qt6 puro. Se precisar (ex.: instância única do melodia, ou controle remoto via CLI), usar `QLocalServer`/`QLocalSocket` (Qt Network) ou D-Bus (`QtDBus`) — nenhum dos dois foi verificado como já instalado; checar antes de depender disso.                                                                                              |
| `Quickshell.Io.Process` (não visto diretamente nos arquivos lidos, mas é o padrão do ecossistema para rodar comandos externos com stdout reativo)  | Rodar `yt-dlp`, etc.                                                         | `QProcess` (Qt Core) — já disponível, é C++ puro. Conectar `readyReadStandardOutput`/`finished` a slots.                                                                                                                                                                                                                                                |

**Resumo para quem vai copiar QML do Noctalia:** os arquivos em `Commons/` (Style, Color,
os widgets em `Widgets/`) são majoritariamente **QML puro** e colam quase sem alteração — a
maior parte do "código de UI" (Rectangle, MouseArea, Behavior, ColorAnimation, RowLayout) é
QtQuick padrão. As armadilhas reais são só: `FileView` (usar C++ + `QFileSystemWatcher`),
`PopupWindow` (usar `Popup`/`ToolTip` do Controls), e qualquer `Quickshell.*` direto (checar
caso a caso, mas os únicos usados nos arquivos lidos foram `shellDir`, `execDetached`,
`screens` — nenhum indispensável).

---

## 7. Entregável de código: Theme.qml singleton (QML puro)

Decisão de rota para ler `colors.json` em runtime: **C++ expondo um objeto ao QML**, não
`XMLHttpRequest` com `file://` nem `Qt.labs.settings`. Motivos: `XMLHttpRequest` com
`file://` é gambiarra não oficial (comportamento varia por versão do Qt, sem watch de
mudança de arquivo); `Qt.labs.settings` é para configuração do próprio app (INI/registry),
não para consumir um JSON externo de outro programa. Uma classe C++ com
`QFileSystemWatcher` dá: leitura tipada, fallback limpo, hot-reload real, e funciona igual
no Windows (troca só o caminho do arquivo).

### C++: `ColorSchemeProvider` (lê `colors.json`, expõe ao QML, observa mudanças)

```cpp
// colorschemeprovider.h
#pragma once
#include <QObject>
#include <QColor>
#include <QFileSystemWatcher>

class ColorSchemeProvider : public QObject {
    Q_OBJECT
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

public:
    explicit ColorSchemeProvider(QObject *parent = nullptr);

    QColor mPrimary() const { return m_colors.value("mPrimary", fallback().mPrimary); }
    QColor mOnPrimary() const { return m_colors.value("mOnPrimary", fallback().mOnPrimary); }
    QColor mSecondary() const { return m_colors.value("mSecondary", fallback().mSecondary); }
    QColor mOnSecondary() const { return m_colors.value("mOnSecondary", fallback().mOnSecondary); }
    QColor mTertiary() const { return m_colors.value("mTertiary", fallback().mTertiary); }
    QColor mOnTertiary() const { return m_colors.value("mOnTertiary", fallback().mOnTertiary); }
    QColor mError() const { return m_colors.value("mError", fallback().mError); }
    QColor mOnError() const { return m_colors.value("mOnError", fallback().mOnError); }
    QColor mSurface() const { return m_colors.value("mSurface", fallback().mSurface); }
    QColor mOnSurface() const { return m_colors.value("mOnSurface", fallback().mOnSurface); }
    QColor mSurfaceVariant() const { return m_colors.value("mSurfaceVariant", fallback().mSurfaceVariant); }
    QColor mOnSurfaceVariant() const { return m_colors.value("mOnSurfaceVariant", fallback().mOnSurfaceVariant); }
    QColor mOutline() const { return m_colors.value("mOutline", fallback().mOutline); }
    QColor mShadow() const { return m_colors.value("mShadow", fallback().mShadow); }
    QColor mHover() const { return m_colors.value("mHover", fallback().mHover); }
    QColor mOnHover() const { return m_colors.value("mOnHover", fallback().mOnHover); }

signals:
    void colorsChanged();

private:
    struct DefaultPalette {
        QColor mPrimary{"#fff59b"}, mOnPrimary{"#0e0e43"};
        QColor mSecondary{"#a9aefe"}, mOnSecondary{"#0e0e43"};
        QColor mTertiary{"#9BFECE"}, mOnTertiary{"#0e0e43"};
        QColor mError{"#FD4663"}, mOnError{"#0e0e43"};
        QColor mSurface{"#070722"}, mOnSurface{"#f3edf7"};
        QColor mSurfaceVariant{"#11112d"}, mOnSurfaceVariant{"#7c80b4"};
        QColor mOutline{"#21215F"}, mShadow{"#070722"};
        QColor mHover{"#9BFECE"}, mOnHover{"#0e0e43"};
    };
    static const DefaultPalette &fallback() { static DefaultPalette p; return p; }

    void reload(); // reads colors.json into m_colors, no-op + keeps fallback if missing/invalid
    QHash<QString, QColor> m_colors;
    QFileSystemWatcher m_watcher;
    QString m_path; // e.g. QDir::homePath() + "/.config/noctalia/colors.json"
};
```

```cpp
// colorschemeprovider.cpp (essência do reload — implementação completa é trabalho de fatia)
#include "colorschemeprovider.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDir>
#include <QStandardPaths>

ColorSchemeProvider::ColorSchemeProvider(QObject *parent) : QObject(parent) {
    m_path = QDir::homePath() + "/.config/noctalia/colors.json";
    reload();
    if (QFile::exists(m_path)) {
        m_watcher.addPath(m_path);
    }
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &) {
        reload();
        emit colorsChanged();
        // Editors do atomic replace (unlink+rename): re-arm the watch.
        if (!m_watcher.files().contains(m_path) && QFile::exists(m_path)) {
            m_watcher.addPath(m_path);
        }
    });
}

void ColorSchemeProvider::reload() {
    QFile f(m_path);
    if (!f.exists() || !f.open(QIODevice::ReadOnly)) {
        m_colors.clear(); // fall back to defaultColors on every getter
        return;
    }
    const auto doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) { m_colors.clear(); return; }
    const auto obj = doc.object();
    static const char *keys[] = {
        "mPrimary","mOnPrimary","mSecondary","mOnSecondary","mTertiary","mOnTertiary",
        "mError","mOnError","mSurface","mOnSurface","mSurfaceVariant","mOnSurfaceVariant",
        "mOutline","mShadow","mHover","mOnHover"
    };
    QHash<QString, QColor> next;
    for (const char *k : keys) {
        if (obj.contains(k)) {
            QColor c(obj.value(k).toString());
            if (c.isValid()) next.insert(QString::fromLatin1(k), c);
        }
    }
    m_colors = next; // partial file: missing keys fall back per-getter
}
```

Registro no `main.cpp` (antes de `engine.load(...)`):

```cpp
qmlRegisterSingletonInstance<ColorSchemeProvider>(
    "Melodia.Theme", 1, 0, "ColorScheme", new ColorSchemeProvider());
```

### QML: `Theme.qml` (pragma Singleton, consome `ColorScheme` de C++)

```qml
// Theme.qml — put in a "Theme" module directory with a qmldir declaring it as singleton
pragma Singleton
import QtQuick
import Melodia.Theme 1.0

QtObject {
    id: root

    // --- Colors: 16 keys, straight passthrough from the C++ provider ---
    // (falls back to Noctalia-default values inside ColorSchemeProvider when
    // colors.json is missing — covers "no Noctalia installed" and Windows.)
    readonly property color mPrimary: ColorScheme.mPrimary
    readonly property color mOnPrimary: ColorScheme.mOnPrimary
    readonly property color mSecondary: ColorScheme.mSecondary
    readonly property color mOnSecondary: ColorScheme.mOnSecondary
    readonly property color mTertiary: ColorScheme.mTertiary
    readonly property color mOnTertiary: ColorScheme.mOnTertiary
    readonly property color mError: ColorScheme.mError
    readonly property color mOnError: ColorScheme.mOnError
    readonly property color mSurface: ColorScheme.mSurface
    readonly property color mOnSurface: ColorScheme.mOnSurface
    readonly property color mSurfaceVariant: ColorScheme.mSurfaceVariant
    readonly property color mOnSurfaceVariant: ColorScheme.mOnSurfaceVariant
    readonly property color mOutline: ColorScheme.mOutline
    readonly property color mShadow: ColorScheme.mShadow
    readonly property color mHover: ColorScheme.mHover
    readonly property color mOnHover: ColorScheme.mOnHover

    // --- Typography (literal values from Noctalia's Style.qml) ---
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

    // --- Shape (container radii) ---
    readonly property int radiusXXXS: 3
    readonly property int radiusXXS: 4
    readonly property int radiusXS: 8
    readonly property int radiusS: 12
    readonly property int radiusM: 16
    readonly property int radiusL: 20

    // --- Shape (interactive-element radii) ---
    readonly property int iRadiusXXXS: 3
    readonly property int iRadiusXXS: 4
    readonly property int iRadiusXS: 8
    readonly property int iRadiusS: 12
    readonly property int iRadiusM: 16
    readonly property int iRadiusL: 20

    // --- Borders ---
    readonly property int borderS: 1
    readonly property int borderM: 2
    readonly property int borderL: 3

    // --- Spacing ---
    readonly property int marginXXXS: 1
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

`qmldir` da pasta `Theme/`:

```
module Melodia.Theme
singleton Theme 1.0 Theme.qml
```

---

## 8. Exemplo: botão no estilo Noctalia, em QML puro, usando Theme

```qml
// PlayerButton.qml — port direto do padrão visto em Widgets/NButton.qml
import QtQuick
import QtQuick.Layouts
import Melodia.Theme 1.0 as Th

Item {
    id: root
    property string text: ""
    property color backgroundColor: Th.Theme.mPrimary
    property color textColor: Th.Theme.mOnPrimary
    property color hoverColor: Th.Theme.mHover
    property color textHoverColor: Th.Theme.mOnHover
    property bool hovered: false

    implicitWidth: bg.implicitWidth + 2 * Th.Theme.borderS
    implicitHeight: bg.implicitHeight + 2 * Th.Theme.borderS
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.margins: Th.Theme.borderS
        implicitWidth: label.implicitWidth + Th.Theme.fontSizeM * 2
        implicitHeight: label.implicitHeight + Th.Theme.fontSizeM
        radius: Th.Theme.iRadiusS
        color: root.hovered ? root.hoverColor : root.backgroundColor

        Behavior on color {
            ColorAnimation { duration: Th.Theme.animationFast; easing.type: Th.Theme.easingType }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Th.Theme.fontFamily
            font.pointSize: Th.Theme.fontSizeM
            font.weight: Th.Theme.fontWeightSemiBold
            color: root.hovered ? root.textHoverColor : root.textColor

            Behavior on color {
                ColorAnimation { duration: Th.Theme.animationFast; easing.type: Th.Theme.easingType }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.hovered = true
            onExited: root.hovered = false
            onClicked: root.clicked()
        }
    }

    signal clicked
}
```

Prova de que a tradução funciona: mesma paleta de 16 chaves, mesmos nomes de token de
raio/margem/duração, mesma curva de easing, mesmo padrão de `Behavior on color` — mas zero
`Quickshell.*`, zero `FileView`, zero `PopupWindow`. Compila com `QtQuick` + `QtQuick.Layouts`
puros, que já estão instalados (`qt6-qtdeclarative-devel`).

---

## Armadilhas registradas

1. `fontDefault` **não é hardcoded "Inter" no shell** — é `Qt.application.font.family` por
   padrão; quem fixou Inter foi a config pessoal do usuário em
   `~/.config/noctalia/settings.json`. O melodia deve hardcodar `"Inter"` (fonte já instalada
   no Fedora do usuário) e não depender de ler isso do Noctalia.
2. `radiusRatio`/`iRadiusRatio`/`screenRadiusRatio`/`uiScaleRatio` no Noctalia são fatores de
   escala configuráveis pelo usuário (todos default `1.0`) — os números acima já são os
   valores com ratio 1.0 aplicado (ou seja, os números "crus" do design). Não precisa portar
   o sistema de ratio, só os valores finais, a menos que o melodia também queira UI-scale
   configurável.
3. `Color.smartAlpha()` e `Color.adaptiveOpacity()` (translucidez de card ajustada por
   dark/light mode e por `panelBackgroundOpacity`) são lógica extra do Noctalia para
   transparência de painel flutuante sobre wallpaper — **não citado no Theme.qml acima**
   porque um player não tem esse caso de uso (não fica sobre o wallpaper); se algum dia for
   preciso, a fórmula é `Settings.data.colorSchemes.darkMode ? baseOpacity :
Math.pow(baseOpacity, 1.5)` (`Color.qml:354`).
4. `NBox` (o "card" do Noctalia) não some sozinho: ele SEMPRE aplica `border.color:
Style.boxBorderColor`, que por sua vez é `Color.mOutline` só **se**
   `Settings.data.ui.boxBorderEnabled` — outro toggle de usuário. Fixar como "sempre com
   borda `mOutline`" é a leitura mais simples para o melodia.
5. O ícone Tabler é **PUA (Private Use Area)** do Unicode — os codepoints (`\u{eb4d}` etc.)
   só significam algo com a fonte `noctalia-tabler-icons.ttf` carregada; não são glyphs
   Unicode padrão, não vão renderizar com nenhuma outra fonte.
6. Licença do arquivo de fonte Tabler (`Assets/Fonts/tabler/tabler-icons-license.txt`) não foi
   lida neste research — **NAO VERIFICADO** se copiar o `.ttf` para o melodia é permitido sem
   restrição; checar antes de embutir o arquivo no repo/instalador.

## Não verificado (marcado explicitamente, não inventado)

- Consumidor real de `Style.shadowOpacity`/`shadowBlur*` (qual componente aplica a sombra) —
  não abri o arquivo que usa esses tokens.
- Uso exato de `mSecondary`/`mOnSecondary` em algum widget-base além da definição de paleta.
- Onde exatamente cada `fontSize*` aparece por tela (fora do que os 4 widgets lidos mostram).
- Termos de licença do arquivo `tabler-icons-license.txt` (arquivo não lido).
- `PanelWindow`/`ShellRoot`/`IpcHandler` — não vistos diretamente nos arquivos lidos
  (`Commons/*` e os 4-6 widgets escolhidos); a caracterização deles na seção 6 é conhecimento
  geral do ecossistema Quickshell, não uma citação de linha específica do Noctalia.
