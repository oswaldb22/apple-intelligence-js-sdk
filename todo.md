# Remaining Tasks

## 1. Core Implementation (Essential)

- [x] **Connect Real Apple Intelligence**:
  - Switch `LanguageModelService` from `MockLanguageModelService` to a real implementation using `GenerativeFunctions` / `SystemLanguageModel` (requires macOS 15.1+ and Entitlements).
  - Ensure the `.entitlements` file includes `com.apple.developer.machine-learning.generative-models` (or appropriate capability).
- [x] **Fix Port Copying in UI**:
  - In `AppDelegate.swift`, the "Copy Base URL" menu item currently hardcodes port `0`. Update it to read the actual bound port from the started application server.

## 2. Hardening & Security

- [ ] **Implement Concurrency Throttling**:
  - Add an `AsyncSemaphore` or actor-based queue in `ChatController` or `LanguageModelService` to limit concurrent inference requests (e.g., max 1 active generation) to prevent crashing the system service.
- [ ] **Secure Admin Endpoints**:
  - In `routes.swift`, the `/admin/shutdown` endpoint has a TODO to add correct Bearer token authentication middleware. Currently, it just accepts the request (logic was "implemented" but check the actual verification of the token in the middleware chain).

## 3. Build & Distribution

- [ ] **Code Signing & Notarization**:
  - Update `scripts/build-helper.sh` or create `scripts/sign-notarize.sh` to:
    - Sign the `.app` with a Developer ID Application certificate.
    - Submit for notarization using `notarytool`.
    - Staple the notarization ticket.
  - This is critical for avoiding "App is damaged" warnings on other user's machines.
- [ ] **CI/CD Configuration**:
  - Add `NPM_TOKEN` to GitHub Actions secrets.
  - Add `APPLE_ID`, `APPLE_ID_PASSWORD`, and signing certificates if running automated signing in CI.

## 4. Testing

- [ ] **Verify on Apple Silicon**:
  - Run `./scripts/build-helper.sh` on a machine with Xcode installed to verify the build process (checking for `PackageDescription` linker issues).
- [ ] **End-to-End Test**:
  - Run the `apple-intelligence-js-sdk` against the real server to verify SSE chunk formatting matches OpenAI's spec exactly in a real-world scenario.
