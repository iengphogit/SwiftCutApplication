# SwiftCutApplication

SwiftCutApplication is an open-source mobile video editing project focused on
basic video trimming, cutting, audio handling, and export using native media
frameworks.

## Current Progress
- Timeline UI and interaction model: `78%`
- Preview/video engine path: `62%`
- Audio engine path: `60%`
- Waveform analysis path: `80%`
- Native timeline bridge parity: `66%`
- End-to-end editor happy flow: `78%`

Current blocker:
- Audible playback from the new native audio path is not verified yet on device.

Quick references:
- [ROADMAP.md](ROADMAP.md)
- [AUDIO_ENGINE_PLAN.md](AUDIO_ENGINE_PLAN.md)
- [ENGINEERING_GUARDRAILS.md](ENGINEERING_GUARDRAILS.md)

## Platforms
- Android: MediaExtractor + MediaCodec + MediaMuxer
- iOS: AVAsset + AVMutableComposition + AVAssetExportSession

## Features
- Trim and cut video
- Split audio and video tracks
- Remove or replace audio
- Merge clips
- Export MP4
- Android & iOS friendly
- KMM-ready architecture

## Timeline Interaction
- Horizontal dragging on the timeline lane is owned by the outer timeline scroll view by default.
- Tapping a clip selects it.
- Moving a clip requires the clip to already be selected, then long-press and drag on the clip body.
- Leading and trailing trim handles remain dedicated drag zones even when the clip body is not selected for moving.
- Vertical track scrolling should only activate when the visible track area is actually overflowed.
- The editor uses one bottom tool strip with two states.
- When nothing is selected, the bottom tool strip shows main creation tools such as `Track`, `Text`, `Audio`, `Overlay`, and `Effects`.
- When a clip is selected, that same bottom tool strip switches to contextual clip tools.
- In clip-tool mode, the leading `Back` button clears selection and returns the strip to the main tool set.
- Tapping empty timeline space clears selection and returns the bottom tool strip to the main tool set.
- Real-time controls such as clip `Volume` should use preview-only UI state while dragging and commit the final value on release.

## Timeline Media Ownership
- Before audio extraction, a video clip may show its embedded audio waveform inside the main video lane.
- After audio extraction, waveform ownership moves to the new dedicated audio track below the main video track.
- After extraction, the source video clip must remain on the video track and render as filmstrip-only.
- After extraction, the extracted audio track becomes the only visible waveform owner for that source audio.
- This mirrors the expected real-world editor behavior: one visible waveform owner at a time for the same source audio.

## Native Media Direction
- The project should own its media engine layer instead of depending on third-party editor libraries.
- The recommended real-world structure is four native engine/services:
  - `TimelineEngine`
  - `VideoEngine`
  - `AudioEngine`
  - `WaveformAnalysisService`
- Waveform rendering should come from real decoded audio sample data, not placeholder or synthetic bars.
- Waveform analysis should be separate from playback transport, even when both live inside the native engine layer.
- For embedded audio in video containers, waveform extraction should prefer asset-reader based decoding instead of relying on `AVAudioFile`.
- Multi-track audio should be handled through explicit track state such as mute, volume, and solo, not only flat clip lists.
- See [AUDIO_ENGINE_PLAN.md](AUDIO_ENGINE_PLAN.md) for the dedicated native audio-engine and waveform-analysis design notes.

## Credits
Developed in Cambodia 🇰🇭 by:
- PHO ieng — iengpho@gmail.com
- SONG Tona — tonasong2019@gmail.com

## License
MIT License. See LICENSE file for details.
