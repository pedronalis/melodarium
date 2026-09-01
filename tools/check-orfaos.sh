#!/usr/bin/env bash
# Finds unreachable QML components and Q_INVOKABLE methods. C++ methods are scoped by class:
# a call to Alpha.open() never makes Beta.open() reachable by accident.
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
cd "$SCRIPT_DIR/.."

python3 - "${1:-}" <<'PY'
import re
import sys
from pathlib import Path

MODE = sys.argv[1]

QML_OK = {"Main", "Theme", "Icons"}

# Covered by a sibling verb or reached entirely inside C++. These are class-qualified on
# purpose: PodcastLibrary.downloadDirectory cannot hide YtDlpDownloader.downloadDirectory.
CPP_OK = {
    "AudioEngine.pause",
    "AudioEngine.stop",
    "CollectionManager.ingestDownloadedFile",
    "FolderBrowser.refresh",
    "LibraryBrowser.isLiked",
    "PlayStatsRecorder.recordSkip",
    "PlayStatsRecorder.savePosition",
    "PodcastEpisodeModel.episodeAt",
    "PodcastEpisodeModel.loadForShow",
    "PodcastLibrary.downloadDirectory",
    "YtDlpDownloader.downloadDirectory",
}

# Calls through typed properties rather than a direct `TypeName.method()` or `id.method()`.
# Each entry is still class-scoped and must match a concrete receiver in QML.
SCOPED_QML_RECEIVERS = {
    "TrackListModel": {"list.model"},
}

# Motor pronto, gesto ainda sem UI aprovada. A reserva vira falha se a chamada aparecer ou se
# o método deixar de existir, impedindo que a lista envelheça como um silenciador permanente.
CPP_RESERVA = {
    "AudioEngine.setGaplessAggressive",
    "CollectionManager.collectionsForTrack",
}


def class_bodies(text):
    """Yield (class_name, balanced class body) without confusing inline method braces."""
    for match in re.finditer(r"\bclass\s+([A-Za-z_]\w*)[^;{]*\{", text):
        depth = 1
        cursor = match.end()
        while cursor < len(text) and depth:
            if text[cursor] == "{":
                depth += 1
            elif text[cursor] == "}":
                depth -= 1
            cursor += 1
        if depth == 0:
            yield match.group(1), text[match.end():cursor - 1]


def invokables_from(headers):
    pairs = set()
    for text in headers:
        for class_name, body in class_bodies(text):
            for line in body.splitlines():
                if "Q_INVOKABLE" not in line:
                    continue
                declaration = line.split("Q_INVOKABLE", 1)[1]
                method = re.search(r"([A-Za-z_]\w*)\s*\(", declaration)
                if method:
                    pairs.add(f"{class_name}.{method.group(1)}")
    return pairs


def qml_instance_ids(qml_text, class_name):
    ids = set()
    pattern = re.compile(rf"\b{re.escape(class_name)}\s*\{{")
    for match in pattern.finditer(qml_text):
        # IDs in this repo are declared at the top of an instance. Stop at the first nested
        # object so an id belonging to a child cannot be assigned to the parent type.
        tail = qml_text[match.end():match.end() + 600]
        nested = tail.find("{")
        direct = tail if nested < 0 else tail[:nested]
        found = re.search(r"\bid\s*:\s*([A-Za-z_]\w*)", direct)
        if found:
            ids.add(found.group(1))
    return ids


def method_reachability(invokables, qml_text):
    reachable = set()
    for pair in invokables:
        class_name, method = pair.split(".", 1)
        receivers = ({class_name} | qml_instance_ids(qml_text, class_name)
                     | SCOPED_QML_RECEIVERS.get(class_name, set()))
        if any(re.search(rf"\b{re.escape(receiver)}\s*\.\s*{re.escape(method)}\s*\(",
                         qml_text)
               for receiver in receivers):
            reachable.add(pair)
    return reachable


def analyse_methods(invokables, qml_text, cpp_ok, reserves):
    reachable = method_reachability(invokables, qml_text)
    stale_reserves = {pair for pair in reserves if pair in reachable or pair not in invokables}
    unreachable = invokables - reachable - cpp_ok - reserves
    active_reserves = reserves - stale_reserves
    return unreachable, stale_reserves, active_reserves


def self_test():
    headers = ["""
        class Alpha { Q_INVOKABLE void ping(); };
        class Beta { Q_INVOKABLE void ping(); Q_INVOKABLE void reserved(); };
    """]
    invokables = invokables_from(headers)
    unreachable, stale, active = analyse_methods(
        invokables,
        "Item { Component.onCompleted: { Alpha.ping(); Beta.reserved() } }",
        set(),
        {"Beta.reserved"},
    )
    if unreachable != {"Beta.ping"}:
        raise SystemExit(f"FAIL: homonym result={sorted(unreachable)}")
    if stale != {"Beta.reserved"} or active:
        raise SystemExit(f"FAIL: reservation result stale={sorted(stale)} active={sorted(active)}")
    print("check-orfaos-selftest: homonyms and reservations scoped by type")


if MODE == "--self-test":
    self_test()
    raise SystemExit(0)

src = Path("src")
qml_files = sorted(src.glob("*.qml"))
qml_by_file = {path: path.read_text(encoding="utf-8") for path in qml_files}
all_qml = "\n".join(qml_by_file.values())
failures = 0

for path in qml_by_file:
    name = path.stem
    if name in QML_OK:
        continue
    use = re.compile(rf"(^|[^A-Za-z0-9_]){re.escape(name)}\s*\{{", re.MULTILINE)
    if not any(use.search(other_text) for other_path, other_text in qml_by_file.items()
               if other_path != path):
        print(f"ÓRFÃO QML: {name} — existe no disco, nenhum outro QML o instancia")
        failures += 1

headers = [path.read_text(encoding="utf-8") for path in sorted(src.glob("*.h"))]
invokables = invokables_from(headers)
unreachable, stale_reserves, active_reserves = analyse_methods(
    invokables, all_qml, CPP_OK, CPP_RESERVA)

for pair in sorted(unreachable):
    print(f"NUNCA CHAMADO: {pair} — motor pronto sem botão que chegue nele")
    failures += 1
for pair in sorted(stale_reserves):
    reason = "a UI já chama o método" if pair in invokables else "o método não existe mais"
    print(f"RESERVA OBSOLETA: {pair} — {reason}; remova a reserva")
    failures += 1

print("----------------------------------------")
if active_reserves:
    print("em reserva declarada, esperando tela: " + " ".join(sorted(active_reserves)))
print(f"check-orfaos: {failures} item(ns) sem porta de entrada")
raise SystemExit(1 if failures else 0)
PY
