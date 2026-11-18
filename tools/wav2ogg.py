"""Переводить озвучку game/assets/voice/**.wav в OGG Vorbis (LÖVE читає OGG напряму).
  pip install soundfile     (потрібен один раз; містить libsndfile з Vorbis)
  python3 wav2ogg.py        конвертує все; оригінали WAV переносить у tools/voice_wav/
Також використовується з make_voice_uk.py для нових фраз (функція encode)."""
import os, shutil, sys
import soundfile as sf

here = os.path.dirname(os.path.abspath(__file__))
voice_root = os.path.join(here, "..", "game", "assets", "voice")
backup_root = os.path.join(here, "voice_wav")
QUALITY = 0.35   # 0..1 (стиснення libsndfile); для мови 22 кГц моно цього досить


def encode(wav, ogg):
    data, rate = sf.read(wav, dtype="float32")
    sf.write(ogg, data, rate, format="OGG", subtype="VORBIS", compression_level=QUALITY)


def main():
    n, before, after = 0, 0, 0
    for d, _, files in os.walk(voice_root):
        for f in sorted(files):
            if not f.endswith(".wav"):
                continue
            wav = os.path.join(d, f)
            ogg = wav[:-4] + ".ogg"
            encode(wav, ogg)
            before += os.path.getsize(wav)
            after += os.path.getsize(ogg)
            dst = os.path.join(backup_root, os.path.relpath(wav, voice_root))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.move(wav, dst)
            n += 1
    print(f"файлів: {n}, було {before / 1e6:.1f} МБ, стало {after / 1e6:.1f} МБ")


if __name__ == "__main__":
    main()
