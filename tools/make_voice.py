"""Озвучує фрази з phrases.py голосами ElevenLabs -> game/assets/voice/<id>.ogg.
  python3 tools/make_voice.py            озвучити лише те, чого ще немає
  python3 tools/make_voice.py --estimate скільки символів піде
Ключ — у ~/.elevenlabs_key. Потрібні ffmpeg (mp3 -> wav) і pip install soundfile (wav -> ogg)."""
import json, os, subprocess, sys, tempfile, urllib.request
from phrases import PHRASES
from voices import VOICES, SPEAKERS, MODEL, SETTINGS
from wav2ogg import encode

here = os.path.dirname(os.path.abspath(__file__))
out_dir = os.path.join(here, "..", "game", "assets", "voice")
mp3_dir = os.path.join(here, "voice_mp3")
todo = [(pid, who, text) for pid, (who, text) in PHRASES.items()
        if not os.path.exists(os.path.join(out_dir, pid + ".ogg"))]
if "--estimate" in sys.argv:
    print(f"{len(todo)} фраз, {sum(len(t) for _, _, t in todo)} символів")
    sys.exit(0)
key = open(os.path.expanduser("~/.elevenlabs_key")).read().strip()
os.makedirs(out_dir, exist_ok=True)
os.makedirs(mp3_dir, exist_ok=True)
for pid, who, text in todo:
    mp3 = os.path.join(mp3_dir, pid + ".mp3")
    if not os.path.exists(mp3):
        body = json.dumps({"text": text, "model_id": MODEL, "language_code": "uk", "voice_settings": SETTINGS}).encode()
        req = urllib.request.Request(
            f"https://api.elevenlabs.io/v1/text-to-speech/{VOICES[SPEAKERS[who]]}?output_format=mp3_44100_128",
            data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
        with urllib.request.urlopen(req) as r, open(mp3, "wb") as f:
            f.write(r.read())
    with tempfile.TemporaryDirectory() as td:
        wav = os.path.join(td, "a.wav")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", mp3, "-ac", "1", "-ar", "22050", wav], check=True)
        encode(wav, os.path.join(out_dir, pid + ".ogg"))
    print("ok", pid)
