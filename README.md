# SwiftCutApplication

SwiftCutApplication is an open-source mobile video editing project focused on
basic video trimming, cutting, audio handling, and export using native media
frameworks.

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

## Credits
Developed in Cambodia 🇰🇭 by:
- PHO ieng — iengpho@gmail.com
- SONG Tona — tonasong2019@gmail.com

## License
MIT License. See LICENSE file for details.
