# melodia

Player local de música e podcast em Qt6/QML, com a estética do
[Noctalia](https://github.com/noctalia-dev/noctalia-shell): paleta lida do `colors.json` do
usuário, tipografia Inter e ícones Tabler. Roda igual sem o Noctalia instalado — toda cor tem
fallback embutido.

## Dependências

Fedora:

```bash
sudo dnf install cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtdeclarative-devel
```

## Build

```bash
cmake -B build -G Ninja
cmake --build build
./build/appmelodia
```

## Testes

```bash
ctest --test-dir build --output-on-failure
```

## Modo de desenvolvimento da tela

Recarrega o QML a cada salvamento, sem recompilar o C++:

```bash
MELODIA_DEV_QML=$PWD/src/Main.qml ./build/appmelodia
```

Os tipos C++ continuam disponíveis porque estão linkados estaticamente no binário; só o texto
QML é relido do disco.

## Ver `qDebug` e `console.log`

O Fedora instala `/usr/share/qt6/qtlogging.ini` com `*.debug=false` e manda o resto para o
journald — sem as duas variáveis abaixo, todo log de debug some sem erro nenhum:

```bash
QT_LOGGING_RULES="*.debug=true" QT_FORCE_STDERR_LOGGING=1 ./build/appmelodia
```

## Licenças de terceiros

A fonte de ícones Tabler (`assets/fonts/noctalia-tabler-icons.ttf`) é distribuída sob licença
MIT — o texto acompanha o arquivo em `assets/fonts/tabler-icons-license.txt`.
