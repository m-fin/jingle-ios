#!/usr/bin/env python3
"""Synthesize Jingle's original alarm tones.

These are simple generated waveforms (sines, partials, filtered noise).
No samples, no melodies copied from existing alarm clocks or songs.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
random.seed(14)


def mix_into(base: list[float], extra: list[float], start: int) -> None:
    need = start + len(extra)
    if len(base) < need:
        base.extend([0.0] * (need - len(base)))
    for i, sample in enumerate(extra):
        base[start + i] += sample


def env_note(
    freq: float,
    dur: float,
    vol: float = 0.35,
    decay: float = 1.8,
    harmonics: tuple[tuple[float, float], ...] = ((1, 1.0), (2, 0.22), (3, 0.08)),
) -> list[float]:
    count = int(dur * RATE)
    attack = max(1, int(0.018 * RATE))
    release = max(1, int(0.06 * RATE))
    out: list[float] = []
    for i in range(count):
        if i < attack:
            envelope = i / attack
        elif i > count - release:
            envelope = max(0.0, (count - i) / release)
        else:
            envelope = 1.0
        envelope *= math.exp(-decay * i / max(1, count))
        sample = 0.0
        for harmonic, amp in harmonics:
            sample += amp * math.sin(2 * math.pi * freq * harmonic * i / RATE)
        out.append(vol * envelope * sample)
    return out


def normalize(samples: list[float], peak: float = 0.86) -> list[float]:
    loudest = max(1e-9, max(abs(sample) for sample in samples))
    gain = peak / loudest
    return [max(-1.0, min(1.0, sample * gain)) for sample in samples]


def write(name: str, samples: list[float]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))
            for sample in normalize(samples)
        )
        handle.writeframes(frames)
    print(f"{name}: {len(samples) / RATE:.2f}s")


def dawn() -> list[float]:
    notes = [261.63, 329.63, 392.00, 493.88, 587.33, 493.88, 392.00]
    base: list[float] = []
    cursor = 0
    step = int(2.15 * RATE)
    for freq in notes:
        mix_into(base, env_note(freq, 2.7, vol=0.32, decay=1.15, harmonics=((1, 1), (2, 0.18), (3, 0.05))), cursor)
        cursor += step
    mix_into(base, env_note(130.81, len(base) / RATE, vol=0.12, decay=0.35, harmonics=((1, 1), (2, 0.08))), 0)
    return base


def bell() -> list[float]:
    base: list[float] = []
    for index, start in enumerate((0.0, 2.4, 4.8, 7.2, 9.6, 12.0)):
        freq = 698.46 if index % 2 == 0 else 880.0
        mix_into(
            base,
            env_note(freq, 2.8, vol=0.4, decay=3.2, harmonics=((1, 1), (2.01, 0.45), (2.97, 0.22), (4.15, 0.1), (5.43, 0.05))),
            int(start * RATE),
        )
    return base


def pulse() -> list[float]:
    count = int(18 * RATE)
    out = [0.0] * count
    on = int(0.16 * RATE)
    gap = int(0.14 * RATE)
    cursor = 0
    step = 0
    while cursor < count - on:
        freq = 493.88 if step % 2 == 0 else 739.99
        volume = 0.28 + 0.14 * min(1, cursor / (count * 0.75))
        tone = env_note(freq, on / RATE, vol=volume, decay=0.4, harmonics=((1, 1), (2, 0.12)))
        for offset, sample in enumerate(tone):
            if cursor + offset < count:
                out[cursor + offset] += sample
        cursor += on + gap
        step += 1
    return out


def chime() -> list[float]:
    motif = [349.23, 440.0, 523.25, 392.0, 329.63, 523.25, 440.0, 349.23]
    base: list[float] = []
    cursor = 0
    for freq in motif:
        mix_into(base, env_note(freq, 0.85, vol=0.38, decay=2.4, harmonics=((1, 1), (2, 0.3), (3, 0.08))), cursor)
        cursor += int(0.62 * RATE)
    cursor += int(0.4 * RATE)
    for freq in (523.25, 659.25, 783.99):
        mix_into(base, env_note(freq, 0.9, vol=0.3, decay=2.2, harmonics=((1, 1), (2, 0.25))), cursor)
        cursor += int(0.7 * RATE)
    return base


def machine() -> list[float]:
    count = int(16 * RATE)
    out: list[float] = []
    noise = 0.0
    for i in range(count):
        noise = noise * 0.94 + random.uniform(-1, 1) * 0.06
        swell = 0.5 - 0.5 * math.cos(2 * math.pi * i / count)
        trem = 0.85 + 0.15 * math.sin(2 * math.pi * 0.18 * i / RATE)
        drone = 0.22 * math.sin(2 * math.pi * 98.0 * i / RATE)
        drone += 0.14 * math.sin(2 * math.pi * 146.83 * i / RATE)
        drone += 0.05 * math.sin(2 * math.pi * 196.0 * i / RATE)
        out.append(swell * trem * (0.22 * noise + drone))
    return out


def main() -> None:
    write("dawn.wav", dawn())
    write("bell.wav", bell())
    write("pulse.wav", pulse())
    write("chime.wav", chime())
    write("machine.wav", machine())


if __name__ == "__main__":
    main()
