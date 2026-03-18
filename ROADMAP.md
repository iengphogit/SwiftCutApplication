# SwiftCut Roadmap

## Progress Snapshot

Last updated: 2026-03-18

Use this section as the quick resume point before reading the detailed phases below.

### Overall Progress
- Timeline UI and interaction model: `78%`
- Preview/video engine path: `62%`
- Audio engine path: `60%`
- Waveform analysis path: `80%`
- Native timeline bridge parity: `66%`
- End-to-end editor happy flow: `78%`

### Done
- [x] Centered playhead timeline model restored
- [x] Ruler and clips aligned to the playhead line
- [x] Horizontal timeline scroll container fixed so content width is real
- [x] Debug layout toggle moved into top-header `...` menu
- [x] Single bottom tool strip now switches between default tools and clip-context tools
- [x] First-load main video no longer auto-creates a separate audio track
- [x] Real waveform analysis service created with `AVAssetReader`
- [x] Native audio transport extracted out of `SCNativePreviewView`
- [x] Swift-facing `NativeAudioEngine` and `NativeVideoEngine` added
- [x] Track model now supports `volume` and `solo`
- [x] Composition audio snapshots now carry effective track/clip volume state
- [x] Native timeline core/bridge now stores track `volume` / `solo` and clip `volume` / `muted`
- [x] Preview white-flash path reduced by stabilizing visual overlay signatures and native frame advancement
- [x] Timeline ownership rule documented: embedded waveform belongs to the video lane only until extraction, then moves to the extracted audio track
- [x] Post-extract rule documented: main video track stays visible and becomes filmstrip-only while the new audio lane owns waveform display
- [x] Extract flow now shows loading and toast feedback
- [x] Extract now exports a real `.m4a` audio file instead of keeping the video container path
- [x] First-load video clip shows embedded waveform before extraction
- [x] After extraction, the new audio lane appears below the main video lane
- [x] Video and extracted audio tracks now behave as fully independent tracks
- [x] Real capsule waveform bars now use decoded sample-data amplitude instead of placeholder shaping
- [x] Audio `Volume` sub-mode added with `Back | slider | percent`
- [x] Live clip volume now uses preview-only updates during drag and commits on release
- [x] Audio transport now updates live node volume without full rescheduling for level-only changes
- [x] Embedded video audio now participates in the same audio composition path before extraction
- [x] Clip selection behavior stabilized so media content and selection stroke do not intentionally rebuild together

### In Progress
- [ ] Native audio playback is still not verified audible on device
- [ ] Native editor bridge support for volume/solo/clip mute-volume needs compile/runtime verification
- [ ] Native snapshot rebuild path still needs broader device validation after the latest bridge changes
- [ ] Preview playback after zoom changes needs another real-device pass
- [ ] Extracted audio clip duration and playback smoothness still need device verification against the ruler
- [ ] Clip selection highlight still needs broad device verification against visual flashing regressions

### Next
- [ ] Verify audible playback on real device with an extracted audio track
- [ ] Log and inspect whether active audio clips are reaching `SCAudioTransportEngine`
- [ ] Add track volume/solo controls to UI once native bridge path is verified
- [ ] Add clip volume/mute controls to contextual tools
- [ ] Verify clip volume persists correctly after full reload and native snapshot rebuild
- [ ] Apply the same preview-only drag / commit-on-release pattern to speed, opacity, and fades
- [ ] Verify extracted audio clip timing/length matches the source video clip exactly after a fresh extract
- [ ] Reintroduce coordinated vertical scrolling for many tracks only after audio playback is stable

### Current Blockers
- [ ] No confirmed audible output yet from the new native audio path
- [ ] Full Xcode/device build verification cannot be completed in sandbox; device testing is required
- [ ] Native/Swift snapshot parity for new audio state needs confirmation after rebuild
- [ ] Extracted audio playback smoothness and exact clip timing still need confirmation on device

## Priority 1: Happy Flow Completion ASAP

### Goal
- Complete and verify the real editor happy flow end-to-end:
  - open seeded or imported project
  - see timeline clips and filmstrip/waveform content
  - play and pause preview successfully
  - move, trim, split, and delete linked video/audio pairs
  - confirm preview and timeline stay in sync after edits

### Current State
- Project open into the timeline editor is working
- Main-track filmstrip and waveform rendering are implemented
- Waveform visuals are rendered in the timeline UI, but the analysis pipeline still needs to move to real decoded sample buckets
- Separate extracted audio clips are implemented for video imports
- Linked move, trim, split, delete, and ripple delete are implemented
- The playback control is present in the editor UI
- Playback happy flow is automation-verified on simulator
- The preview viewport now clearly differs from the output canvas:
  - gray outer viewport
  - black inner preview canvas
  - visible border for the selected output frame
- Practical preview terms:
  - `viewer` for the outer preview area
  - `canvas` for the inner render surface
  - `export frame` for the visible output boundary
- Aspect ratio, resolution, and frame rate now drive live preview output settings
- Preview content defaults to fit inside the viewport without cropping
- The export frame stays centered and changes by fit geometry, not by padding/margin layout tricks
- Timeline horizontal scrub is smoother because drag updates no longer commit a native seek on every scroll tick
- The bottom tool strip now switches between a default tool set and clip-specific contextual tools
- The next contextual-tool happy-flow target is an audio `Volume` sub-mode with a focused slider UI

### Blockers To Clear First
- [x] Prove `Play -> Playing -> Pause -> Paused` works after opening a real project
- [x] Prove preview time advances while playback is running
- [ ] Prove moved clips still preview at the correct time and position with manual testing
- [ ] Prove trimmed clips still preview the correct in/out ranges with manual testing
- [ ] Prove split linked video/audio pairs still play in sync with manual testing
- [ ] Prove delete and ripple delete do not desync preview state with manual testing
- [x] Remove UI test ambiguity around the nested playback button accessibility tree
- [x] Add one stable playback smoke test that passes on simulator
- [ ] Run one manual simulator/device verification pass for the same flow
- [ ] Prove selected audio clip volume can be adjusted from a focused slider sub-mode without breaking playback smoothness
- [ ] Wire export bitrate to real encoder/output configuration
- [ ] Only after the above: mark the happy flow as signed off

### Exit Criteria
- One seeded project can be opened and played successfully
- Playback state changes are verified, not assumed
- Timeline edits update both the timeline and preview correctly
- Linked video/audio behavior remains correct after playback and edits
- A simulator smoke test passes consistently
- Manual verification matches automation results
- Preview viewport and export output settings follow the same aspect-ratio and resolution model

## ⚠️ CRITICAL: ZERO COPYRIGHT / LICENSING RISK

**This project MUST NOT use any third-party libraries, SDKs, or licensed components.**

| ❌ FORBIDDEN | ✅ ALLOWED |
|-------------|-----------|
| FFmpeg | AVFoundation |
| Commercial SDKs | CoreMedia |
| Open-source video libs | CoreVideo |
| Licensed codecs | CoreAudio |
| Third-party frameworks | Metal |
| Copyleft code (GPL) | AudioToolbox |
| External dependencies | QuartzCore |

**Why This Matters:**
- Legal liability for unlicensed codec usage
- Patent claims on video/audio compression
- GPL contamination of proprietary code
- Third-party SDK licensing fees
- Future acquisition due diligence

**Enforcement:**
- All code must be written from scratch
- No CocoaPods/SPM dependencies for media processing
- Only Apple-provided frameworks permitted
- Code review required for any new engine code

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftCut App                           │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (SwiftUI)                                         │
│  ├── StudioScreen                                           │
│  ├── TimelineView                                           │
│  └── ExportScreen                                           │
├─────────────────────────────────────────────────────────────┤
│  Engine Layer (100% Custom, Built from Scratch)             │
│  ├── VideoEngine        - Decoding, encoding, processing    │
│  ├── AudioEngine        - Mixing, effects, processing       │
│  ├── VideoPreviewEngine - Real-time rendering, playback     │
│  └── TimelineEngine     - Multi-track composition, sync     │
├─────────────────────────────────────────────────────────────┤
│  iOS Native APIs (Apple Provided, Free to Use)              │
│  ├── AVFoundation       - Asset reading/writing             │
│  ├── CoreMedia          - Sample buffers, time              │
│  ├── CoreVideo          - Frame buffers, pixel buffers      │
│  ├── CoreAudio          - Audio processing                  │
│  ├── Metal              - GPU rendering/effects             │
│  └── AudioToolbox       - Audio format conversion           │
└─────────────────────────────────────────────────────────────┘
```

**Risk Mitigation:**
- All engines owned 100% by this project
- No external code copying
- No license attribution required
- Safe for commercial distribution
- Safe for future acquisition/investment

---

## Phase 1: Foundation

### Current Status
- In progress
- Native iOS app builds, installs, and launches on a physical device
- A first-pass custom `TimelineEngine` exists inside `iosApp/iosApp/Engine/TimelineEngine`
- No separate `SwiftCutEngine` framework target yet
- No dedicated engine test target or CI dependency audit yet

### 1.1 Project Setup
- [ ] Create `SwiftCutEngine` framework target (separate from UI)
- [x] Define engine protocols/interfaces
- [ ] Set up unit test infrastructure for engines
- [ ] **Audit and remove ALL third-party dependencies**
- [ ] **Add dependency check to CI pipeline**

### 1.2 Codebase Cleanup
- [ ] Remove unused `coolcut` package and schedule code
- [ ] Consolidate to `space.iengpho.swiftcut`
- [ ] Remove Compose UI (iOS is fully native)
- [ ] **Verify no copied code from external sources**

---

## Phase 2: VideoEngine

### Current Status
- Not started
- No frame-level decoding, processing, or encoding engine exists yet
- Current video handling is composition-based through `AVMutableComposition`

**Purpose:** Handle all video decoding, processing, and encoding using AVFoundation only.

### ⚠️ Risk Warning
- DO NOT use FFmpeg or any video library
- DO NOT copy codec implementations from open-source
- DO NOT use GPL/LGPL licensed code
- ONLY use AVFoundation APIs provided by Apple

### 2.1 Video Decoding
- [ ] `VideoDecoder` class using `AVAssetReader`
- [ ] Extract `CMSampleBuffer` frames from video file
- [ ] Support multiple codecs (H.264, H.265, ProRes) via AVFoundation
- [ ] Handle different resolutions and frame rates

### 2.2 Video Frame Processing
- [ ] `VideoFrameProcessor` for frame manipulation
- [ ] Convert `CMSampleBuffer` to `CVPixelBuffer`
- [ ] Apply transforms (crop, scale, rotate)
- [ ] Frame-by-frame access for editing

### 2.3 Video Encoding
- [ ] `VideoEncoder` class using `AVAssetWriter`
- [ ] Encode `CVPixelBuffer` to H.264/H.265 via AVFoundation
- [ ] Configurable bitrate, resolution, frame rate
- [ ] Support keyframe interval settings

### 2.4 VideoEngine API
```swift
protocol VideoEngineProtocol {
    func loadVideo(url: URL) async throws -> VideoAsset
    func decodeFrame(at time: CMTime) -> CVPixelBuffer?
    func encodeFrames(_ frames: [CVPixelBuffer], config: EncodeConfig) async throws -> URL
    func extractFrames(range: CMTimeRange) async -> [CVPixelBuffer]
}
```

---

## Phase 3: AudioEngine

### Current Status
- Not started
- Audio clip and effect models exist, but no decoding, mixing, DSP, or encoding engine exists yet

**Purpose:** Handle audio decoding, mixing, effects, and encoding using CoreAudio/AVFoundation only.

### Direction
- Build a fully owned native `AudioEngine` instead of relying on UI-level playback hacks
- Keep waveform analysis as a separate native service, not as part of the live playback transport
- Share source media access patterns with the video/timeline engine, but keep playback, analysis, and rendering responsibilities separated
- Use the engine layer to unlock future features such as split, gain, fade, mute, solo, extraction, trim, speed, and effect processing

### ⚠️ Risk Warning
- DO NOT use third-party audio libraries
- DO NOT use GPL audio code (e.g., SoundTouch)
- ONLY use CoreAudio and AVFoundation APIs

### 3.1 Audio Decoding
- [ ] `AudioDecoder` using `AVAssetReader` for audio tracks
- [ ] Extract `CMSampleBuffer` audio samples
- [ ] Support common formats (AAC, PCM) via AVFoundation
- [ ] Convert to PCM for processing
- [ ] Handle embedded audio inside video containers through the same asset-reader path

### 3.2 Audio Processing (Custom Implementation)
- [ ] `AudioMixer` for multi-track mixing (own code)
- [ ] Volume control per track
- [ ] Fade in/out processing
- [ ] Audio ducking implementation
- [ ] Real-time audio buffer manipulation
- [ ] Native playback transport for play, pause, seek, scrub, and timeline sync
- [ ] Split-aware clip scheduling for timeline audio segments
- [ ] Correct playback updates after trim, move, delete, and ripple edits

### 3.3 Waveform Analysis Service
- [ ] `WaveformAnalysisService` owned by the engine layer
- [ ] Decode real audio sample buffers and generate waveform buckets from source media bytes
- [ ] Support waveform bucket generation from audio files and video files with embedded audio
- [ ] Cache waveform data by asset id, source path, zoom level, or target bar count
- [ ] Expose normalized peak/RMS style values for timeline rendering
- [ ] Keep waveform generation off the live playback engine path

### 3.4 Audio Effects (Custom, No External DSP Libraries)
- [ ] `AudioEffectProcessor` base class (own implementation)
- [ ] Equalizer (EQ) - write DSP code from scratch
- [ ] Reverb - write using AudioUnit provided by Apple
- [ ] Noise reduction - custom algorithm
- [ ] Speed/pitch change (time stretching) - custom implementation

### 3.5 Timeline Edit Convenience Operations
- [ ] Add compatible clip swap support after split/trim/move/delete behavior is stable
- [ ] Ensure swap keeps linked media relationships and valid source/timeline ranges
### 3.6 Audio Encoding
- [ ] `AudioEncoder` using `AVAssetWriter`
- [ ] Encode to AAC/PCM via AVFoundation
- [ ] Sync audio with video timestamps

### 3.7 AudioEngine API
```swift
protocol AudioEngineProtocol {
    func loadAudio(url: URL) async throws -> AudioAsset
    func mixTracks(_ tracks: [AudioTrack]) async throws -> AudioAsset
    func applyEffect(_ effect: AudioEffect, to track: AudioTrack) async -> AudioTrack
    func encode(_ asset: AudioAsset, config: AudioEncodeConfig) async throws -> URL
}
```

---

## Phase 4: VideoPreviewEngine

### Current Status
- In progress
- `AVPlayer` preview has been replaced by a native `SCNativePreviewView`
- SwiftUI preview now feeds `CompositionFrame.visualClips` and `CompositionFrame.audioClips` into the native preview host
- Playback control is routed through `PlaybackEngine` via `NativeEditorEngine`
- Preview now respects fit-within-viewport behavior for composed content
- Preview viewport/output-canvas separation is visible in the editor UI
- No Metal renderer or `MTKView` exists yet

**Purpose:** Real-time video preview and playback using Metal for GPU rendering.

### ⚠️ Risk Warning
- DO NOT use third-party rendering engines
- DO NOT copy Metal shader code from tutorials with restrictive licenses
- Write all shaders from scratch

### 4.1 Preview Rendering
- [ ] `MetalRenderer` class using Metal framework
- [ ] Write custom Metal shaders (own code)
- [x] Render preview content inside a native preview surface
- [x] Support layered visual preview from composition output
- [x] Handle aspect ratio transformations
- [x] Keep output canvas distinct from preview viewport
- [x] Default composite video content to fit inside the viewport without cropping

### 4.2 Playback Controller
- [x] `PlaybackController` for play/pause/seek
- [x] Frame-accurate scrubbing
- [x] Lightweight timeline scrub preview with deferred native seek commit
- [ ] Playback rate control (0.25x - 4x)
- [ ] Loop playback

### 4.3 Real-time Effects Preview
- [ ] Apply color adjustments in real-time (custom shaders)
- [ ] Preview filters using Metal shaders (own code)
- [ ] Transform preview (crop, scale, rotate)

### 4.4 VideoPreviewEngine API
```swift
protocol VideoPreviewEngineProtocol {
    var currentTime: CMTime { get }
    var isPlaying: Bool { get }
    
    func setPreviewView(_ view: MTKView)
    func loadTimeline(_ timeline: Timeline)
    func play()
    func pause()
    func seek(to time: CMTime)
    func setPlaybackRate(_ rate: Float)
}
```

---

## Phase 5: TimelineEngine

### Current Status
- In progress
- This is the most advanced engine area in the codebase
- Data model, edit operations, composition building, import, preview wiring, and export plumbing all exist in early form
- The current implementation lives in `iosApp/iosApp/Engine/TimelineEngine`
- Early undo/redo and ripple delete are now wired into the iOS editor UI and engine
- Project output settings now affect both preview and export render size/frame rate

**Purpose:** Manage multi-track timeline composition using AVMutableComposition.

### ⚠️ Risk Warning
- Build timeline logic from scratch
- Do not copy timeline implementations from other projects

### 5.1 Timeline Data Model
- [x] `Timeline` struct with tracks and clips (own model)
- [x] `Track` class (video, audio, text, effects)
- [x] `Clip` struct with time range and source
- [x] Support clip overlap resolution on insert/move/trim
- [ ] Support transitions

### 5.2 Composition Builder
- [x] `CompositionBuilder` using `AVMutableComposition`
- [x] Add/remove/move clips
- [x] Handle multi-track composition
- [x] Sync video and audio tracks
- [x] `CompositionEngine` evaluates active visual and audio clips at time `t`
- [x] SwiftUI preview wiring consumes composition output
- [x] Preview bridge honors `fit/fill/stretch` scale mode

### 5.3 Edit Operations
- [x] `TimelineEditor` for edit commands
- [x] Split clip at time
- [x] Trim clip (in/out points)
- [x] Delete clip with ripple option
- [x] Undo/redo in early snapshot-based form
- [x] Track mute/lock/remove operations

### 5.4 Time Management
- [x] Basic time formatting for editor display
- [x] Frame-to-time conversion via project/frame-rate-backed playback configuration
- [x] Scroll scrub path updates local preview continuously and commits native seek on scroll end
- [ ] Snap to frame/grid
- [ ] Marker support

### 5.5 TimelineEngine API
```swift
protocol TimelineEngineProtocol {
    var duration: CMTime { get }
    var tracks: [Track] { get }
    
    func addClip(_ clip: Clip, to track: Track, at time: CMTime)
    func removeClip(_ clip: Clip)
    func splitClip(at time: CMTime)
    func moveClip(_ clip: Clip, to time: CMTime)
    func buildComposition() -> AVMutableComposition
}
```

### Implemented Now
- `Timeline`, `Track`, `VideoClip`, `AudioClip`, `TextClip`, and `OverlayClip`
- `TimelineEngineProtocol` and `TimelineEngine`
- Clip add/remove/move/trim/split operations
- Ripple delete and snapshot-based undo/redo
- Track add/remove/mute/lock operations
- Native C++ timeline core plus Objective-C++ bridge
- `NativeTimelineEngine`, `NativeEditorEngine`, and `PlaybackEngine`
- Composition building through `AVMutableComposition`
- `CompositionEngine` with active visual/audio evaluation
- Native preview host consuming visual/audio clip snapshots
- Basic media import, text overlay insertion, preview generation, and export flow
- Live project output settings for aspect ratio, resolution, and frame rate
- Output-frame viewport treatment in the editor preview
- Physical-device build/install/launch confirmed
- `XCUITest` smoke test for opening `Project 003` into the editor
- `XCUITest` playback smoke test for opening and toggling playback on `Project 003`

### Next Recommended Work
1. Finish Phase 5 before starting VideoEngine or AudioEngine.
2. Run manual verification for post-edit playback correctness after move/trim/split/delete.
3. Wire export bitrate to a writer-based export pipeline instead of only persisting the UI value.
4. Add timeline tests for split/trim/move/build composition behavior.
5. Reduce Swift-to-native timeline resync dependency so native timeline becomes the sole editing source of truth.
6. Replace the current snapshot-based undo/redo with a more complete command/`UndoManager` approach if needed.
7. Add snapping and markers.
8. Decide whether preview should evolve from the current native view into a dedicated Metal renderer.

---

## Phase 6: Export Engine

**Purpose:** Final video export combining all engines.

### ⚠️ Risk Warning
- Only use AVAssetExportSession
- No custom codec implementations
- No FFmpeg integration

### 6.1 Export Pipeline
- [ ] `ExportEngine` orchestrating all engines
- [ ] Build final `AVMutableComposition`
- [ ] Apply all edits and effects
- [ ] Export using `AVAssetExportSession`

### 6.2 Export Presets
- [x] Resolution: 720p, 1080p, 2K, 4K model exists in project settings
- [x] Frame rate: 24, 30, 60 fps model exists in project settings
- [ ] Bitrate: configurable (5-100 Mbps) in actual export encoding
- [ ] Codec: H.264, H.265 (via AVFoundation presets)

### 6.3 Export Progress
- [ ] Progress callback/Combine publisher
- [ ] Cancel export
- [ ] Export to photo library
- [ ] Share sheet integration

### 6.4 ExportEngine API
```swift
protocol ExportEngineProtocol {
    var progress: AnyPublisher<Float, Never> { get }
    
    func export(timeline: Timeline, config: ExportConfig) async throws -> URL
    func cancelExport()
}
```

---

## Phase 7: UI Layer

### 7.1 Timeline UI
- [x] Native timeline editor UI in SwiftUI
- [x] Draggable clips
- [x] Zoom/scroll timeline
- [x] Playhead indicator
- [x] Track lanes visualization

### 7.2 Preview UI
- [ ] `PreviewView` with `MTKView`
- [x] Playback controls overlay
- [x] Aspect ratio handling
- [x] Output-frame viewport visualization

### 7.3 Editor UI
- [x] Trim handles on clips
- [ ] Tool panels (speed, volume, crop)
- [x] Basic editor toolbar/actions
- [ ] Inspector panels

---

## Phase 8: Advanced Features

### ⚠️ Risk Warning for Advanced Features
- Text rendering: Use CoreText only
- Image processing: Use CoreImage/Vision
- Do NOT use third-party AI/ML libraries

### 8.1 Text Overlays
- [ ] `TextRenderer` using CoreText
- [ ] Render text to `CVPixelBuffer`
- [ ] Animated text using CADisplayLink

### 8.2 Image Support
- [ ] Static image import
- [ ] Image-to-video conversion
- [ ] Ken Burns effect (custom animation)

### 8.3 Speed Effects
- [ ] Variable speed (time remapping)
- [ ] Reverse playback
- [ ] Frame interpolation for slow-mo (use AVFoundation)

### 8.4 Color Grading
- [ ] Custom color adjustments via Metal shaders
- [ ] Real-time color preview
- [ ] LUT support (custom parser, no external libs)

---

## Phase 9: Quality & Performance

### 9.1 Optimization
- [x] Background processing with GCD for project/media loading and preview asset work
- [ ] Memory management for large files
- [ ] Caching decoded frames
- [ ] GPU-accelerated processing

### 9.2 Error Handling
- [ ] Comprehensive error types
- [ ] Recovery from failed operations
- [ ] User-friendly error messages

### 9.3 Testing
- [ ] Unit tests for each engine
- [x] Integration smoke test coverage started
- [ ] Performance benchmarks

---

## iOS APIs Used (Zero Third-Party)

| Engine | iOS Framework | Purpose | License Risk |
|--------|---------------|---------|--------------|
| VideoEngine | AVFoundation | AssetReader/Writer | ✅ None |
| VideoEngine | CoreMedia | CMSampleBuffer, CMTime | ✅ None |
| VideoEngine | CoreVideo | CVPixelBuffer | ✅ None |
| AudioEngine | AVFoundation | Audio track reading | ✅ None |
| AudioEngine | CoreAudio | AudioBuffer | ✅ None |
| AudioEngine | AudioToolbox | Format conversion | ✅ None |
| VideoPreviewEngine | Metal | GPU rendering | ✅ None |
| VideoPreviewEngine | QuartzCore | Display sync | ✅ None |
| TimelineEngine | AVFoundation | AVMutableComposition | ✅ None |
| ExportEngine | AVFoundation | AVAssetExportSession | ✅ None |

**All frameworks are provided by Apple with the iOS SDK. No additional licensing required.**

---

## Implementation Priority

| Phase | Engine | Priority | Risk Level |
|-------|--------|----------|------------|
| 2 | VideoEngine | P0 | Low (AVFoundation only) |
| 5 | TimelineEngine | P0 | Low (AVFoundation only) |
| 6 | ExportEngine | P0 | Low (AVFoundation only) |
| 4 | VideoPreviewEngine | P0 | Low (Metal only) |
| 3 | AudioEngine | P1 | Low (CoreAudio only) |
| 7 | UI Layer | P1 | None |
| 8 | Advanced Features | P2 | Low (Apple APIs only) |
| 9 | Optimization | P2 | None |

---

## Legal Compliance Checklist

Before each release, verify:

- [x] No third-party frameworks in Podfile/SPM
- [ ] No FFmpeg or similar libraries
- [ ] No GPL/LGPL code
- [ ] No copied code from StackOverflow without verification
- [ ] All engine code written by project contributors
- [ ] Code review completed for all new engines
- [ ] License header on all source files (MIT or proprietary)

---

## Key Principles

1. **100% iOS Native** - Only Apple frameworks, zero external dependencies
2. **Built from Scratch** - All engines custom-designed and owned
3. **Zero Copyright Risk** - No licensed components, no legal exposure
4. **Protocol-Driven** - Engines defined by protocols for testability
5. **Separation of Concerns** - Each engine has single responsibility
6. **Future-Proof** - Safe for commercial use, acquisition, and investment

---

*Last updated: March 2026*
