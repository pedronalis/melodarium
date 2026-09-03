# Contributing to Melodarium

**English** · [Português (Brasil)](CONTRIBUTING.pt-BR.md)

Thanks for helping make local music software better. Bug reports, design observations and code
are welcome in English or Portuguese. Melodarium is still an early Linux preview, so small,
well-proven changes are much easier to review than broad rewrites.

> [!IMPORTANT]
> The project license is still being selected. Until `LICENSE` is published, please contribute
> through issues and design/diagnostic discussion rather than submitting code for inclusion.

## Before you start

1. Search existing issues and discussions.
2. Open a feature request before a large UI, data-model or dependency change.
3. Describe the user-visible outcome and how it can be verified.
4. Never attach a real music library, database, podcast download or credential. Build a minimal
   disposable fixture instead.

Good first contributions include documentation fixes, reproducible bug reports, accessibility
findings, packaging checks and focused tests.

## Development environment

Fedora 43 is the reference platform. Install the native build dependencies:

```bash
sudo dnf install cmake ninja-build gcc-c++ \
  qt6-qtbase-devel qt6-qtdeclarative-devel \
  mpv-devel taglib-devel \
  rsms-inter-fonts jetbrains-mono-fonts
```

The complete local gate also needs:

```bash
sudo dnf install ImageMagick appstream dbus-daemon desktop-file-utils \
  ffmpeg-free flac flatpak-builder playerctl python3-pillow python3-pyyaml \
  ripgrep sqlite xdotool xorg-x11-server-Xvfb
```

Configure and build:

```bash
cmake -S . -B build -G Ninja
cmake --build build
./build/melodarium
```

## Change workflow

- Keep each commit focused and write commit subjects in English, for example
  `fix(queue): preserve the selected track`.
- Write C++, QML identifiers and code comments in English. User-facing text currently follows
  pt-BR because application translation infrastructure has not landed yet.
- Add or update a test before changing behavior whenever practical.
- Preserve local-first behavior: network access must be explicit and tied to a feature that needs
  it, never analytics or an account requirement.
- Do not rewrite published SQLite migrations or remove the migration from the former `melodia`
  application paths.
- Avoid drive-by refactors. Put unrelated observations in a separate issue.

## Verification

Always build before running CTest. Exit code zero is not enough: CTest also exits successfully when
it discovers no tests, so the floor gate is mandatory.

```bash
cmake -S . -B build -G Ninja
cmake --build build
bash tools/check-test-floor.sh 25
ctest --test-dir build --output-on-failure
```

Run the extra gates that match your change:

| Change | Required evidence |
|---|---|
| Any QML | `cmake --build build --target all_qmllint` and `bash tools/check-orfaos.sh` |
| Layout or colors | `bash tools/check-layout.sh` and `bash tools/check-fidelidade.sh` |
| Accessibility | `bash tools/check-accessibility.sh` |
| Queue or playback | Relevant CTest target plus the matching `tools/check-*.sh` gate |
| Packaging | `bash tools/check-package.sh` |
| Public docs/assets | `bash tools/check-public-release.sh` |

The CI workflow runs the complete deterministic suite in Fedora 43.

## Visual changes

A screenshot does not replace interaction testing, and a geometry check does not prove that colors
are right. For UI work:

1. Exercise the reachable component in the real application.
2. Run QML lint, orphan, layout and fidelity gates.
3. Capture the affected state with an isolated XDG directory.
4. Include before/after images and describe the interaction that was tested.

The public README gallery is reproducible:

```bash
bash tools/capture-readme-gallery.sh ./build/melodarium
```

It creates generated audio, synthetic metadata and original covers under a temporary directory;
use the same pattern for regression fixtures.

## Pull requests

Keep a pull request small enough to review as one idea. Complete the template, link its issue, list
the exact commands you ran and call out anything that still needs human visual or audio judgment.
Do not mix generated build output, caches, personal media or local databases into a commit.

A maintainer may ask to split a change when product behavior, migration risk and visual design are
entangled. That is about keeping verification honest, not about the size of the diff alone.

## Reporting security issues

Do not open a public issue for a vulnerability. Follow [SECURITY.md](SECURITY.md) and use GitHub's
private vulnerability reporting flow.
