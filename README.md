# Маленькі рятувальники — розробка

Гра на LÖVE 11.5 для приставок Anbernic через PortMaster, для дітей 4–6 років.
Пожежна машина, поліція, вертоліт і рятувальний човен виконують завдання Капітана Бобра.
Стиль — гладка векторна графіка (без пікселів): логічний екран 640x480, масштабується під будь-який екран.

- `game/` — код і ресурси. Запуск: `love game`.
- `./build.sh` — перевіряє фрази й luacheck, пакує `dist/LittleRescuers.zip` для PortMaster.

## Код

- `main.lua` — запуск, масштаб, кадр.
- `core/` — `draw` (фігури, тіні, градієнти, звірята, вогник), `vehicles` (4 машини), `input`
  (кнопки й утримання), `sound` (озвучка + згенеровані звуки), `fx` (частинки), `save`, `screens`.
- `screens/` — `title`, `station` (вибір машини й місії), `mission` (рація → місія → зірочки).
- `missions/` — `list.lua` (усі місії по машинах), `kit.lua` (спільне: дорога-переїзд, табло,
  небо, капітан), `<id>.lua` — по файлу на місію (зразок — `fire1.lua`).

### Як додати місію
1. `game/missions/<id>.lua`: таблиця `M = { id, vehicle, rescued, intro = "<id>_intro", icon = fn }`,
   `M.new()` повертає об'єкт з `update(dt)` (true — пройдено), `draw()`, `stars()` (1–3),
   необов'язково `press(name)`, `leave()` і `bot()` (для автотесту).
2. Додати id у `missions/list.lua`.
3. Фрази `<id>_intro`, `<id>_go`, свої й `thanks_<rescued>` — у `tools/phrases.py`.

## Перевірка
- `LR_TEST=1 love game` — проходить усі місії ботами, робить знімки в `~/.local/share/love/littlerescuers/`.
- `LR_TEST=<id> love game` — одна місія.
- `luacheck game`.

## Озвучка
- `tools/phrases.py` — усі фрази (хто говорить і текст), `tools/voices.py` — голоси ElevenLabs.
- `python3 tools/check_voices.py` — перевірка; неозвучені пише в `tools/voice_todo.txt`.
- `python3 tools/make_voice.py` — озвучити відсутні (ключ у `~/.elevenlabs_key`). Без файлів гра просто мовчить.
