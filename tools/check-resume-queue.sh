#!/usr/bin/env bash
# Persist a two-track queue in one app process and restore it in a second. The database also
# claims that the current track stopped at 7 s: the restored music must ignore that timestamp.
set -uo pipefail

BIN="${1:-./build/melodarium}"
if [ ! -x "$BIN" ]; then
    echo "check-resume-queue: executable not found: $BIN"
    exit 1
fi
for command in ffmpeg sqlite3; do
    if ! command -v "$command" >/dev/null; then
        echo "check-resume-queue: $command is required"
        exit 1
    fi
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/config" "$TMP/data" "$TMP/cache" "$TMP/media"

TRACK_A="$TMP/media/a.flac"
TRACK_B="$TMP/media/b.flac"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=440:d=12' -y "$TRACK_A"
ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=660:d=12' -y "$TRACK_B"

run_app() {
    QT_LOGGING_RULES='*.debug=true' \
    QT_FORCE_STDERR_LOGGING=1 \
    QT_QPA_PLATFORM=offscreen \
    MELODIA_NULL_AO=1 \
    XDG_CONFIG_HOME="$TMP/config" \
    XDG_DATA_HOME="$TMP/data" \
    XDG_CACHE_HOME="$TMP/cache" \
        timeout 60 "$BIN" "$@" 2>&1
}

if ! run_app --measure 1100 --measure-height 700 --no-search --delay 50 >/dev/null; then
    echo "check-resume-queue: failed to initialize the temporary database"
    exit 1
fi

DB="$TMP/data/melodarium/melodarium/melodarium.db"
sqlite3 "$DB" <<SQL
INSERT INTO artists (id, name) VALUES (301, 'Queue Artist');
INSERT INTO albums (id, title, album_artist_id, year)
VALUES (301, 'Queue Album', 301, 2026);
INSERT INTO tracks
    (id, path, mtime, size, title, artist_id, album_id, disc_no, track_no,
     duration_ms, added_at)
VALUES (301, '$TRACK_A', 1, 1, 'Queue A', 301, 301, 1, 1, 12000, 1),
       (302, '$TRACK_B', 1, 1, 'Queue B', 301, 301, 1, 2, 12000, 2);
INSERT INTO track_stats
    (track_id, play_count, skip_count, last_played_at, first_seen_at, last_position_ms)
VALUES (302, 1, 0, 2000000000, 1, 7000);
SQL

# First process: build the full queue and leave it on the second entry.
first=$(run_app --measure 1100 --measure-height 700 --no-search --play-queue \
    --play-queue-mode all --queue-index 1 --delay 1200)
first_line=$(printf '%s\n' "$first" | grep -ao 'MEDIDA .*' | tail -1)
if ! printf '%s\n' "$first_line" | rg -q "fila=2 queuepos=1 .*arquivo=$TRACK_B"; then
    echo "FAIL: first process did not persist the expected queue: $first_line"
    exit 1
fi

# Second process: the UI's real resume action must restore both entries at index 1 and start
# near zero. The old implementation would load one track and seek to the database's 7 s.
second=$(run_app --measure 1100 --measure-height 700 --no-search --play-queue \
    --play-queue-mode resume --delay 1200)
second_line=$(printf '%s\n' "$second" | grep -ao 'MEDIDA .*' | tail -1)
if ! printf '%s\n' "$second_line" | rg -q "fila=2 queuepos=1 .*arquivo=$TRACK_B"; then
    echo "FAIL: resume did not restore queue + index: $second_line"
    exit 1
fi

seconds=$(printf '%s\n' "$second_line" | sed -n 's/.* segundos=\([0-9.]*\) arquivo=.*/\1/p')
if ! awk -v seconds="$seconds" 'BEGIN { exit !(seconds >= 0 && seconds < 2.0) }'; then
    echo "FAIL: resumed music at ${seconds:-unknown}s instead of 0:00: $second_line"
    exit 1
fi

echo "check-resume-queue: restored 2 tracks at index 1 from ${seconds}s"
