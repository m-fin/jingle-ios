import { Platform } from "react-native";
import { useKeepAwake } from "expo-keep-awake";

function NativeKeepAwake() {
  useKeepAwake();
  return null;
}

export function KeepAwake() {
  if (Platform.OS === "web") return null;
  return <NativeKeepAwake />;
}
