#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");

console.log("Apple Intelligence JS SDK Doctor");
console.log("================================");

// 1. Check OS/Arch
const platform = os.platform();
const arch = os.arch();
console.log(`OS: ${platform}`);
console.log(`Arch: ${arch}`);

if (platform !== "darwin" || arch !== "arm64") {
  console.warn(
    "⚠️  Warning: This SDK is designed for macOS (Apple Silicon). Your environment may not be supported."
  );
} else {
  console.log("✅ OS/Arch supported");
}

// 2. Check App Bundle
// Try to locate it based on where this script is installed
// In dev: .../packages/apple-intelligence-js-sdk/bin/doctor.js -> .../apps/AppleIntelligenceServer
// In prod: node_modules/apple-intelligence-js-sdk/bin -> node_modules/@apple-intelligence-js-sdk/darwin-arm64/AppleIntelligenceServer.app

let appPath = null;
const possiblePaths = [
  path.resolve(
    __dirname,
    "../../@oswaldb22/darwin-arm64/AppleIntelligenceServer.app"
  ), // Monorepo/Dev
  path.resolve(
    __dirname,
    "../node_modules/@oswaldb22/apple-intelligence-js-sdk-darwin-arm64/AppleIntelligenceServer.app"
  ), // Prod install
];

for (const p of possiblePaths) {
  if (fs.existsSync(p)) {
    appPath = p;
    break;
  }
}

if (appPath) {
  console.log(`✅ Server App found at: ${appPath}`);
  // Check if executable
  try {
    fs.accessSync(
      path.join(appPath, "Contents/MacOS/AppleIntelligenceServer"),
      fs.constants.x_OK
    );
    console.log("✅ Server App executable check passed");
  } catch (e) {
    console.error("❌ Server App binary is not executable (chmod +x needed?)");
  }
} else {
  console.error(
    "❌ Server App not found. Did you install optional dependencies?"
  );
}

// 3. Check Runtime Dependencies (Swift/macOS)
// We can't easily check for Apple Intelligence enabling without native code, but we can check macOS version
const release = os.release().split(".");
const major = parseInt(release[0], 10);
// Darwin 23 = Sonoma (14), Darwin 24 = Sequoia (15)
if (major >= 24) {
  console.log(`✅ macOS version compatible (Darwin ${major})`);
} else {
  console.warn(
    `⚠️  macOS version (Darwin ${major}) might be too old for Apple Intelligence (requires macOS 26+)`
  );
}

// 4. Check status file
const configDir = path.join(
  os.homedir(),
  "Library",
  "Caches",
  "apple-intelligence-js-sdk"
);
const stateFile = path.join(configDir, "state.json");

if (fs.existsSync(stateFile)) {
  try {
    const state = JSON.parse(fs.readFileSync(stateFile, "utf8"));
    console.log("ℹ️  Server state file found:");
    console.log(state);

    // Try health check
    // fetch is available in Node 18+
    if (state.baseURL) {
      checkHealth(state.baseURL);
    }
  } catch (e) {
    console.error("❌ Invalid state file found");
  }
} else {
  console.log("ℹ️  No active server state file found (server likely stopped)");
}

async function checkHealth(url) {
  try {
    const res = await fetch(`${url}/health`);
    if (res.ok) {
      const data = await res.json();
      console.log("✅ Server is reachable and healthy");
      console.log(data);
    } else {
      console.error(`❌ Server returned ${res.status}`);
    }
  } catch (e) {
    console.error(`❌ Failed to connect to server at ${url}: ${e.message}`);
  }
}
