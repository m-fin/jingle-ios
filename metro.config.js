const path = require("path");
const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);
const speakerShim = path.join(__dirname, "src/shims/speaker.js");
const emptyShim = path.join(__dirname, "src/shims/empty.js");
const avEntry = path.join(__dirname, "node_modules/av/node.js");

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === "speaker") {
    return { type: "sourceFile", filePath: speakerShim };
  }
  // The published `av` package points its browser entry at CoffeeScript that is not in the tarball.
  // Node's compiled entry can decode a buffer. Its file/http sources need Node built-ins, which Jingle does not use.
  if (moduleName === "av") {
    return { type: "sourceFile", filePath: avEntry };
  }
  const fromAv = context.originModulePath.includes(`${path.sep}node_modules${path.sep}av${path.sep}`);
  const nodeSource = moduleName.endsWith("sources/node/http") || moduleName.endsWith("sources/node/file") || moduleName.endsWith(".coffee");
  if (fromAv && nodeSource) {
    return { type: "sourceFile", filePath: emptyShim };
  }
  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
