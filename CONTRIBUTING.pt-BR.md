# Contribuindo com o Melodarium

[English](CONTRIBUTING.md) · **Português (Brasil)**

Obrigado por ajudar a fazer software local de música melhor. Relatos de bug, observações de design
e código são bem-vindos em português ou inglês. O Melodarium ainda é um preview inicial para Linux,
então mudanças pequenas e bem provadas são muito mais fáceis de revisar que reescritas amplas.

> [!IMPORTANT]
> A licença do projeto ainda está sendo escolhida. Até a publicação de `LICENSE`, contribua por
> issues e discussões de design/diagnóstico em vez de enviar código para inclusão no projeto.

## Antes de começar

1. Procure por issues e discussões existentes.
2. Abra um pedido de recurso antes de uma grande mudança de UI, modelo de dados ou dependência.
3. Descreva o resultado visível para o usuário e como ele pode ser verificado.
4. Nunca anexe biblioteca de música, banco, download de podcast ou credencial reais. Monte uma
   fixture mínima e descartável.

Boas primeiras contribuições incluem correções de documentação, bugs reproduzíveis, achados de
acessibilidade, verificações de empacotamento e testes focados.

## Ambiente de desenvolvimento

O Fedora 43 é a plataforma de referência. Instale as dependências do build nativo:

```bash
sudo dnf install cmake ninja-build gcc-c++ \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  mpv-devel taglib-devel \
  rsms-inter-fonts jetbrains-mono-fonts
```

O gate local completo também exige:

```bash
sudo dnf install ImageMagick appstream dbus-daemon desktop-file-utils \
  ffmpeg-free flac flatpak-builder playerctl python3-pillow python3-pyyaml \
  ripgrep sqlite xdotool xorg-x11-server-Xvfb
```

Configure e compile:

```bash
cmake -S . -B build -G Ninja
cmake --build build
./build/melodarium
```

## Fluxo de mudança

- Mantenha cada commit focado e escreva o título em inglês, por exemplo
  `fix(queue): preserve the selected track`.
- Escreva C++, identificadores QML e comentários de código em inglês. O texto visível do app hoje
  segue pt-BR porque a infraestrutura de tradução ainda não foi implementada.
- Antes de mudar comportamento, adicione ou atualize um teste sempre que for viável.
- Preserve o funcionamento local-first: rede deve ser explícita e ligada a um recurso que dependa
  dela, nunca a telemetria ou obrigação de conta.
- Não reescreva migrações SQLite já publicadas nem remova a migração dos caminhos do antigo app
  `melodia`.
- Evite refatorações “já que estou aqui”. Registre observações fora do escopo em outra issue.

## Verificação

Sempre compile antes de executar CTest. Exit code zero não basta: o CTest também termina com sucesso
quando não descobre teste nenhum, portanto o gate de piso é obrigatório.

```bash
cmake -S . -B build -G Ninja
cmake --build build
bash tools/check-test-floor.sh 25
ctest --test-dir build --output-on-failure
```

Rode os gates adicionais que correspondem à sua mudança:

| Mudança | Evidência obrigatória |
|---|---|
| Qualquer QML | `cmake --build build --target all_qmllint` e `bash tools/check-orfaos.sh` |
| Layout ou cores | `bash tools/check-layout.sh` e `bash tools/check-fidelidade.sh` |
| Acessibilidade | `bash tools/check-accessibility.sh` |
| Fila ou reprodução | Alvo CTest relevante e o gate `tools/check-*.sh` correspondente |
| Empacotamento | `bash tools/check-package.sh` |
| Docs/assets públicos | `bash tools/check-public-release.sh` |

O workflow da CI executa a suíte determinística completa no Fedora 43.

## Mudanças visuais

Um print não substitui teste de interação, e um gate de geometria não prova que as cores estão
certas. Para trabalho de UI:

1. Exercite o componente alcançável no aplicativo real.
2. Rode lint QML e os gates de órfãos, layout e fidelidade.
3. Capture o estado afetado com diretório XDG isolado.
4. Inclua imagens de antes/depois e descreva a interação testada.

A galeria pública do README é reproduzível:

```bash
bash tools/capture-readme-gallery.sh ./build/melodarium
```

Ela cria áudio gerado, metadados sintéticos e capas originais num diretório temporário; use o mesmo
padrão para fixtures de regressão.

## Pull requests

Mantenha o pull request pequeno o bastante para ser revisado como uma ideia. Preencha o template,
ligue a issue, liste os comandos exatos que rodou e destaque tudo que ainda exige julgamento humano
visual ou de áudio. Não misture saída de build, caches, mídia pessoal nem bancos locais no commit.

Um mantenedor pode pedir que a mudança seja separada quando comportamento do produto, risco de
migração e design visual estiverem misturados. Isso preserva a honestidade da verificação; não é
apenas uma questão de número de linhas.

## Relatando problemas de segurança

Não abra issue pública para vulnerabilidade. Siga [SECURITY.md](SECURITY.md) e use o relato privado
de vulnerabilidades do GitHub.
