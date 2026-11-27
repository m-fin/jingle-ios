/// <reference types="expo/types" />

declare module "*.png" {
  const value: number;
  export default value;
}

declare module "*.wav" {
  const value: number;
  export default value;
}

declare module "*.jpg" {
  const value: number;
  export default value;
}

declare module "av" {
  interface AVFormat {
    sampleRate?: number;
    channelsPerFrame?: number;
  }
  interface AVAsset {
    format?: AVFormat;
    on(event: "error", handler: (error: unknown) => void): void;
    decodeToBuffer(callback: (buffer: Float32Array) => void): void;
  }
  const AV: {
    Asset: {
      fromBuffer(input: Uint8Array): AVAsset;
    };
  };
  export default AV;
}

declare module "mp3" {}
