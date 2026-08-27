# Player de música e podcast — esqueleto

**Data:** 2026-08-27 · **Nome provisório:** melodia (definir com `/batiza`)
**Modo:** esqueleto (não é SPEC completo — decisões que amarram, o resto se decide construindo)

---

## O quê

Um player e biblioteca de música **e** podcast, de arquivos locais, com a estética do
Noctalia, rodando em Linux (Windows depois). Publicado no GitHub, aberto, sem promessa
de suporte.

Não é um catálogo de streaming e não é uma casca para o Spotify: os arquivos são de
verdade e ficam no disco.

## Pra quê

Existem players bons e prontos (Strawberry, Elisa). Este só se justifica por duas coisas,
e elas são o produto:

1. **A cara.** Player feio não se abre, e app que não se abre não serve. A aparência é
   requisito, não enfeite.
2. **A organização.** Coleções por contexto ("Pra codar", "Madrugada") em vez de só o
   eixo artista → álbum → faixa.

Tudo que não serve a essas duas coisas é candidato a corte.

---

## Decisões

| O quê | Decidido | Por quê |
|---|---|---|
| Plataforma | Linux primeiro, Windows depois | Quickshell (o do Noctalia) é Wayland/Linux-only — não existe port |
| Tela | Qt6 + QML | Mesma tecnologia do Noctalia: dá para ler `/etc/xdg/quickshell/noctalia-shell` e adaptar |
| Motor | C++ | Mais leve e abre mais rápido; a tela (QML) fica editável pelo Pedro |
| Áudio | libmpv | Toca tudo, alta resolução, gapless, sem resample do sistema |
| Tags dos arquivos | TagLib | Padrão de fato; é o que o Strawberry usa |
| Biblioteca | SQLite | Local, sem servidor |
| Organização | Coleções (faixa em várias) + artista/álbum/gênero/tags + busca | O clássico porque estranho usa; coleções porque é o diferencial |
| Tags | Livres, com autocomplete do que já existe | Autocomplete é o freio que impede "codar"/"programar"/"foco" virarem três tags iguais |
| Automáticas | Recentes · Mais tocadas · Esquecidas · Nunca ouvi | Custo zero para o usuário: o app já tem esses dados |
| Baixar | Cola link do YouTube dentro de uma coleção → baixa na melhor qualidade disponível, com capa | Pedido explícito, mantido após alerta |
| Baixador | `yt-dlp` **externo**, chamado como processo — não embutido no projeto | O app publicado não distribui o baixador; some o risco de takedown e o de quebrar a cada update |
| Podcast | Por programa + "Continuar ouvindo" + velocidade + marcar ouvido | Podcast quer o oposto de música: retomar posição, não embaralhar |
| Feed RSS | **Entra na primeira versão** | Decisão do Pedro após dois alertas de custo |
| Publicação | GitHub aberto, sem instalador nem suporte | "Público e quem quiser usa" |

### Requisito duro: qualidade de áudio

Áudio é critério de aceitação, não "nice to have":

- FLAC e alta resolução (24 bit / 96–192 kHz) tocados sem conversão no caminho
- Sem silêncio entre faixas de álbuns contínuos (ao vivo, DJ set, ópera)
- Sem o sistema operacional remixar ou reamostrar o sinal
- ReplayGain respeitado quando o arquivo tiver

**Limite honesto e documentado:** o que vier do YouTube é comprimido (Opus, ~160 kbps) e
nunca será alta qualidade. As duas qualidades convivem na biblioteca; o app não finge que
são a mesma coisa.

### Como fica organizado

```
   [ Música ]   Podcast                       🔍
──────────────────────────────────────────────────
  Coleções        ← o diferencial, no topo
  Artistas
  Álbuns
  Gêneros
  Tags
  Todas as faixas
──────────────────────────────────────────────────
  Recentes · Mais tocadas · Esquecidas · Nunca ouvi
```

Podcast **não** tem coleção nem tag: por programa, episódios dentro, "Continuar ouvindo"
no topo.

**O gesto manual é um só:** jogar uma faixa numa coleção. Todo o resto o app preenche
sozinho. Esse é o princípio que impede o sistema de ser abandonado em três semanas.

---

## Fora de escopo

Explicitamente **não** se faz — e não se discute de novo sem motivo novo:

- **Energia, humor, contexto por faixa.** Cortado na entrevista: campo que ninguém
  preenche duas vezes igual. Contexto já é o nome da coleção.
- **Pasta exclusiva** (faixa num lugar só). Coleção múltipla ganhou.
- **Streaming** (Spotify, YouTube Music, Tidal, Subsonic/Navidrome). O app é de arquivos.
- **Scrobble** (Last.fm / ListenBrainz).
- **Editar tags dos arquivos.** O app lê; não escreve no arquivo do usuário.
- **Sincronizar biblioteca entre máquinas.**
- **Equalizador, efeitos, visualizações.** Contrariam o requisito de qualidade.
- **Análise automática** (BPM, detecção de humor, sugestão automática de coleção).
- **Widget na barra do Noctalia.** Depois de o app existir, se fizer sentido.
- **Instalador, atualização automática, suporte.** "Quem quiser usa" — sem promessa.
- **Vídeo.** Não é player de vídeo.
- **Windows** na primeira versão. A stack já garante que é possível; só não é agora.

---

## Fatias sugeridas (para o `/planeja`)

Ordem por dependência, não por importância:

1. **Esqueleto + toca** — janela QML com a cara do Noctalia, varre a pasta, lê tags, lista, toca/pausa/pula.
2. **Biblioteca de verdade** — banco, artista/álbum/gênero, busca, fila, capas, as listas automáticas.
3. **Coleções e tags** — o diferencial: criar coleção, jogar faixa nela, filtrar por tag com autocomplete.
4. **Podcast lendo a pasta** — seção própria, retomar posição, velocidade, marcar ouvido.
5. **Feed RSS** — assinar, checar, baixar sozinho, tratar internet caída e download pela metade.
6. **Baixar do YouTube** — colar link numa coleção, chamar o `yt-dlp` do sistema, capa e nome certos.

Fatias 1–4 são o app utilizável. 5 e 6 são o que o Pedro pediu para não deixar de fora.

## Riscos assumidos

- **Feed RSS na v1** dobra o tamanho da primeira entrega: é a única parte que roda em
  background e lida com rede. Alertado duas vezes, mantido por decisão do Pedro.
- **App público que baixa do YouTube** é terreno cinzento. Mitigado por não distribuir o
  baixador junto (o app chama o que já estiver instalado na máquina).
- **C++ é linguagem nova para o Pedro.** Mitigado por a tela (QML, onde ele vai querer
  mexer) ser separada do motor.
