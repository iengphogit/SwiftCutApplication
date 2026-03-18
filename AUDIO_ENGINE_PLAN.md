# Audio Engine Plan

## Progress Snapshot

Last updated: 2026-03-18

### Audio Engine Progress: `48%`
- [x] Dedicated native `SCAudioTransportEngine` created
- [x] Audio transport ownership moved out of `SCNativePreviewView`
- [x] Swift-facing `NativeAudioEngine` created
- [x] Mix-state model added for multi-track / multi-clip payload building
- [x] Track state model includes `mute`, `volume`, and `solo`
- [x] Clip transport payload carries effective volume data
- [x] `WaveformAnalysisService` added and uses real decoded sample data
- [x] Composition layer now calculates effective track/clip audio volume
- [x] Native timeline core/bridge now stores track `volume` / `solo` and clip `volume` / `muted`
- [ ] Audible playback on real device still needs verification
- [ ] Embedded video-audio playback path still needs verification
- [ ] Track volume/solo UI controls are not wired yet
- [ ] Clip volume/mute UI controls are not wired yet
- [ ] Fade, gain automation, speed/pitch, and effects are not implemented yet

### Resume Here
1. Rebuild the iOS app after the latest native bridge changes.
2. Test a project with an extracted audio track.
3. Confirm:
   - waveform renders
   - pressing play produces audible output
   - seek/scrub keeps audio in sync
4. If there is still no sound, inspect whether `updateActiveAudioClips` receives non-empty payloads and whether `AVAudioFile` / scheduling succeeds for those sources.

## Timeline Ownership Rule

For a video source that contains embedded audio, the expected editor behavior is:
- before extraction: the video clip may show embedded waveform in the video lane
- after extraction: the video clip should remain on the main video track and become filmstrip-only
- after extraction: the dedicated audio track below becomes the sole visible waveform owner
- after extraction: the waveform must not remain duplicated in the video lane

This is the preferred real-world model for this editor because it avoids duplicating waveform meaning across both the video lane and the extracted audio lane at the same time.

## Goal

Build a fully owned native audio engine for SwiftCut that supports:
- timeline-synced playback
- multi-track audio control
- split-aware clip scheduling
- clip extraction from video sources
- waveform generation from real decoded sample data
- future editing features such as gain, fade, speed, mute, solo, and effects

This layer should be implemented only with Apple-provided frameworks such as:
- AVFoundation
- CoreMedia
- CoreAudio
- AudioToolbox

No third-party media or DSP libraries should be used.

## Why This Exists

The current editor already has timeline UI, video preview, and audio clip models, but audio responsibilities are still spread across UI code and preview bridge behavior. That makes future editing features harder to add and harder to reason about.

A dedicated native audio engine gives the project:
- clear ownership of playback transport
- better sync with the timeline and video preview
- room for real audio editing features
- a proper place to generate and cache waveform data

In the broader editor architecture, the recommended engine split is:
- `TimelineEngine`
- `VideoEngine`
- `AudioEngine`
- `WaveformAnalysisService`

## Core Direction

Separate audio responsibilities into two native services:

1. `AudioEngine`
- owns playback transport
- owns play, pause, seek, scrub, sync
- owns track-level audio state such as mute, solo, gain, fade
- will eventually own audio effect processing

2. `WaveformAnalysisService`
- reads source media and decodes audio sample data
- generates waveform buckets for UI rendering
- caches waveform results
- does not depend on live playback state

Waveform analysis should not be coupled to the playback engine.

## Recommended Module Shape

### `AudioEngine`
Responsibilities:
- load audio sources from timeline clips
- keep audio playback synchronized to timeline time
- respect split, trim, move, and delete operations coming from the timeline layer
- support paused scrubbing and playback resume
- manage track gain, mute, solo, and lock-related playback rules
- prepare for future mixing and DSP

Possible subcomponents:
- `AudioTransportController`
- `AudioMixer`
- `AudioClipRenderer`
- `AudioTrackState`

### `WaveformAnalysisService`
Responsibilities:
- decode audio from file URLs
- support standalone audio files and video files with embedded audio
- produce normalized waveform values from real sample buffers
- cache data by source and target resolution

Possible subcomponents:
- `WaveformDecoder`
- `WaveformBucketizer`
- `WaveformCache`

## Waveform Strategy

The waveform should be based on real sample data, not synthetic or placeholder bars.

Recommended pipeline:

1. Load media asset
- use `AVURLAsset`

2. Decode audio samples
- prefer `AVAssetReader` for both audio files and video files with embedded audio
- convert output to PCM buffers

3. Bucket the samples
- derive `targetBarCount` from visible width or zoom
- group sample amplitudes into buckets
- compute normalized values using peak, RMS, or a blended model

4. Cache the result
- key by source path and target bar count
- optionally add zoom-based cache variants later

5. Render in SwiftUI
- timeline views consume only normalized waveform arrays
- UI should not perform media decoding itself

## Why `AVAssetReader` First

`AVAudioFile` is useful for direct audio files, but it is not the right general solution for media containers like `.mp4`.

For a timeline editor, the more reliable default is:
- `AVAssetReader` for decoding audio from any source asset

That keeps the decoding path consistent across:
- audio imports
- extracted audio
- embedded audio inside video clips

## Audio Playback Direction

Playback should move toward a dedicated native transport model:
- timeline playhead is the source of truth
- video preview and audio engine both sync to the same timeline time
- manual scrubbing should not depend on UI-only state hacks

Needed behaviors:
- play
- pause
- seek
- scrub preview
- resume from scrubbed position
- schedule split clip segments using the correct source offsets and durations
- multi-track enable/disable
- per-track volume, mute, and solo
- clip-level volume and mute that combine with track state

## Functional Milestones

### Phase 1
- define `AudioEngine` interface
- define `WaveformAnalysisService` interface
- move waveform decoding responsibility out of UI rendering code
- use real decoded sample buckets for waveform display

### Phase 2
- support timeline-synced audio playback transport
- support seek and paused scrubbing
- support extracted audio track playback below source video clips
- support split clip scheduling so left/right clip segments still play the correct source ranges

### Phase 3
- support per-track volume and mute
- support fade in/out
- support clip gain automation basics
- support trim, move, delete, and ripple-safe playback updates after timeline edits

### Phase 4
- support custom audio effects
- support time stretch / speed change
- support richer waveform detail and zoom-aware caching
- support higher-level convenience edits such as compatible clip swap operations

## Non-Goals

This plan does not require:
- third-party DSP libraries
- FFmpeg
- copied codec or processing code
- coupling waveform drawing to live playback sessions

## Immediate Next Step

Implement a native `WaveformAnalysisService` based on `AVAssetReader` and make the timeline waveform UI consume its cached bucket output instead of owning the analysis path directly.
