#!/usr/bin/env bash
set -euo pipefail

files=(
    src/CollectionsPane.qml
    src/FolderPickerDialog.qml
    src/LibraryPane.qml
    src/PodcastPane.qml
    src/QueueOverlay.qml
    src/SearchOverlay.qml
)

failed=0
for file in "${files[@]}"; do
    list_count=$(awk '/^[[:space:]]*ListView[[:space:]]*\{/{count++} END{print count+0}' "$file")
    reuse_count=$(awk '/^[[:space:]]*reuseItems:[[:space:]]*true/{count++} END{print count+0}' "$file")
    if [[ "$list_count" -ne "$reuse_count" ]]; then
        echo "$file: $reuse_count/$list_count ListViews enable reuseItems"
        failed=1
    fi
done

if [[ "$failed" -ne 0 ]]; then
    exit 1
fi

echo "check-list-reuse: every ListView recycles delegates"
