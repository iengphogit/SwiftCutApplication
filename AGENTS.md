# Repository Guidelines

## Project Structure & Module Organization
The shared Kotlin Multiplatform code lives in `composeApp/src`, split by target (`commonMain`, `androidMain`, `iosMain`, `jsMain`, `jvmMain`, `wasmJsMain`). Android packaging, Gradle scripts, and Compose configuration are in `composeApp/build.gradle.kts`. Platform bootstraps stay outside the shared module: Android assets/manifests are generated from `composeApp`, while Swift entry points live in `iosApp/iosApp`. This project shares business logic only; implement UI with native platform layers rather than shared Compose UI. iOS local data persists under `Application Support/SwiftCut`.

## Build, Test, and Development Commands
Run all tasks from the repo root using the Gradle wrapper:
- `./gradlew :composeApp:assembleDebug` — build the Android debug APK.
- `./gradlew :composeApp:run` — launch the desktop JVM app.
- `./gradlew :composeApp:wasmJsBrowserDevelopmentRun` — serve the Wasm web build.
- `./gradlew test` — execute unit tests across configured targets.
On Windows use `gradlew.bat`.

## Coding Style & Naming Conventions
Follow Kotlin official style: four-space indentation, 100-character soft limit, trailing commas allowed. Use UpperCamelCase for types, lowerCamelCase for members, and SCREAMING_SNAKE_CASE only for compile-time constants. Prefer `val` over `var`, expose platform bridges via expect/actual pairs, and colocate Composables near previews.

## Testing Guidelines
Shared tests belong in `composeApp/src/commonTest`; platform-specific tests live beside their `*Main` source set. Use `kotlin.test` assertions, name files `{Feature}Test.kt`, and use backticked method names when clarity helps. Focus coverage on view-model logic and expect/actual boundaries.

## Commit & Pull Request Guidelines
This repo ships without history, so align new commits to Conventional Commits (e.g., `feat: add scene editor`). Keep body text present tense, reference issue IDs, and add `BREAKING CHANGE:` footers when needed. Pull requests should describe user-facing impact, list executed test commands, and include platform screenshots for UI changes spanning Android, desktop, or web.

## Environment & Tooling Notes
The project targets Kotlin 2.2.20 with Compose Multiplatform 1.9.1; keep dependency bumps in `gradle/libs.versions.toml` and use the Gradle wrapper. Hot reload is enabled via `org.jetbrains.compose.hot-reload`; disable it explicitly in experimental branches only. Prefer editing configuration through `gradle.properties` instead of generated `.idea` files. All project flows are driven by `workspace.json`; update it for workflow changes. iOS media imports persist in `Application Support/SwiftCut/MediaLibrary.json` with files in `Application Support/SwiftCut/MediaLibraryFiles`, and project workspaces live under `Application Support/SwiftCut/Projects/Project 001`.
