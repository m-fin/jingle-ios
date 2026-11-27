import { requireOptionalNativeModule } from "expo";

type JingleWakeClipNative = {
  exportWakeClip(input: string, output: string): Promise<void>;
};

const native = requireOptionalNativeModule<JingleWakeClipNative>("JingleWakeClip");

export function canExportWakeClip(): boolean {
  return Boolean(native?.exportWakeClip);
}

/** Writes Library/Sounds/catalog-<id>.caf from the first 28 seconds of a local audio file. */
export function exportWakeClip(input: string, output: string): Promise<void> {
  if (!native?.exportWakeClip) return Promise.reject(new Error("wake-clip-unavailable"));
  return native.exportWakeClip(input, output);
}
