#!/usr/bin/env bash
set -euo pipefail

if rg -q 'id:[[:space:]]*prefsAudio|AudioEngine\.setReplayGainMode\(prefsAudio|AudioEngine\.setExclusiveOutput\(prefsAudio' src/Main.qml; then
    echo "FAIL: Main.qml reapplies a second QML preference source over AudioEngine startup state"
    exit 1
fi

for key in playback/volume playback/podcastSpeed audio/replayGainMode \
           audio/gaplessAggressive audio/exclusiveOutput; do
    if ! rg -q "${key}" src/audioengine.cpp tests/tst_audioengine.cpp; then
        echo "FAIL: persisted audio key is not covered: ${key}"
        exit 1
    fi
done

echo "check-audio-preferences: one startup owner and five persisted audio preferences"
