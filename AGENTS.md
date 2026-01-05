# Repository Guidelines

## Project Structure & Module Organization
The shared Kotlin Multiplatform code lives in `composeApp/src`, split by target (for example `commonMain`, `androidMain`, `iosMain`, `jsMain`, `jvmMain`, `wasmJsMain`). Android packaging, Gradle scripts, and Compose configuration sit in `composeApp/build.gradle.kts`. Platform-specific bootstraps stay outside: Android assets and manifests are generated from the `composeApp` module, while Swift entry points live in `iosApp/iosApp`.

## Build, Test, and Development Commands
Use the Gradle wrapper for all tasks so everyone shares the same toolchain. Key commands:
- `./gradlew :composeApp:assembleDebug` — builds the Android debug APK.
- `./gradlew :composeApp:run` — launches the desktop JVM app.
- `./gradlew :composeApp:wasmJsBrowserDevelopmentRun` — serves the Wasm web build locally.
- `./gradlew test` — executes available unit tests across configured targets.
Run everything from the repo root; on Windows replace `./gradlew` with `gradlew.bat`.

## Coding Style & Naming Conventions
Follow Kotlin official style: four-space indentation, trailing commas allowed, 100-character soft limit. Use UpperCamelCase for classes and objects, lowerCamelCase for members, and SCREAMING_SNAKE_CASE only for compile-time constants. Prefer immutable `val` over `var`, expose platform bridges via expect/actual pairs, and colocate Composables near their preview functions.

## Testing Guidelines
Shared tests belong in `composeApp/src/commonTest`; platform-specific cases can live beside their `*Main` source set. Write tests with `kotlin.test` assertions, name files `{Feature}Test.kt`, and use backticked method names when clarity helps. Aim for coverage on view-model logic and expect/actual boundaries.

## Commit & Pull Request Guidelines
This repo ships without Git history in the archive, so align new commits to Conventional Commits (e.g., `feat: add scene editor`). Keep body text present-tense, reference issue IDs, and note breaking changes in a `BREAKING CHANGE:` footer. Pull requests should describe the user-facing impact, list test commands executed, and add platform screenshots when UI changes span Android, desktop, or web.

## Environment & Tooling Notes
The project targets Kotlin 2.2.20 with Compose Multiplatform 1.9.1; keep the Gradle wrapper and `gradle/libs.versions.toml` as the source of truth for dependency bumps. Hot reload is enabled via `org.jetbrains.compose.hot-reload`; disable it explicitly in experimental branches to avoid committing local-only configs. Prefer editing configuration through `gradle.properties` rather than modifying generated `.idea` files.
