---
slug: mpris-noctalia
feature: melodarium
status: em-execucao
depende-de: [motor-audio]
decisao-humana: sim
spec: docs/specs/2026-08-27-player-musica-podcast.md
---

# Integração MPRIS com o Noctalia Implementation Plan

> **Para execução agentic:** executar inline com TDD; o gate final precisa passar pelo
> barramento D-Bus real e pelas teclas de mídia no desktop do Pedro.

**Goal:** publicar o Melodarium como player MPRIS 2.2 para o Noctalia mostrar faixa, artista,
capa e estado, e para Play/Pause/Next/Previous do teclado controlarem o `AudioEngine`.

**Architecture:** um `MprisService` anexado ao singleton `AudioEngine` exporta, no session bus,
o nome `org.mpris.MediaPlayer2.melodarium` e o objeto `/org/mpris/MediaPlayer2`. Dois adaptadores
`QDBusAbstractAdaptor` implementam as interfaces Root e Player; os métodos apenas encaminham ao
motor existente, e os sinais do motor viram `PropertiesChanged`. A integração é Linux/Unix e não
entra no caminho do áudio nem cria dependência do Quickshell.

**Tech Stack:** Qt 6.10 `QtDBus`, MPRIS 2.2, libmpv, TagLib, `playerctl`, Qt Test e CTest.

## Global Constraints

- A causa provada é a ausência total de `org.mpris.MediaPlayer2.melodarium`; não alterar binds
  do Hyprland nem arquivos do Noctalia.
- O Noctalia filtra players sem `CanPlay`; com uma sessão salva, `Play` deve restaurar a fila e
  iniciar a faixa atual, mantendo o contrato de retomada em `0:00`.
- `Position` e `mpris:length` usam microssegundos; `Volume` usa a escala MPRIS 0.0–1.0, enquanto
  o motor usa 0–100.
- `Metadata` sempre inclui `mpris:trackid` quando há faixa e usa `xesam:title`, `xesam:artist`,
  `xesam:album`, `xesam:url`, `mpris:length` e `mpris:artUrl` quando disponíveis.
- Não exportar TrackList: a fila continua autoridade do `AudioEngine`, com `HasTrackList=false`.
- O serviço deve falhar de forma segura quando não houver session bus ou quando outra instância
  já possuir o nome; o app continua tocando pela UI.
- Não mexer em qualidade, gapless, ReplayGain, caminhos de dados, visual ou configurações do
  usuário.
- Antes de cada `ctest`, compilar e conferir que o gate shell `tst_mpris` aparece em `-N`; a
  saída precisa provar cada chamada, sem aceitar dependência ausente como verde.

## File Map

- Create: `src/mprisservice.h`, `src/mprisservice.cpp` — serviço, adaptadores Root/Player,
  metadata e emissão de `PropertiesChanged`.
- Modify: `src/main.cpp` — obter o singleton `AudioEngine` depois de carregar QML e manter o
  serviço vivo pelo `QQmlApplicationEngine`.
- Modify: `CMakeLists.txt` — localizar/linkar `Qt6::DBus` e compilar o serviço somente no
  backend Unix, preservando o caminho futuro de Windows sem MPRIS.
- Create: `tools/check-mpris.sh` — reprodução real isolada em `dbus-run-session`, com fila salva,
  `playerctl play/pause/next` e consultas de metadata.
- Modify: `tests/CMakeLists.txt` — registrar o gate como teste e dar timeout explícito.
- Create: `docs/solutions/integracao/2026-08-31-player-local-precisa-publicar-mpris.md` — causa,
  contrato e receita de diagnóstico.

---

### Task 1: Contrato vermelho e serviço MPRIS

**Files:**
- Create: `tools/check-mpris.sh`
- Create: `src/mprisservice.h`, `src/mprisservice.cpp`
- Modify: `src/main.cpp`, `CMakeLists.txt`
- Modify: `tests/CMakeLists.txt`

**Interfaces:**
- Consumes: `AudioEngine::{play,pause,togglePause,stop,seek,next,previous,restoreSavedQueue}` e
  seus sinais/propriedades; `TagReader::read`; `CoverCache::coverUrlForTrack`;
  `dbus-run-session`, `playerctl`, `ffmpeg` e QSettings isolado.
- Produces: `org.mpris.MediaPlayer2.melodarium` em `/org/mpris/MediaPlayer2`, interfaces
  `org.mpris.MediaPlayer2` e `org.mpris.MediaPlayer2.Player`, mais o teste `tst_mpris`.

- [x] Criar dois FLACs temporários, gravar `playback/queue` e `currentIndex` em
  `$XDG_CONFIG_HOME/melodarium/melodarium.conf`, e iniciar o app com `MELODIA_NULL_AO=1` e
  `QT_QPA_PLATFORM=offscreen` dentro de um session bus isolado.
- [x] Esperar por `org.mpris.MediaPlayer2.melodarium` com prazo; consultar `Identity`,
  `CanControl`, `CanPlay`, `PlaybackStatus` e `Metadata` por `playerctl`/`gdbus`.
- [x] Mandar `play`, esperar `Playing`; mandar `pause`, esperar `Paused`; mandar `next` e exigir
  que `xesam:title` mude do primeiro para o segundo arquivo.
- [x] Registrar em `tests/CMakeLists.txt`, compilar e confirmar vermelho especificamente porque
  o nome MPRIS não aparece — não por fixture, dependência ou processo órfão. Conferir o novo
  teste com `ctest --test-dir build -N -R tst_mpris` antes de executar o binário atualizado.
- [x] Implementar adaptador Root com `CanQuit=false`, `CanRaise=false`,
  `CanSetFullscreen=false`, `HasTrackList=false`, `Identity=Melodarium`, `DesktopEntry=melodarium`
  e suporte aos formatos locais já aceitos pelo scanner.
- [x] Implementar adaptador Player com os métodos e propriedades obrigatórios do MPRIS 2.2;
  `Play`/`PlayPause` restauram a sessão salva quando ainda não há faixa carregada.
- [x] Conectar sinais do motor a `org.freedesktop.DBus.Properties.PropertiesChanged`; não emitir
  o sinal para a progressão normal de `Position`, conforme a especificação.
- [x] Montar metadata da faixa com fallback para o nome do arquivo e resolver `mpris:artUrl`
  pelo cache assíncrono existente, descartando resultado que pertença à faixa anterior.
- [x] Depois de `engine.load...`, obter `AudioEngine` por
  `engine.singletonInstance<AudioEngine*>("Melodarium.App", "AudioEngine")` e parentear o
  `MprisService` ao `QQmlApplicationEngine`.
- [x] Localizar e linkar `Qt6::DBus` sob condição Unix; em outras plataformas, compilar sem os
  arquivos MPRIS e sem alterar o `main` efetivo.
- [x] Compilar, rodar o mesmo `tst_mpris` até verde e depois rodar a suíte completa; marcar e
  commitar teste e implementação juntos com
  `feat(mpris): expose playback to desktop controls`.

### Task 2: Gate no Noctalia e lição durável

**Files:**
- Create: `docs/solutions/integracao/2026-08-31-player-local-precisa-publicar-mpris.md`
- Modify: `docs/plans/2026-08-31-mpris-noctalia.md`

**Interfaces:**
- Consumes: build final, session bus real, Noctalia `MediaService`, teclas XF86 do teclado.
- Produces: evidência de descoberta e controle no desktop real do Pedro.

- [ ] Rodar build, piso de testes, suíte completa, `check-orfaos.sh`, `check-layout.sh` e
  `check-fidelidade.sh` por `quiet-run`.
- [ ] Reiniciar somente o Melodarium com o binário novo; exigir
  `playerctl -l | grep '^melodarium$'` e inspecionar as duas interfaces por `gdbus introspect`.
- [ ] Tocar uma faixa, acionar Play/Pause e Next pelo IPC exato usado pelos binds:
  `~/.config/hypr/scripts/noctalia-ipc.sh call media ...`; comparar estado, arquivo e metadata.
- [ ] Pedro confirma na tela que o player aparece no Noctalia e que as teclas físicas controlam
  a faixa; registrar a causa e o diagnóstico em `docs/solutions/integracao/`.
- [ ] Rodar `gitnexus detect_changes`, marcar a task, concluir a fatia com `planos-lote.py`,
  commitar apenas os arquivos da fatia e enviar `main`.
