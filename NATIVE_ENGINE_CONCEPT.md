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
