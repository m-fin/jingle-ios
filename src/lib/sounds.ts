import type { SoundId } from "./types";

export type SoundMeta = {
  id: SoundId;
  name: string;
  detail: string;
  file: string;
  source: number;
};

export const SOUND_LIST: SoundMeta[] = [
  {
    id: "dawn",
    name: "Dawn",
    detail: "Slow rising tones",
    file: "dawn.wav",
    source: require("../../assets/sounds/dawn.wav"),
  },
  {
    id: "bell",
    name: "Bell",
    detail: "Soft struck partials",
    file: "bell.wav",
    source: require("../../assets/sounds/bell.wav"),
  },
  {
    id: "pulse",
    name: "Pulse",
    detail: "Clear two-note pulse",
    file: "pulse.wav",
    source: require("../../assets/sounds/pulse.wav"),
  },
  {
    id: "chime",
    name: "Chime",
    detail: "A short original phrase",
    file: "chime.wav",
    source: require("../../assets/sounds/chime.wav"),
  },
];

export const SOUNDS: Record<SoundId, SoundMeta> = {
  dawn: SOUND_LIST[0],
  bell: SOUND_LIST[1],
  pulse: SOUND_LIST[2],
  chime: SOUND_LIST[3],
};

export const MACHINE_SOUND = {
  name: "Machine",
  detail: "Quiet drone before the alarm",
  file: "machine.wav",
  source: require("../../assets/sounds/machine.wav"),
};

export function soundFile(id: SoundId | "machine"): string {
  if (id === "machine") return MACHINE_SOUND.file;
  return SOUNDS[id].file;
}
