import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import { spawn } from "child_process";

const CONFIG_DIR = path.join(
  os.homedir(),
  "Library",
  "Caches",
  "apple-intelligence-js-sdk"
);
const STATE_FILE = path.join(CONFIG_DIR, "state.json");

interface ServerState {
  ready: boolean;
  pid: number;
  port: number;
  baseURL: string;
  token?: string;
  version: string;
  startedAt: number;
}

export interface EnsureOptions {
  timeoutMs?: number;
  logLevel?: "silent" | "info" | "debug";
}

function log(level: string, message: string) {
  if (level !== "silent") {
    console.log(`[AppleIntelligence] ${message}`);
  }
}

export async function ensureAppleIntelligence(
  options: EnsureOptions = {}
): Promise<ServerState> {
  const timeoutMs = options.timeoutMs ?? 20000;
  const logLevel = options.logLevel ?? "info";

  if (!fs.existsSync(CONFIG_DIR)) {
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
  }

  // 1. Check if running
  const state = readState();
  if (state) {
    // Verify health
    if (await checkHealth(state.baseURL)) {
      log(logLevel, "Server already running.");
      return state;
    }
    // Stale state file
    log(logLevel, "Removing stale state file.");
    fs.rmSync(STATE_FILE, { force: true });
  }

  // 2. Launch
  log(logLevel, "Launching server...");
  const appPath = getAppPath();

  // Arguments
  // --state, --port 0, etc.
  // Note: open -gj appPath --args ...

  const args = [
    "-gj",
    appPath,
    "--args",
    "--state",
    STATE_FILE,
    "--port",
    "0",
    "--token",
    generateToken(),
  ];

  spawn("open", args, { stdio: "ignore" }).unref();

  // 3. Wait
  const startTime = Date.now();
  while (Date.now() - startTime < timeoutMs) {
    const newState = readState();
    if (newState && (await checkHealth(newState.baseURL))) {
      log(logLevel, "Server ready.");
      return newState;
    }
    await new Promise((r) => setTimeout(r, 500));
  }

  throw new Error("Timed out waiting for Apple Intelligence Server to start");
}

export async function shutdownAppleIntelligence(): Promise<void> {
  const state = readState();
  if (!state) return;

  try {
    await fetch(`${state.baseURL}/admin/shutdown`, {
      method: "POST",
      headers: { Authorization: `Bearer ${state.token}` },
    });
  } catch (e) {
    // ignore
  }

  try {
    fs.unlinkSync(STATE_FILE);
  } catch (e) {}
}

function readState(): ServerState | null {
  try {
    if (!fs.existsSync(STATE_FILE)) return null;
    const content = fs.readFileSync(STATE_FILE, "utf-8");
    return JSON.parse(content) as ServerState;
  } catch {
    return null;
  }
}

async function checkHealth(baseURL: string): Promise<boolean> {
  try {
    const res = await fetch(`${baseURL}/health`);
    return res.ok;
  } catch {
    return false;
  }
}

function getAppPath(): string {
  // Logic to find .app from optionalDependencies or dev location
  // For dev:
  const devPath = path.resolve(
    __dirname,
    "../../../../apps/AppleIntelligenceServer/AppleIntelligenceServer.app"
  );
  // Wait, I haven't built the app yet in the folder structure, but assuming development mode or installed package:

  try {
    // Try to resolve from platform package
    const pkg = require.resolve(
      "@oswaldb22/apple-intelligence-js-sdk-darwin-arm64/package.json"
    );
    const dir = path.dirname(pkg);
    return path.join(dir, "AppleIntelligenceServer.app");
  } catch (e) {
    // Fallback to dev path
    // Note: The dev path assumes we build it there.
    // For now, return a placeholder or dev path
    return (
      process.env.APPLE_INTELLIGENCE_APP_PATH ||
      path.resolve(
        __dirname,
        "../../../../apps/AppleIntelligenceServer/AppleIntelligenceServer.app"
      )
    );
  }
}

function generateToken(): string {
  return Math.random().toString(36).substring(2);
}
