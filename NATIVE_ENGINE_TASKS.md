# Native Engine Tasks

This task list converts the native engine concept into concrete work for
`SwiftCutApplication`.

## Current Implementation Snapshot

Done:

- native preview surfaces replaced `VideoPlayer` and `AVPlayerViewController`
- native C++ timeline core added
- Objective-C++ timeline and preview bridges added
- Swift `NativeEditorEngine` facade added for UI-facing native access
- opening a project now routes to the timeline editor screen
- native timeline supports:
  - add-track
  - add-clip/import
  - add text/debug clip
  - remove-clip
  - ripple delete
  - move-clip
  - trim-clip
  - split-clip
  - mute, lock, and remove-track
  - undo and redo
- timeline UI now has:
  - a visible play/pause control
  - centered playhead
  - real clip thumbnails for video/overlay clips
  - capsule-bar waveforms for audio clips
  - native snapshot-backed track and clip rows

Not done yet:

- native composition engine ownership for preview and export
- native timeline as the only source of truth
- removing the old studio screen from the active editing flow entirely
- reducing Swift-to-native resync dependency during editor refresh

## Phase 1: Stabilize TimelineEngine

Goal:

- keep the edit model correct and predictable

Tasks:

- keep track and clip model serializable
- keep add, move, trim, split, ripple, lock, and overlap rules inside
  `TimelineEngine`
- remove preview-specific logic from timeline mutation code over time
- define one project FPS field as the master edit timebase

Exit criteria:

- timeline can answer active clips at time `t`
- timeline mutations do not depend on UI layout code

## Phase 2: Introduce CompositionEngine

Goal:

- separate edit structure from visual evaluation

Tasks:

- create `CompositionEngine`
- define active visual layer resolution
- define active audio clip resolution
- define clip-to-source time mapping
- define transform model for:
  - crop
  - position
  - scale
  - rotation
  - opacity
  - fit/fill/stretch

Exit criteria:

- composition can evaluate the timeline at time `t`
- timeline no longer owns render decisions

## Phase 3: Introduce PlaybackEngine

Goal:

- one deterministic timeline clock

Tasks:

- create `PlaybackEngine` or `PlaybackClock`
- move play, pause, stop, seek, and frame-step logic out of view code
- keep current timeline time in one place
- make loop behavior explicit

Exit criteria:

- playback time is the single source of truth
- playhead behavior is deterministic

## Phase 4: Native Preview Surface

Goal:

- preview becomes a real native editor viewport

Tasks:

- keep native preview surface based on native layer/view rendering
- connect preview to playback clock
- let preview consume composition output instead of raw ad hoc playback state
- support output canvas inside preview viewport
- maintain aspect ratio with letterbox/pillarbox rules

Exit criteria:

- preview shows one composed result
- viewport behavior is stable across device sizes

## Phase 5: Timeline UI Alignment

Goal:

- centered-playhead professional timeline behavior

Tasks:

- fixed vertical playhead at center
- one shared horizontal timeline canvas
- ruler and track rows in same coordinate system
- playhead tied to playback clock
- scrolling updates current time
- current time updates scroll position
- pinch-to-zoom anchored to the finger center, not the left edge
- button zoom keeps the playhead time stable
- ruler tick density adapts to zoom level over time

Exit criteria:

- timeline feels like one editor surface, not independent scroll rows

## Phase 6: Audio Engine

Goal:

- prepare proper mixed audio playback

Tasks:

- resolve active audio clips at time `t`
- map timeline time to source samples
- apply gain and mute state
- mix to one output path

Exit criteria:

- audio follows the same master timeline clock

## Phase 7: Export Reuse

Goal:

- preview and export share the same composition logic

Tasks:

- move export to consume composition evaluation
- keep preview and export feature parity
- avoid separate visual rules for preview and export

Exit criteria:

- one composition model drives both preview and export

## Immediate Next Tasks

Highest priority:

1. stop syncing Swift timeline into native on normal editor refresh
2. make native timeline the only edit source of truth
3. move preview composition to consume native composition data instead of rebuilt Swift state
4. remove or repurpose the old `StudioScreen` so the active editor surface is unambiguous

## Non-Goals Right Now

Do not do these first:

- one player per track
- one preview surface per clip
- more SwiftUI placeholder controls without engine ownership
- advanced effects before composition boundaries are clear
