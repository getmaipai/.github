# MaiPai tech stack standard

New work uses this stack. Deviating is allowed only with a written
justification in that repo's dev docs.

## Backend (MaiPai Home)

| Layer | Standard |
|---|---|
| Runtime | Bun |
| Shared helpers | `@maipai/core` from `getmaipai/shared` (log, paths, secrets and keystore, throttles, the hardware probe), and `@maipai/spec` for every record and wire shape; pinned by tag, never copied |
| HTTP framework | Hono, routes defined with Zod schemas via `@hono/zod-openapi` |
| Validation | Zod (the same schemas that generate the OpenAPI spec) |
| Database | SQLite via Drizzle ORM |
| API docs | Generated OpenAPI spec + interactive explorer at `/api/docs` |

## Frontend (MaiPai Home web)

| Layer | Standard |
|---|---|
| Framework | React + Vite (TypeScript) |
| Styling/components | `@maipai/ui` from `getmaipai/shared` (the kit: tokens, primitives, blocks, the shell, the settings renderer, its ESLint config), pinned by tag; build from it before building new |

## Desktop (MaiPai Desktop)

Electron + electron-builder, unsigned phase-1 builds (ad-hoc signed on arm64).

## Status app: none

MaiPai Stack has no tray or menu-bar item and no interface of any kind (refocused 2026-09-20, `docs/DECISIONS.md`);
the engines' state, updates and repairs appear on Home's own Engines
page. Home's native notifications go through the notification
system in `docs/NOTIFICATIONS.md`.

## TV / Phone (MaiPai Go)

SwiftUI (tvOS + iOS), project generated with xcodegen, built locally with
`scripts/build_local.sh` style tooling, sideloaded via atvloadly. Never built
on GitHub Actions (macOS minutes bill 10x).

## Robot (MaiPai Bot)

Python managed with uv; lint and format with Ruff; tests with pytest.

## Docs sites

Astro Starlight, living inside each product repo under `docs/`, published via
GitHub Pages. Three content tiers (`user/`, `dev/`, `api/`) per
[docs/STYLE.md](docs/STYLE.md).

## Packages (`catalog`, and Tier 1 plugins on `home`/`bot`)

| Layer | Standard |
|---|---|
| Runtime | Deno, deny-by-default sandbox, one warm process per package on the hub, Workers on the robot |
| RPC | MCP over the official stdio transports (TypeScript SDK on the hub, Python SDK on the robot); `vscode-jsonrpc`/`pygls` as the fallback |
| Storage | `node:sqlite` inside the package's own permitted directory, no FFI |
| Declarative tier (Tier 0) | Recipes (`fetch`, `pick`, `format`, `action`, `remember`, `schedule`), interpreted natively by the TypeScript and Python interpreters in `home/spec/` |

## Models and the engine

| Layer | Standard |
|---|---|
| Owner | MaiPai Stack (`getmaipai/stack`, design stage 2026-09-17): the one service that installs, supervises, budgets and serves every engine and model, on the hub and the robot. Until Home runs on it, the hub's own supervisors stand in with the same rules |
| Engine | llama-server (llama.cpp) is the baseline everywhere and the only engine on the robot. On Apple silicon the Stack measures `mlx-serve` and `oMLX` beside it (the hub's `docs/plans/hub-on-apple-silicon-2026-09-17.md`); ComfyUI is a managed sidecar for image edits and video. Ollama and LM Studio are never product dependencies (a person may point the Stack at one they installed) |
| Wire contract | OpenAI-compatible HTTP for text, embeddings, transcription, speech and images, addressed by role; the Stack's job API for image, video and music; the voice sidecar contract (`spec/voice/`) for the robot's body and the hub's in-process speech |
| Roles in code | `chat`, `coding`, `judge`, `router`, `embed`, `rerank`, `vision`, `stt`, `tts`, `wakeword`, `image`, `video`, `music`, never a model name; generator roles take `quality: fast, everyday, best` |

## Shell and kit (hub, robot, Go)

| Layer | Standard |
|---|---|
| Kit | `@maipai/ui`, a thin layer over shadcn/ui on Radix and Tailwind v4 |
| Icons | lucide, referenced by name, no other set |
| Web-only escape hatch | Module Federation 2.0, so a custom React page shares the React and `@maipai/ui` singletons with the shell |
| iPhone/Apple TV rendering | SwiftUI, rendering the same declared UI schema natively |

## Robot speech

| Layer | Standard |
|---|---|
| Speech stack | sherpa-onnx (wake word, STT, TTS all run through it); Moonshine for English STT, a Whisper or Zipformer model for other languages; Piper for non-English voices |

## Cross-cutting tooling

| Concern | Standard |
|---|---|
| Pre-commit gate | `scripts/check.sh` per repo: its own lint/format/tests, then the pinned `@maipai/standards` core (gitleaks, PII wordlist, prose lint, licence check) |
| Screenshots | Playwright against a seeded demo household (web); `xcrun simctl` (Go) |
| Secret scanning | gitleaks locally; GitHub secret scanning on public repos |
| Releases | Semver tags + GitHub Releases + Keep a Changelog, cut by the `release` skill |
| CI | None on push for private repos; cheap tag/docs workflows allowed on public repos |
