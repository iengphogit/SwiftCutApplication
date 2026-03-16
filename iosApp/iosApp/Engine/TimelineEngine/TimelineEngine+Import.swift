import Foundation
import AVFoundation
import CoreMedia
import UIKit

extension TimelineEngine {
    func importVideo(
        from url: URL,
        toTrackType: TrackType = .video,
        at time: CMTime = .zero,
        completion: @escaping (Result<UUID, Error>) -> Void
    ) {
        let asset = AVURLAsset(url: url)
        
        asset.loadValuesAsynchronously(forKeys: ["duration", "tracks"]) { [weak self] in
            guard let self = self else { return }
            
            var error: NSError?
            let status = asset.statusOfValue(forKey: "duration", error: &error)
            
            guard status == .loaded else {
                DispatchQueue.main.async {
                    completion(.failure(error ?? NSError(domain: "TimelineEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load asset duration"])))
                }
                return
            }
            
            let duration = asset.duration
            let sourceRange = CMTimeRangeMake(start: .zero, duration: duration)
            let timelineRange = CMTimeRangeMake(start: time, duration: duration)
            
            let clipId: UUID
            
            switch toTrackType {
            case .video:
                let videoClip = VideoClip(
                    sourceUrl: url,
                    sourceRange: sourceRange,
                    timelineRange: timelineRange
                )
                clipId = self.addClip(videoClip, toTrackType: .video, named: "Video", at: time)
                
            case .audio:
                let audioClip = AudioClip(
                    sourceUrl: url,
                    sourceRange: sourceRange,
                    timelineRange: timelineRange
                )
                clipId = self.addClip(audioClip, toTrackType: .audio, named: "Audio", at: time)
                
            case .overlay:
                let overlayClip = OverlayClip(
                    sourceUrl: url,
                    sourceRange: sourceRange,
                    timelineRange: timelineRange
                )
                clipId = self.addClip(overlayClip, toTrackType: .overlay, named: "Overlay", at: time)
                
            case .text, .effect:
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "TimelineEngine", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot import media to text/effect track"])))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(clipId))
            }
        }
    }
    
    func addTextOverlay() {
        let textClip = TextClip(
            timelineRange: CMTimeRangeMake(start: currentTime, duration: CMTime(seconds: 5, preferredTimescale: 600)),
            text: "Text Overlay"
        )

        _ = addClip(textClip, toTrackType: .text, named: "Text", at: currentTime)
    }

    func addDebugClip() {
        let debugClip = TextClip(
            timelineRange: CMTimeRangeMake(start: currentTime, duration: CMTime(seconds: 3, preferredTimescale: 600)),
            text: "DEBUG CLIP"
        )

        _ = addClip(debugClip, toTrackType: .text, named: "Text", at: currentTime)
    }

    func splitAllClips(at time: CMTime) -> [UUID] {
        timeline.tracks
            .flatMap(\.clips)
            .compactMap { clip in
                splitClip(clip.id, at: time)
            }
    }

    func clearAllClips() {
        let clipIds = timeline.tracks.flatMap { track in
            track.clips.map(\.id)
        }
        for clipId in clipIds {
            removeClip(clipId)
        }
    }
}
