"""Звіряє фрази в коді з tools/phrases.py і перелічує неозвучені (tools/voice_todo.txt).
Помилка (код 1), якщо код грає фразу, якої немає в phrases.py, або в місії бракує обов'язкових фраз."""
import glob, os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from phrases import PHRASES
from voices import SPEAKERS

game = os.path.join(here, "..", "game")
errors = []
for pid, (who, _) in PHRASES.items():
    if who not in SPEAKERS:
        errors.append(f"{pid}: невідомий персонаж {who}")

used = set()
for path in glob.glob(os.path.join(game, "**", "*.lua"), recursive=True):
    src = open(path, encoding="utf-8").read()
    src = re.sub(r"--[^\n]*", "", src)
    used |= set(re.findall(r'voice\(\s*"(\w+)"\s*\)', src))
    for lst in re.findall(r'voiceList\(\s*\{([^}]*)\}', src):
        used |= set(re.findall(r'(?:^|,)\s*"(\w+)"\s*(?=,|$)', lst.strip()))
    m = re.search(r'\bid\s*=\s*"(\w+)"\s*,\s*vehicle', src)
    if m:
        mid = m.group(1)
        used |= {mid + "_intro", mid + "_go"}
        r = re.search(r'rescued\s*=\s*"(\w+)"', src)
        if r:
            used.add("thanks_" + r.group(1))
unknown = sorted(u for u in used if u not in PHRASES)
if unknown:
    errors.append("у коді є фрази, яких немає в phrases.py: " + " ".join(unknown))

voice_dir = os.path.join(game, "assets", "voice")
missing = [p for p in PHRASES if not os.path.exists(os.path.join(voice_dir, p + ".ogg"))]
with open(os.path.join(here, "voice_todo.txt"), "w", encoding="utf-8") as f:
    for p in missing:
        f.write(f"{p}\t{PHRASES[p][0]}\t{PHRASES[p][1]}\n")
if missing:
    print(f"УВАГА: неозвучено {len(missing)} з {len(PHRASES)} фраз (tools/voice_todo.txt; озвучити: python3 tools/make_voice.py)")
if errors:
    print("\n".join("ПОМИЛКА: " + e for e in errors))
    sys.exit(1)
print(f"гаразд: {len(PHRASES)} фраз, у коді {len(used)}")
