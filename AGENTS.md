# Repository Guidelines

## Project Structure & Module Organization
This repository is a Swift Package Manager (SPM) project with a core library and a separate CLI target. `Package.swift` defines the package and target configuration. Core source code lives under `Sources/OpenXCResultTool/`, while the CLI entry point is in `Sources/OpenXCResultToolCLI/`. Tests live in `Tests/OpenXCResultToolTests/`; keep new test files aligned with the feature area they cover.

## Build, Test, and Development Commands
- `swift build` compiles the executable target using the Swift toolchain declared in `Package.swift` (swift-tools-version 6.2).
- `swift run openxcresulttool` builds (if needed) and runs the CLI executable.
- `swift test` runs the XCTest suite in `Tests/OpenXCResultToolTests/`.
- `swift run openxcresulttool get object --legacy --path Tests/Fixtures/<bundle>.xcresult --id <objectId> --format json` prints a legacy object payload for debugging or reverse‑engineering.
- `make wasm-image` builds the SwiftWasm Docker image.
- `make wasm-build` builds the core library for WASI (`wasm32-unknown-wasi`); override with `WASM_TARGET` and `WASM_BUILD_ARGS`.

## Coding Style & Naming Conventions
Keep indentation at 4 spaces, matching the existing source file. Follow Swift API Design Guidelines: use UpperCamelCase for types (`OpenXCResultTool`), lowerCamelCase for functions and variables, and keep filenames aligned with their primary type. There is no formatter configured in the repo; if you introduce one, update this guide and the build instructions. Keep the entry point in a small `@main` type and move non-trivial logic into separate files for readability.

## Testing Guidelines
Use XCTest (SPM default) for unit tests and name files like `FeatureTests.swift` with methods named `testFeatureBehavior`. Prefer deterministic tests and keep I/O behind protocols so logic can be tested without external dependencies. Place tests in `Tests/OpenXCResultToolTests/` and run them via `swift test`.

## Commit & Pull Request Guidelines
Current history only includes a single `Init` commit, so no established convention exists yet. Use short, imperative commit subjects (for example, `Add CLI parsing`) and include scope when it clarifies the change. For pull requests, include a brief summary, the motivation, and the commands you ran (for example, `swift build`, `swift test`) so reviewers can reproduce your checks.

## Agent-Specific Instructions
When running repository commands, do not ask for permission before executing `git add` or `git commit`; proceed directly.
