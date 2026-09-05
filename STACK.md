# MaiPai tech stack standard

New work uses this stack. Deviating is allowed only with a written
justification in that repo's dev docs.

## Backend (MaiPai Home)

| Layer | Standard |
|---|---|
| Runtime | Bun |
| HTTP framework | Hono, routes defined with Zod schemas via `@hono/zod-openapi` |
| Validation | Zod (the same schemas that generate the OpenAPI spec) |
| Database | SQLite via Drizzle ORM |
| API docs | Generated OpenAPI spec + interactive explorer at `/api/docs` |

## Frontend (MaiPai Home web)

| Layer | Standard |
|---|---|
| Framework | React + Vite (TypeScript) |
| Styling/components | The shared component catalog in `home`'s agents.md; build from it before building new |

## Desktop (MaiPai Desktop)

Electron + electron-builder, unsigned phase-1 builds (ad-hoc signed on arm64).

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
| Engine | llama-server (llama.cpp), the only model engine on hub and robot. Ollama is not part of the fresh hub |
| Wire contract | OpenAI-compatible HTTP for text and embeddings (`spec/llm/`); ComfyUI's API for image and video; the voice sidecar contract (`spec/voice/`) for speech |
| Roles in code | `chat`, `router`, `embed`, `vision`, `image`, `video`, `coding`, `tts`, `stt`, `wakeword`, never a model name |

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
