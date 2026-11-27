import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from "expo-audio";

let player: AudioPlayer | null = null;
let playToken = 0;

export async function playSound(
  source: number | string,
  options: { loop?: boolean; volume?: number; fadeMs?: number } = {},
): Promise<void> {
  await stopSound();
  const token = playToken;
  try {
    await setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
    });
  } catch {
    // Web and some simulators have no audio session. Playback still tries below.
  }
  if (token !== playToken) return;
  try {
    const next = createAudioPlayer(source);
    const target = options.volume ?? 1;
    const fadeMs = options.fadeMs ?? 0;
    next.loop = options.loop ?? false;
    next.volume = fadeMs > 0 ? 0 : target;
    next.play();
    player = next;
    if (fadeMs <= 0) return;
    const steps = 28;
    let step = 0;
    const timer = setInterval(() => {
      if (token !== playToken) {
        clearInterval(timer);
        return;
      }
      step += 1;
      const position = Math.min(1, step / steps);
      const eased = 0.5 - 0.5 * Math.cos(Math.PI * position);
      try {
        next.volume = target * eased;
      } catch {
        clearInterval(timer);
        return;
      }
      if (step >= steps) clearInterval(timer);
    }, Math.max(16, Math.round(fadeMs / steps)));
  } catch {
    player = null;
  }
}

export async function stopSound(): Promise<void> {
  playToken += 1;
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
