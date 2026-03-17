# Native Engine Concept

This document captures the native video-editor engine model adapted from the
reference project at `/Users/iengpho/PycharmProjects/NativeVideoEngine`.

## Core Rule

Use one master timeline clock.

Do not build the editor around one independent media player per track or per
clip.

At any time `t`:

1. `PlaybackEngine` produces the current timeline time.
2. `TimelineEngine` resolves active clips at that time.
3. `CompositionEngine` resolves those active clips into one visual result.
4. `AudioEngine` resolves those active audio clips into one mixed audio result.
5. `PreviewEngine` displays the composed result in the preview viewport.

## Engine Split

### TimelineEngine

Owns the editing model.

Responsibilities:

- timeline
- tracks
- clips
- trim
- split
- move
- ripple
- locking
- mute and visibility state
- selection-safe serializable edit data

Question answered:

- what should exist at time `t`

Rules:

- no UIKit or SwiftUI rendering logic
- no preview-layer ownership
- no direct playback UI behavior

### CompositionEngine

Owns evaluation of the timeline into one frame plan.

Responsibilities:

- resolve active clips from visible tracks
- sort active visual layers by stacking order
- map timeline time to source time
- apply transform and visual properties
- produce one composed visual result

Visual properties:

- crop
- position
- scale
- rotation
- opacity
- fit, fill, or stretch

Question answered:

- how do the active items become one output result

Rules:

- composition is not the edit-command layer
- composition is not the playback-clock layer
- composition should be reusable for preview and export

### PreviewEngine

Owns runtime playback presentation.

Responsibilities:

- play
- pause
- stop
- seek
- frame stepping
- loop behavior
- present current composed output in the preview viewport

Question answered:

- how is the composed result displayed during playback

Rules:

- preview is a native rendering surface
- preview should not own editing rules
- preview viewport and output canvas are different rectangles

### AudioEngine

Owns mixed timeline audio output.

Responsibilities:

- resolve active audio clips
- map timeline time to source samples
- apply clip gain and mute rules
- mix to output buffer

## Time Model

Project FPS is the master edit domain.

Use project FPS for:

- frame stepping
- playhead snapping
- timeline ruler behavior
- timecode display
- preview requests
- export defaults

Source FPS belongs to the asset and should not replace the project clock.

## Canvas Model

### Output Canvas

One project output frame size, for example:

- `1080x1920`
- `1920x1080`
- `1080x1080`

This is the actual edited frame.

### Preview Viewport

The UI rectangle that displays the output canvas.

Rules:

- preserve output aspect ratio
- letterbox or pillarbox when needed
- do not confuse viewport size with project output size

## Timeline Surface Model

The timeline surface uses one fixed playhead and one shared time scale.

Required UI structure:

- fixed `left channel` for track controls
- scrollable `right lane` for ruler and clips
- one centered `playhead`
- one shared `pointsPerSecond` scale for ruler and clip drawing

Required behavior:

- the left channel must not scroll horizontally
- the right lane must scroll under the fixed playhead
- timeline `0:00` must align through a computed leading inset, not by ad hoc offsets
- clip width must be derived from duration and zoom scale
- ruler ticks must use the same time scale as clip drawing
- pinch zoom should preserve the touched timeline point under the finger
- button zoom should preserve the playhead time

This matters because timeline layout is not cosmetic. It is part of the time
model. If the left channel, playhead, ruler, or clip drawing use different
coordinate assumptions, the editor becomes visually incorrect even when the
engine state is right.

## iOS Direction

For SwiftCut on iOS, native means:

- native preview surface
- one timeline clock
- one composition result
- one preview viewport

Not:

- one `AVPlayer` per track
- one preview widget per clip
- edit logic mixed into preview view code

## Bridge Boundary

UI should use a high-level engine API, not talk directly to C++ internals.

Recommended stack:

- SwiftUI or UIKit UI
- Swift facade
- Objective-C++ bridge
- C++ engine core

The app-facing facade should expose actions such as:

- play
- pause
- seek
- add clip
- split clip
- move clip
- trim clip
- timeline snapshot
- preview snapshot

This keeps UI code out of engine internals and makes the native engine
replaceable without rewriting the interface layer.

## Responsiveness Rules

These rules apply across the iOS app:

- do not block the UI thread for project loading, media probing, thumbnail generation, waveform generation, or timeline rebuild preparation
- run file I/O, asset probing, thumbnail generation, and waveform generation in background work
- only publish final UI state changes on the main thread
- when opening a project, show a loading state immediately instead of leaving the UI visually stuck
- when background work finishes, sync the minimum required state back to the UI

These are not optional style choices. They are baseline behavior requirements
for this project.

## Size Rule

Keep files and types maintainable:

- avoid more than `1000` lines in one view, class, or coordinator file
- split large UI surfaces into focused files for screen layout, controls, and media visualization
- if a screen starts collecting unrelated helper structs, move them out before continuing feature work

## Recommended Module Layout

Suggested local grouping:

- `iosApp/iosApp/Engine/TimelineEngine`
- `iosApp/iosApp/Engine/CompositionEngine`
- `iosApp/iosApp/Engine/PlaybackEngine`
- `iosApp/iosApp/Engine/PreviewEngine`
- `iosApp/iosApp/Engine/AudioEngine`
- `iosApp/iosApp/UI/Timeline`
- `iosApp/iosApp/UI/Preview`

## Immediate Architecture Goal

Refactor the current iOS engine toward:

1. pure timeline edit model
2. separate composition layer
3. native preview surface consuming composition output
4. later export reuse of the same composition evaluation

## Current Status

Implemented in the current codebase:

- native preview hosts using `AVPlayerLayer`
- C++ preview state bridge
- C++ timeline core with timeline, tracks, and clips
- Objective-C++ timeline bridge
- Swift `NativeEditorEngine` facade over native timeline and playback
- timeline editor is now the active project-editing screen
- native-first timeline UI state for:
  - timeline snapshots
  - visible duration
  - undo and redo availability
  - clip thumbnails and audio waveform bars
- active editor UI includes:
  - centered playhead
  - top project title
  - glass aspect-ratio popup
  - glass resolution/frame-rate/bitrate popup
  - preview-footer undo and redo
  - finger-anchored pinch zoom on the timeline
  - playhead-stable button zoom
  - adaptive ruler tick density based on zoom
  - centered overlay play or pause icon on the preview

Native-first edit paths already in use:

- import and add clip
- add text/debug clip
- split
- delete
- ripple delete
- move
- trim
- mute, lock, and remove track
- undo and redo

Still transitional:

- Swift timeline still exists as a compatibility model for preview and export
- `refreshDisplay()` still incrementally syncs Swift timeline data into native as a safety path
- preview and export still rebuild from the Swift compatibility timeline
- preview playback still uses `AVPlayer` as the backend
- C++ timeline core with timeline, tracks, and clips
- Objective-C++ timeline bridge
- Swift `NativeEditorEngine` facade over native timeline and playback
- timeline editor is now the active project-editing screen
- centered-playhead timeline editor UI
- native-first timeline UI state for:
  - timeline snapshots
  - visible duration
  - undo and redo availability
  - clip thumbnails and audio waveform bars

Native-first edit paths already in use:

- import and add clip
- add text/debug clip
- split
- delete
- ripple delete
- move
- trim
- mute, lock, and remove track
- undo and redo

Still transitional:

- Swift timeline still exists as a compatibility model for preview and export
- `refreshDisplay()` still incrementally syncs Swift timeline data into native as a safety path
- preview and export still rebuild from the Swift compatibility timeline
- preview playback still uses `AVPlayer` as the backend
