#!/bin/bash
# Збірка для PortMaster: game/ -> port/littlerescuers/gamedata/ -> dist/LittleRescuers.zip
set -euo pipefail
cd "$(dirname "$0")"
echo "== фрази й озвучка"
python3 tools/check_voices.py
if command -v luacheck >/dev/null; then echo "== luacheck"; luacheck game; fi
echo "== game/ -> port/littlerescuers/gamedata/"
rm -rf port/littlerescuers/gamedata
mkdir -p port/littlerescuers/gamedata
(cd game && tar cf - --exclude dev.lua --exclude '*.wav' --exclude .DS_Store .) | (cd port/littlerescuers/gamedata && tar xf -)
mkdir -p dist
rm -f dist/LittleRescuers.zip
(cd port && zip -qr ../dist/LittleRescuers.zip LittleRescuers.sh littlerescuers \
    -x 'littlerescuers/save/*' 'littlerescuers/log.txt' '*.DS_Store')
echo "готово: dist/LittleRescuers.zip ($(du -h dist/LittleRescuers.zip | cut -f1))"
