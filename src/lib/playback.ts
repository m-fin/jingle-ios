import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from "expo-audio";

let player: AudioPlayer | null = null;
let fadeTimer: ReturnType<typeof setInterval> | null = null;
let generation = 0;

const FADE_STEPS = 20;

export async function playSound(
  source: number | string,
  options: { loop?: boolean; volume?: number; fadeInMs?: number } = {},
): Promise<void> {
  await stopSound();
  const token = generation;
  try {
    await setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
    });
  } catch {
    // Web and some simulators have no audio session. Playback still tries below.
  }
  if (token !== generation) return;
  try {
    const next = createAudioPlayer(source);
    const target = options.volume ?? 1;
    const fadeInMs = options.fadeInMs ?? 0;
    next.loop = options.loop ?? false;
    next.volume = fadeInMs > 0 ? 0 : target;
    next.play();
    if (token !== generation) {
      try {
        next.pause();
        next.remove();
      } catch {
        // A newer play or stop already replaced this player.
      }
      return;
    }
    player = next;
    if (fadeInMs > 0) {
      const stepMs = Math.max(16, Math.round(fadeInMs / FADE_STEPS));
      let step = 0;
      fadeTimer = setInterval(() => {
        if (token !== generation || player !== next) {
          if (fadeTimer) clearInterval(fadeTimer);
          fadeTimer = null;
          return;
        }
        step += 1;
        const gain = Math.sin((Math.min(step, FADE_STEPS) / FADE_STEPS) * (Math.PI / 2));
        try {
          next.volume = target * gain;
        } catch {
          // The player was released.
        }
        if (step >= FADE_STEPS && fadeTimer) {
          clearInterval(fadeTimer);
          fadeTimer = null;
        }
      }, stepMs);
    }
  } catch {
    player = null;
  }
}

export async function stopSound(): Promise<void> {
  generation += 1;
  if (fadeTimer) {
    clearInterval(fadeTimer);
    fadeTimer = null;
  }
  const current = player;
  player = null;
  if (!current) return;
  try {
    current.pause();
    current.remove();
  } catch {
    // The player was already released.
  }
}
