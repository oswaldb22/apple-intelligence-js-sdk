# Apple Intelligence JS SDK

Access Apple Intelligence on macOS through a standard, OpenAI-compatible JavaScript/TypeScript SDK.

This library allows you to build AI-powered Node.js applications that run entirely on-device using the Foundation Models built into macOS 15.1+ on Apple Silicon.

## Features

- 🔒 **Privacy-First**: All inference runs locally on your device. No data leaves your Mac.
- 🚀 **Hardware Accelerated**: Optimized for Apple Silicon Neural Engine.
- 🧩 **OpenAI Compatible**: Drop-in replacement for the official OpenAI SDK.
- 📦 **Zero-Config**: Automatically handles the local inference server lifecycle.

## Requirements

- **Hardware**: Mac with Apple Silicon (M1, M2, M3, or later).
- **OS**: macOS 15.1 (Sequoia) or later.
- **Feature**: Apple Intelligence must be enabled in System Settings.

## Installation

```bash
npm install apple-intelligence-js-sdk openai
```

The package automatically attempts to install the platform-specific binary (`@apple-intelligence-js-sdk/darwin-arm64`) as an optional dependency.

## Usage

### Quick Start

The easiest way to get started is using the helper to create a configured OpenAI client:

```typescript
import { createOpenAIClient } from "apple-intelligence-js-sdk";

async function main() {
  // Automatically launches the local inference server if needed
  const openai = await createOpenAIClient();

  const completion = await openai.chat.completions.create({
    model: "base", // Maps to the system's default large language model
    messages: [{ role: "user", content: "Tell me a joke about coding." }],
    stream: true,
  });

  for await (const chunk of completion) {
    process.stdout.write(chunk.choices[0]?.delta?.content || "");
  }
}

main();
```

### Testing with `curl`

You can verify the OpenAI-compatible server is working directly from your terminal. If you know the port (e.g., `12345`), run:

```bash
curl http://localhost:12345/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "base",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

### Advanced Usage

If you want more control over the lifecycle or configuration:

```typescript
import {
  ensureAppleIntelligence,
  shutdownAppleIntelligence,
} from "apple-intelligence-js-sdk";
import OpenAI from "openai";

async function main() {
  // Launch server and wait for readiness
  const { baseURL, port, pid } = await ensureAppleIntelligence({
    logLevel: "info", // 'silent' | 'info' | 'debug'
    timeoutMs: 10000,
  });

  console.log(`Server running on port ${port} (PID: ${pid})`);

  const client = new OpenAI({
    baseURL: baseURL,
    apiKey: "local", // API key is ignored but required by SDK
  });

  // ... facilitate chat ...

  // Optional: Shutdown when done
  // await shutdownAppleIntelligence();
}
```

## Troubleshooting

If you encounter issues, the package includes a "doctor" command to diagnose your environment:

```bash
npx apple-intelligence-doctor
```

This will check:

- OS and Architecture compatibility
- Presence of the helper app binary
- Server status and reachability

## Architecture

This project consists of two main components:

1.  **Swift Server (`AppleIntelligenceServer.app`)**: A lightweight macOS menu bar application that bridges the system's `Measurement` and `GenerativeFunctions` APIs to an HTTP server running on `localhost`.
2.  **Node.js Wrapper**: A library that manages the background process of the Swift server and provides the client configuration.

## Development

This repository is a monorepo managed with npm workspaces (conceptual).

### Prerequisites

- Xcode 15+ (with macOS 15 SDK)
- Node.js 20+

### Building the Server

To build the Swift server binary from source:

```bash
./scripts/build-helper.sh
```

This will compile the Swift sources in `apps/AppleIntelligenceServer` and place the result in `packages/@apple-intelligence-js-sdk/darwin-arm64`.

### Building the Wrapper

```bash
cd packages/apple-intelligence-js-sdk
npm install
npm run build
```

## Models

The generic model names mapped by the server:

- `base`: The standard system monitoring model.
- `permissive`: A variant with looser guardrails (if supported by system).

## License

MIT
