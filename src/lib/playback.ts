import { createAudioPlayer, setAudioModeAsync, type AudioPlayer } from "expo-audio";

let player: AudioPlayer | null = null;

export async function playSound(source: number, options: { loop?: boolean; volume?: number } = {}): Promise<void> {
  await stopSound();
  try {
    await setAudioModeAsync({
      playsInSilentMode: true,
      interruptionMode: "doNotMix",
    });
  } catch {
    // Web and some simulators have no audio session. Playback still tries below.
  }
  try {
    const next = createAudioPlayer(source);
    next.loop = options.loop ?? false;
    next.volume = options.volume ?? 1;
    next.play();
    player = next;
  } catch {
    player = null;
  }
}

export async function stopSound(): Promise<void> {
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
