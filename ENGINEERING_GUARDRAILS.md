# Engineering Guardrails

Use this file as the negative-rule checklist before changing timeline, preview, audio, or tool-strip behavior.

## Live Parameter Edits

These controls must behave as live parameter edits, not structural timeline edits:
- clip volume
- track volume
- opacity
- fade preview
- speed preview controls

Do not:
- rebuild the full timeline/native snapshot on every slider tick
- resync the full timeline bridge on every slider tick
- publish heavy SwiftUI layout state during a live drag
- let live slider movement reset scroll position, playhead position, or selected clip state

Do:
- keep a local UI draft value while dragging
- send lightweight live updates to the engine
- commit final persistence on drag end or after the value stabilizes
- keep current timeline time stable during the drag
- prefer preview-only overrides during drag and one real timeline commit on release

## Structural Timeline Edits

These are structural edits and can use the heavier snapshot/rebuild path:
- add track
- remove track
- import media
- extract audio
- split
- trim
- move clip
- delete
- ripple delete

Do not mix structural edit behavior into live parameter sliders.

## Audio Transport

Do not:
- reschedule audio transport every time only volume changes
- rebuild active audio nodes when clip structure is unchanged
- depend on `.mp4` container paths for direct `AVAudioFile` playback

Do:
- update existing audio node volume live when only level/mute changes
- rebuild transport only when clip structure changes:
  - clip ids
  - source path
  - source range
  - timeline range
- convert embedded video audio to a playable audio file when needed

## Timeline UI

Do not:
- let clip gestures steal default horizontal timeline scroll
- let live tool-strip interactions snap the ruler back to `0:00`
- update selection state unnecessarily during tool-strip drags
- duplicate waveform ownership across the video lane and extracted audio lane

Do:
- preserve playhead and scroll state during live parameter edits
- keep waveform ownership to one visible lane at a time
- keep extracted audio independent from video after extraction
- keep selection highlight as stable UI state, not a structural view swap
- keep empty-space deselection separate from clip tap selection
- avoid reloading thumbnail or waveform content just because selection changed

## Preview Updates

Do not:
- clear or rebuild visual layers every playback tick
- include per-frame time in structural visual signatures
- publish SwiftUI state synchronously from view update callbacks

Do:
- use stable structural signatures for overlay/layer rebuilds
- update only frame content during playback ticks
- dispatch UI state callbacks asynchronously when they originate from UIKit/native view updates

## Rule Of Thumb

If the user is dragging continuously:
- prefer lightweight engine updates
- avoid full snapshot rebuilds
- avoid layout churn
- avoid transport rescheduling unless structure truly changed
