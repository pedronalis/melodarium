#!/usr/bin/env bash
# Validate the files and metadata that make a public Melodarium release trustworthy.
set -uo pipefail

SOURCE_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$SOURCE_ROOT" || exit 1

failed=0

fail() {
    echo "$1"
    failed=1
}

required_files=(
    LICENSE
    README.md
    README.pt-BR.md
    CONTRIBUTING.md
    CONTRIBUTING.pt-BR.md
    SECURITY.md
    CODE_OF_CONDUCT.md
    CHANGELOG.md
    .github/ISSUE_TEMPLATE/bug_report.yml
    .github/ISSUE_TEMPLATE/feature_request.yml
    .github/ISSUE_TEMPLATE/config.yml
    .github/PULL_REQUEST_TEMPLATE.md
    .github/release.yml
    .github/dependabot.yml
    .github/workflows/release.yml
    docs/brand/github-visual-philosophy.md
    docs/assets/melodarium-hero.png
)

gallery_files=(
    docs/assets/screenshots/now-playing.png
    docs/assets/screenshots/library.png
    docs/assets/screenshots/collections.png
    docs/assets/screenshots/podcasts.png
    docs/assets/screenshots/search.png
)

for path in "${required_files[@]}" "${gallery_files[@]}"; do
    if [ ! -s "$path" ]; then
        fail "PUBLIC_RELEASE_MISSING $path"
    fi
done

if [ -s LICENSE ]; then
    if ! rg -Fq 'GNU GENERAL PUBLIC LICENSE' LICENSE \
            || ! rg -Fq 'Version 3, 29 June 2007' LICENSE; then
        fail "PUBLIC_RELEASE_LICENSE_TEXT LICENSE is not canonical GPLv3 text"
    fi
fi

if ! rg -Fq '<project_license>GPL-3.0-only</project_license>' \
        data/io.github.pedronalis.melodarium.metainfo.xml; then
    fail "PUBLIC_RELEASE_LICENSE_MISMATCH AppStream is not GPL-3.0-only"
fi

license_docs=(
    README.md
    README.pt-BR.md
    CONTRIBUTING.md
    CONTRIBUTING.pt-BR.md
    CHANGELOG.md
    docs/releases/0.1.0.md
)

for path in "${license_docs[@]}"; do
    if [ -s "$path" ] && ! rg -Fq 'GPL-3.0-only' "$path"; then
        fail "PUBLIC_RELEASE_LICENSE_DOC $path does not name GPL-3.0-only"
    fi
done

if [ -s README.md ] && ! rg -Fq 'README.pt-BR.md' README.md; then
    fail "PUBLIC_RELEASE_LANGUAGE_LINK README.md does not link to pt-BR"
fi
if [ -s README.pt-BR.md ] && ! rg -Fq 'README.md' README.pt-BR.md; then
    fail "PUBLIC_RELEASE_LANGUAGE_LINK README.pt-BR.md does not link to English"
fi
if [ -s CONTRIBUTING.md ] && ! rg -Fq 'CONTRIBUTING.pt-BR.md' CONTRIBUTING.md; then
    fail "PUBLIC_RELEASE_LANGUAGE_LINK CONTRIBUTING.md does not link to pt-BR"
fi
if [ -s CONTRIBUTING.pt-BR.md ] && ! rg -Fq 'CONTRIBUTING.md' CONTRIBUTING.pt-BR.md; then
    fail "PUBLIC_RELEASE_LANGUAGE_LINK CONTRIBUTING.pt-BR.md does not link to English"
fi

if [ -s README.md ] && rg -n \
        'github\.com/[^/]+/[^/]+/actions/workflows/[^ )]+/badge\.svg' README.md \
        | rg -vq 'github\.com/pedronalis/melodarium/actions/workflows/'; then
    fail "PUBLIC_RELEASE_FOREIGN_BADGE README.md"
fi
if [ -s README.pt-BR.md ] && rg -n \
        'github\.com/[^/]+/[^/]+/actions/workflows/[^ )]+/badge\.svg' README.pt-BR.md \
        | rg -vq 'github\.com/pedronalis/melodarium/actions/workflows/'; then
    fail "PUBLIC_RELEASE_FOREIGN_BADGE README.pt-BR.md"
fi

secret_pattern='gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{48}|sk-(proj|svcacct)-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
if git grep -I -E -q "$secret_pattern" -- . ':!tools/check-public-release.sh'; then
    fail "PUBLIC_RELEASE_SECRET_PATTERN tracked tree contains a credential-shaped value"
fi

if ! python3 -c 'import PIL' >/dev/null 2>&1; then
    fail "PUBLIC_RELEASE_DEPENDENCY python3-pillow"
else
    python3 - "${gallery_files[@]}" <<'PY' || failed=1
import statistics
import sys
from pathlib import Path

from PIL import Image, ImageStat

for raw_path in sys.argv[1:]:
    path = Path(raw_path)
    if not path.is_file() or path.stat().st_size == 0:
        continue
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        if rgb.size != (1100, 700):
            print(f"PUBLIC_RELEASE_IMAGE_SIZE {path} is {rgb.width}x{rgb.height}")
            raise SystemExit(1)
        sample = rgb.resize((110, 70))
        spread = statistics.fmean(ImageStat.Stat(sample).stddev)
        colors = sample.getcolors(maxcolors=110 * 70)
        color_count = len(colors) if colors is not None else 110 * 70
        if spread < 8 or color_count < 48:
            print(
                f"PUBLIC_RELEASE_IMAGE_FLAT {path} "
                f"spread={spread:.2f} colors={color_count}"
            )
            raise SystemExit(1)
        print(
            f"PUBLIC_RELEASE_SCREENSHOT_OK {path} "
            f"1100x700 spread={spread:.2f} colors={color_count}"
        )

hero = Path("docs/assets/melodarium-hero.png")
if hero.is_file() and hero.stat().st_size:
    with Image.open(hero) as image:
        if image.size != (1280, 640):
            print(f"PUBLIC_RELEASE_IMAGE_SIZE {hero} is {image.width}x{image.height}")
            raise SystemExit(1)
        print(f"PUBLIC_RELEASE_HERO_OK {hero} 1280x640")
PY
fi

if [ -d .github ] && python3 -c 'import yaml' >/dev/null 2>&1; then
    while IFS= read -r yaml_file; do
        if ! python3 - "$yaml_file" <<'PY'
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
with path.open(encoding="utf-8") as handle:
    yaml.safe_load(handle)
PY
        then
            fail "PUBLIC_RELEASE_YAML_INVALID $yaml_file"
        fi
    done < <(find .github -type f \( -name '*.yml' -o -name '*.yaml' \) -print | sort)
fi

if [ "$failed" -ne 0 ]; then
    exit 1
fi

echo "PUBLIC_RELEASE_OK bilingual docs, community files, real screenshots, license and metadata"
