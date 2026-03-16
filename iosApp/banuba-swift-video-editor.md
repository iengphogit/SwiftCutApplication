# Implementation Notes: Banuba "How to Make a Swift Video Editor"

Source: https://www.banuba.com/blog/how-to-make-swift-video-editor

## Summary
- Article overview of building a basic Swift video editor with AVFoundation, plus a comparison of SwiftUI vs. UIKit.
- Presents an 8-step implementation outline for a simple editor and a 3-step SDK integration option.
- Emphasizes hybrid UI: SwiftUI for screens/panels, UIKit for complex timeline widgets.

## Key Components (Native)
- AVFoundation core types: AVAsset, AVAssetTrack, AVMutableComposition, AVVideoComposition, AVAssetExportSession
- Playback: AVPlayer, AVPlayerViewController
- Timeline UI: UISlider or custom timeline view
- Effects: Core Image (CIFilter)
- Audio: AVAudioEngine / AVAudioMix
- Optional: Metal for heavier effects

## Core Classes (No Single VideoEditor Class)
- Timeline/editing: AVMutableComposition
- Video effects/transform: AVVideoComposition, AVMutableVideoCompositionInstruction
- Audio mixing: AVAudioMix, AVMutableAudioMixInputParameters
- Playback: AVPlayer, AVPlayerItem, AVPlayerViewController
- Export: AVAssetExportSession
- Filters: CIFilter (Core Image) or Metal

## Viewport & Layer Types (Suggested Model)
- Treat the viewport as a preview of the composed timeline at a given time.
- Render layers in z-order with crop -> transform -> opacity -> blend.
- Use AVMutableComposition + AVVideoComposition (or CIFilter handler) for transforms/crops/filters.
- For text/image overlays, use Core Image compositing or CALayer with AVVideoCompositionCoreAnimationTool.

Typical layer types:
- Video clip layer
- Audio clip layer
- Image/sticker layer
- Text layer
- Shape/overlay layer
- Adjustment layer (global color/FX)
- Transition layer (between clips)
- Optional: effect/mask layer

MVP layer set:
1. Video clip layer (trim, split, speed, transform, crop)
2. Audio clip layer (trim, fades, volume)
3. Text layer (position, scale, rotation, opacity)
4. Overlay/image layer (stickers, watermark)
5. Global adjustment (color filter/LUT)

## JSON-Based Template System
- Save templates as JSON with slots for media, text, audio, and style settings.
- Load template -> bind user media to slots -> render timeline.
- Keep template data separate from user assets for reuse.

Suggested template JSON (minimal but flexible):
```json
{
  "id": "template_intro_001",
  "name": "Punchy Intro",
  "version": 1,
  "aspectRatio": "9:16",
  "fps": 30,
  "durationSeconds": 8.0,
  "slots": [
    { "id": "video_1", "type": "video", "durationSeconds": 3.0 },
    { "id": "video_2", "type": "video", "durationSeconds": 3.0 },
    { "id": "title", "type": "text", "defaultText": "Your Title" },
    { "id": "music", "type": "audio", "durationSeconds": 8.0 }
  ],
  "layers": [
    {
      "id": "clip_1",
      "type": "video",
      "slotId": "video_1",
      "start": 0.0,
      "duration": 3.0,
      "transform": { "scale": 1.0, "rotation": 0.0, "x": 0, "y": 0 },
      "crop": { "x": 0, "y": 0, "w": 1, "h": 1 }
    },
    {
      "id": "clip_2",
      "type": "video",
      "slotId": "video_2",
      "start": 3.0,
      "duration": 3.0,
      "transition": { "type": "crossfade", "duration": 0.5 }
    },
    {
      "id": "title_1",
      "type": "text",
      "slotId": "title",
      "start": 0.2,
      "duration": 2.5,
      "style": {
        "font": "BebasNeue-Regular",
        "size": 64,
        "color": "#FFFFFF",
        "strokeColor": "#000000",
        "strokeWidth": 2,
        "alignment": "center"
      },
      "transform": { "scale": 1.0, "rotation": 0.0, "x": 0, "y": -240 }
    },
    {
      "id": "music_1",
      "type": "audio",
      "slotId": "music",
      "start": 0.0,
      "duration": 8.0,
      "volume": 0.8,
      "fadeIn": 1.0,
      "fadeOut": 1.0
    }
  ],
  "adjustments": [
    { "type": "lut", "name": "WarmFilm", "intensity": 0.6 }
  ]
}
```

Notes:
- `slots` describe replaceable inputs; `layers` reference slots with timing and transforms.
- Normalize crop to [0..1] for simple device-agnostic framing.
- Extend with keyframes, masks, or per-layer effects when needed.

## Original Template Example (Custom Style)
This example is an original structure and styling (not based on any third-party template).

```json
{
  "id": "template_slate_001",
  "name": "Slate Pulse",
  "version": 1,
  "aspectRatio": "9:16",
  "fps": 30,
  "durationSeconds": 10.0,
  "style": {
    "palette": {
      "bg": "#0E1116",
      "accent": "#F2C94C",
      "text": "#F5F7FA"
    },
    "fonts": {
      "title": "SpaceGrotesk-Bold",
      "body": "SpaceGrotesk-Regular"
    }
  },
  "slots": [
    { "id": "video_a", "type": "video", "durationSeconds": 4.0 },
    { "id": "video_b", "type": "video", "durationSeconds": 4.0 },
    { "id": "title", "type": "text", "defaultText": "Your Story" },
    { "id": "subtitle", "type": "text", "defaultText": "In 10 seconds" },
    { "id": "music", "type": "audio", "durationSeconds": 10.0 }
  ],
  "layers": [
    {
      "id": "bg_color",
      "type": "shape",
      "trackIndex": 0,
      "start": 0.0,
      "duration": 10.0,
      "fill": "#0E1116",
      "opacity": 1.0
    },
    {
      "id": "clip_a",
      "type": "video",
      "slotId": "video_a",
      "trackIndex": 1,
      "start": 0.0,
      "duration": 4.0,
      "transform": { "scale": 1.08, "rotation": 0.0, "x": 0, "y": 0 },
      "crop": { "x": 0.05, "y": 0.0, "w": 0.90, "h": 1.0 }
    },
    {
      "id": "clip_b",
      "type": "video",
      "slotId": "video_b",
      "trackIndex": 1,
      "start": 4.0,
      "duration": 4.0,
      "transition": { "type": "wipe", "direction": "right", "duration": 0.4 }
    },
    {
      "id": "title_text",
      "type": "text",
      "slotId": "title",
      "trackIndex": 2,
      "start": 0.3,
      "duration": 2.6,
      "style": {
        "font": "SpaceGrotesk-Bold",
        "size": 72,
        "color": "#F5F7FA",
        "tracking": 1.2,
        "alignment": "center"
      },
      "transform": { "scale": 1.0, "rotation": 0.0, "x": 0, "y": -280 },
      "animation": { "type": "pop", "duration": 0.35 }
    },
    {
      "id": "subtitle_text",
      "type": "text",
      "slotId": "subtitle",
      "trackIndex": 2,
      "start": 1.0,
      "duration": 2.0,
      "style": {
        "font": "SpaceGrotesk-Regular",
        "size": 32,
        "color": "#F2C94C",
        "alignment": "center"
      },
      "transform": { "scale": 1.0, "rotation": 0.0, "x": 0, "y": -210 },
      "animation": { "type": "slideUp", "duration": 0.4 }
    },
    {
      "id": "music_track",
      "type": "audio",
      "slotId": "music",
      "trackIndex": 0,
      "start": 0.0,
      "duration": 10.0,
      "volume": 0.75,
      "fadeIn": 0.6,
      "fadeOut": 0.8
    }
  ],
  "adjustments": [
    { "type": "colorBalance", "shadows": [-2, 0, 4], "midtones": [0, 0, 0], "highlights": [4, 2, -2] }
  ]
}
```

Notes:
- `trackIndex` is optional but useful for multi-track ordering.
- Styles are original; replace fonts/colors with your own brand system.

## SwiftUI vs. UIKit (UI Guidance)
- SwiftUI: fast for forms/settings and app flow; good for iteration.
- UIKit: better for performance-sensitive, custom timeline interactions.
- Recommended approach: hybrid UI (SwiftUI for panels, UIKit for timeline).

## Simple Editor: 8-Step Outline (from the article)
1. Set up the app and add AVFoundation/AVKit/CoreImage.
2. Build an editable timeline by trimming with AVMutableComposition.
3. Merge clips and add transitions via AVVideoComposition layer instructions.
4. Apply real-time filters with Core Image.
5. Add background music and fades with AVAudioMix.
6. Preview the composition with AVPlayer/AVPlayerViewController.
7. Provide a scrub timeline (UISlider or custom view).
8. Export with AVAssetExportSession.

## Must-Have Features (Article)
- Recording
- Video editing
- Audio browser/effects
- Face AR (optional/advanced)

## Use Cases Mentioned
- Social media and short video apps
- Photo and video apps
- Other communication and UGC-style apps

## SDK Integration Option (Banuba)
- Offers a ready-made iOS video editor SDK.
- Integration paths: CocoaPods or Swift Package Manager.
- Requirements listed in the article: Swift 5.9+, Xcode 15.2+, iOS 15.0+.
- Trial access requires a token from Banuba.

## Notes
- This doc summarizes the article for implementation planning; refer to the source for full details and code samples.
