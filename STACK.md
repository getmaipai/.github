# MaiPai tech stack standard

New work uses this stack. Deviating is allowed only with a written
justification in that repo's dev docs.

## Backend (MaiPai Home)

| Layer | Standard |
|---|---|
| Runtime | Bun |
| Shared helpers | `@maipai/core` from `getmaipai/commons` (log, paths, secrets and keystore, throttles, the hardware probe), and `@maipai/spec` for every record and wire shape; pinned by tag, never copied |
| HTTP framework | Hono, routes defined with Zod schemas via `@hono/zod-openapi` |
| Validation | Zod (the same schemas that generate the OpenAPI spec) |
| Database | SQLite via Drizzle ORM |
| API docs | Generated OpenAPI spec + interactive explorer at `/api/docs` |

## Frontend (MaiPai Home web)

| Layer | Standard |
|---|---|
| Framework | React + Vite (TypeScript) |
| Styling/components | `@maipai/ui` from `getmaipai/commons` (the kit: tokens, primitives, blocks, the shell, the settings renderer, its ESLint config), pinned by tag; build from it before building new |

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

Bun runs the shared household core on the robot: the one TypeScript
pipeline (the XState turn machine, memory, safety, the package host) as
the hub's own runtime package (bot RUNTIME-01, the 2026-09-14 bot design
pass). Python, managed with uv, linted with Ruff, tested with pytest,
runs the hardware and speech services (the body, the voice sidecar). The
pipeline is never ported to Python; the robot differs from the hub only
by its model's budget record and its deployment limits.

## Before the Studio

Four things are settled before the Studio becomes the hub, each a home
backlog row: enforceable offline operation (preloaded artifacts, no
runtime download or telemetry, cached-only frozen dependencies, a
process-level network restriction, and an egress-denied startup and
turn test, OFFLINE-TEST-01); the pinned execution configuration above
with the adapter checks (ENGINE-CONTRACT-01); runtime and schema
ownership resolved (the `commons/spec` interpreters, no stale
`home/spec/` reference anywhere); and one realistic acceptance workload,
two simultaneous conversations with speech, measuring first useful
answer, peak memory and cancellation, which sets the concurrency and
residency limits (STUDIO-ACCEPT-01).

## Docs sites

Astro Starlight, living inside each product repo under `docs/`, published via
GitHub Pages. Three content tiers (`user/`, `dev/`, `api/`) per
[docs/STYLE.md](docs/STYLE.md).

## Packages (`catalog`, and Tier 1 plugins on `home`/`bot`)

| Layer | Standard |
|---|---|
| Runtime | Deno, deny-by-default sandbox; one execution boundary with deployment-controlled warm limits and idle eviction first; Workers only after measurement, and if adopted with explicit per-Worker permissions and a documented stdio bridge |
| RPC | MCP over the official stdio transports (TypeScript SDK on the hub, Python SDK on the robot); `vscode-jsonrpc`/`pygls` as the fallback |
| Storage | `node:sqlite` inside the package's own permitted directory, no FFI |
| Declarative tier (Tier 0) | Recipes (`fetch`, `pick`, `format`, `action`, `remember`, `schedule`), interpreted natively by the TypeScript and Python interpreters in `commons/spec/` (the `spec` workspace, pinned by tag; `home/spec/` no longer exists) |

## Models and the engine

| Layer | Standard |
|---|---|
| Owner | MaiPai Stack (`getmaipai/stack`, design stage 2026-09-17): the one service that installs, supervises, budgets and serves every engine and model, on the hub and the robot. Until Home runs on it, the hub's own supervisors stand in with the same rules |
| Engine | llama-server (llama.cpp) is the baseline everywhere and the only generative-text engine on the robot (speech runs through sherpa-onnx, below). On Apple silicon the Stack measures `mlx-serve` and `oMLX` beside it (the hub's `docs/plans/hub-on-apple-silicon-2026-09-17.md`); ComfyUI is a managed sidecar for image edits and video. Ollama and LM Studio are never product dependencies (a person may point the Stack at one they installed) |
| Wire contract | OpenAI-compatible HTTP for text, embeddings, transcription, speech and images, addressed by role; the Stack's job API for image, video and music; the voice sidecar contract (`spec/voice/`) for the robot's body and the hub's in-process speech |
| Roles in code | `chat`, `coding`, `judge`, `router`, `embed`, `rerank`, `vision`, `stt`, `tts`, `wakeword`, `image`, `video`, `music`, never a model name; generator roles take `quality: fast, everyday, best` |
| Engine contract | "OpenAI-compatible" guarantees none of what the turn needs, so the role adapter provides and tests, per pinned build: `tool_choice` `required` and `auto` honoured, reasoning separated from content, thinking limits per request, cancellation that reaches the engine, and per-call timing fields; llama.cpp's tool behaviour is template-dependent and is proven, not assumed (home ENGINE-CONTRACT-01) |
| Classifier runtime | A learned decider (the lookup head, the router) runs in a supported encoder runtime (ONNX) behind the `router` role, never as an unmanaged process inside a turn node |
| Pinned execution configuration | The complete set is pinned together and a measurement is valid only against its set: the Bun version, the engine build, the model digest, the quantization, the chat template, the thinking settings, the tool set |

## Shell and kit (hub, robot, Go)

| Layer | Standard |
|---|---|
| Kit | `@maipai/ui`: shadcn/ui on Base UI and Tailwind v4, with the application shell and every non-chat page vendored from shadcndashboard as shipped (MIT, `commons/ui/src/dashboard/`) and restyled by tokens only |
| Chat | assistant-ui's Elements, all of them vendored as shipped (`commons/ui/src/elements/`) on the assistant-ui runtime; a capability is wired to its Element (reasoning, tool, artifact, image generation, and the rest), never to a hand-built part |
| Icons | lucide, referenced by name, no other set |
| Web-only escape hatch | Optional: Module Federation 2.0, so a custom React page shares the React and `@maipai/ui` singletons with the shell; never required for a package |
| iPhone/Apple TV rendering | SwiftUI rendering the shared semantic records (messages, sources, attachments, actions, confirmations, progress) with shipped native controls; the no-hand-built-UI rule's native scope is exactly that: shipped SwiftUI controls, never custom-drawn ones. Disclosure and every policy decision are enforced on the server; a client renders what it is sent |

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
