import type { SoundId } from "./types";

/** Filenames of the original tones bundled with the app and copied for notifications. */
export const BUNDLED_SOUND_FILES: Record<SoundId | "machine", string> = {
  dawn: "dawn.wav",
  bell: "bell.wav",
  pulse: "pulse.wav",
  chime: "chime.wav",
  machine: "machine.wav",
};

/** Bundled tone used when a catalog file is missing. Alarms must still ring. */
export const DEFAULT_WAKE_SOUND: SoundId = "dawn";

export function bundledSoundFile(id: SoundId | "machine"): string {
  return BUNDLED_SOUND_FILES[id] ?? BUNDLED_SOUND_FILES[DEFAULT_WAKE_SOUND];
}
