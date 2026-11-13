#!/usr/bin/env python3
"""Generates the merge tones: Presentation/Resources/merge0…merge10.caf.

One soft, short tone per merged value (4 → merge0 … 2048 → merge9, 4096+ → merge10), climbing a
major-pentatonic scale from A4, so bigger merges sound brighter. A sine with a touch of the octave,
a 4 ms attack and an exponential decay (~110 ms). Our own sounds (no licensing). Run from the repo
root:  python3 tools/make_sounds.py
"""
import math, os, struct, subprocess, tempfile, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Presentation", "Resources")
PENTATONIC = [0, 2, 4, 7, 9]  # semitones

def frequency(index):
    octave, degree = divmod(index, len(PENTATONIC))
    return 440.0 * 2 ** ((octave * 12 + PENTATONIC[degree]) / 12)

def tone(freq, duration=0.14, volume=0.32):
    samples = []
    n = int(RATE * duration)
    for i in range(n):
        t = i / RATE
        attack = min(1.0, t / 0.004)
        decay = math.exp(-t / 0.045)
        s = math.sin(2 * math.pi * freq * t) + 0.18 * math.sin(4 * math.pi * freq * t)
        samples.append(volume * attack * decay * s / 1.18)
    return samples

os.makedirs(OUT, exist_ok=True)
with tempfile.TemporaryDirectory() as tmp:
    for index in range(11):
        wav = os.path.join(tmp, f"merge{index}.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in tone(frequency(index))))
        caf = os.path.join(OUT, f"merge{index}.caf")
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16", wav, caf], check=True)
        print(caf, round(frequency(index), 1), "Hz")
