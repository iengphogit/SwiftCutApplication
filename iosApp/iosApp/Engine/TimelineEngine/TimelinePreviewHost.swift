import SwiftUI

struct PreviewSeekCommand: Equatable {
    let id = UUID()
    let timeSeconds: Double
}

struct NativeEnginePreviewHost: UIViewRepresentable {
    let compositionFrame: CompositionFrame?
    let durationSeconds: Double
    let desiredIsPlaying: Bool
    let seekCommand: PreviewSeekCommand?
    let onDisplayTimeChange: (Double) -> Void
    let onPlaybackStateChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNativePreviewView {
        let view = SCNativePreviewView()
        update(view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: SCNativePreviewView, context: Context) {
        update(uiView, coordinator: context.coordinator)
    }

    private func update(_ view: SCNativePreviewView, coordinator: Coordinator) {
        let visualClipCount = compositionFrame?.visualClips.count ?? 0
        let audioClipCount = compositionFrame?.audioClips.count ?? 0
        let activeVisualSummary = activeVisualSummary
        let activeTextOverlays = activeTextOverlays
        let activeVisualOverlays = activeVisualOverlays
        let activeAudioClips = activeAudioClips

        view.onDisplayTimeChange = onDisplayTimeChange
        view.onPlaybackStateChange = onPlaybackStateChange
        if coordinator.lastAppliedPreviewDurationSeconds != durationSeconds {
            view.setPreviewDurationSeconds(durationSeconds)
            coordinator.lastAppliedPreviewDurationSeconds = durationSeconds
        }
        if coordinator.lastAppliedPlaybackState != desiredIsPlaying {
            view.setDesiredPlaybackState(desiredIsPlaying)
            coordinator.lastAppliedPlaybackState = desiredIsPlaying
        }
        if coordinator.lastAppliedSeekCommandId != seekCommand?.id {
            if let seekCommand {
                view.seek(toTimeSeconds: seekCommand.timeSeconds)
            }
            coordinator.lastAppliedSeekCommandId = seekCommand?.id
        }
        if coordinator.lastAppliedVisualClipCount != visualClipCount ||
            coordinator.lastAppliedAudioClipCount != audioClipCount ||
            coordinator.lastAppliedVisualSummary != activeVisualSummary {
            view.updateCompositionVisualClipCount(
                visualClipCount,
                audioClipCount: audioClipCount,
                activeVisualSummary: activeVisualSummary
            )
            coordinator.lastAppliedVisualClipCount = visualClipCount
            coordinator.lastAppliedAudioClipCount = audioClipCount
            coordinator.lastAppliedVisualSummary = activeVisualSummary
        }

        let activeTextOverlaySignature = textOverlaySignature(activeTextOverlays)
        if coordinator.lastAppliedTextOverlaySignature != activeTextOverlaySignature {
            view.updateActiveTextOverlays(activeTextOverlays)
            coordinator.lastAppliedTextOverlaySignature = activeTextOverlaySignature
        }

        let activeVisualOverlaySignature = visualOverlaySignature(activeVisualOverlays)
        if coordinator.lastAppliedVisualOverlaySignature != activeVisualOverlaySignature {
            view.updateActiveVisualOverlays(activeVisualOverlays)
            coordinator.lastAppliedVisualOverlaySignature = activeVisualOverlaySignature
        }

        let activeAudioClipSignature = audioClipSignature(activeAudioClips)
        if coordinator.lastAppliedAudioClipSignature != activeAudioClipSignature {
            view.updateActiveAudioClips(activeAudioClips)
            coordinator.lastAppliedAudioClipSignature = activeAudioClipSignature
        }
    }

    private var activeVisualSummary: String {
        guard let compositionFrame, let leadClip = compositionFrame.visualClips.first else {
            return "No active layer"
        }

        switch leadClip.kind {
        case .text:
            let text = leadClip.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? "Text layer active" : "Text: \(text)"
        case .overlay:
            return compositionFrame.visualClips.count > 1
                ? "Overlay active +\(compositionFrame.visualClips.count - 1)"
                : "Overlay active"
        case .video:
            return compositionFrame.visualClips.count > 1
                ? "Video active +\(compositionFrame.visualClips.count - 1)"
                : "Video active"
        }
    }

    private var activeTextOverlays: [[AnyHashable: Any]] {
        guard let compositionFrame else {
            return []
        }

        return compositionFrame.visualClips.compactMap { clip in
            guard clip.kind == .text, let text = clip.text, !text.isEmpty else {
                return nil
            }

            let canvasWidth = max(compositionFrame.outputSize.width, 1)
            let canvasHeight = max(compositionFrame.outputSize.height, 1)
            let rawX = clip.transform.position.x == 0 ? canvasWidth / 2 : clip.transform.position.x
            let rawY = clip.transform.position.y == 0 ? canvasHeight / 2 : clip.transform.position.y
            let style = clip.textStyle ?? .default

            return [
                "text": text,
                "normalizedX": min(max(rawX / canvasWidth, 0.05), 0.95),
                "normalizedY": min(max(rawY / canvasHeight, 0.08), 0.92),
                "fontName": style.fontName,
                "fontSize": Double(style.fontSize),
                "textColorHex": style.textColorHex,
                "backgroundColorHex": style.backgroundColorHex ?? "",
                "shadowColorHex": style.shadowColorHex ?? "",
                "shadowOffsetX": Double(style.shadowOffset.width),
                "shadowOffsetY": Double(style.shadowOffset.height),
                "shadowBlur": Double(style.shadowBlur),
                "alignment": style.alignment.rawValue
            ]
        }
    }

    private var activeVisualOverlays: [[AnyHashable: Any]] {
        guard let compositionFrame else {
            return []
        }

        return compositionFrame.visualClips.compactMap { clip in
            guard clip.kind == .video || clip.kind == .overlay else {
                return nil
            }

            let canvasWidth = max(compositionFrame.outputSize.width, 1)
            let canvasHeight = max(compositionFrame.outputSize.height, 1)
            let rawX = clip.transform.position.x == 0 ? canvasWidth / 2 : clip.transform.position.x
            let rawY = clip.transform.position.y == 0 ? canvasHeight / 2 : clip.transform.position.y

            return [
                "kind": clip.kind.rawValue,
                "clipId": clip.id.uuidString,
                "normalizedX": min(max(rawX / canvasWidth, 0.05), 0.95),
                "normalizedY": min(max(rawY / canvasHeight, 0.08), 0.92),
                "scaleX": Double(max(clip.transform.scale.width, 0.2)),
                "scaleY": Double(max(clip.transform.scale.height, 0.2)),
                "scaleMode": clip.transform.scaleMode.rawValue,
                "rotationDegrees": clip.transform.rotationDegrees,
                "opacity": clip.transform.opacity,
                "sourcePath": clip.sourceURL?.path ?? "",
                "sourceTimeSeconds": clip.sourceTimeSeconds,
                "frameTimelineTimeSeconds": compositionFrame.timelineTimeSeconds,
                "renderContent": clip.kind == .overlay || clip.kind == .video,
                "cropX": normalizedCropRect(for: clip)?.origin.x ?? -1,
                "cropY": normalizedCropRect(for: clip)?.origin.y ?? -1,
                "cropWidth": normalizedCropRect(for: clip)?.size.width ?? -1,
                "cropHeight": normalizedCropRect(for: clip)?.size.height ?? -1
            ]
        }
    }

    private var activeAudioClips: [[AnyHashable: Any]] {
        guard let compositionFrame else {
            return []
        }

        return compositionFrame.audioClips.map { clip in
            let timelineEnd = clip.timelineRange.start.seconds + clip.timelineRange.duration.seconds
            return [
                "clipId": clip.id.uuidString,
                "sourcePath": clip.sourceURL.path,
                "sourceTimeSeconds": clip.sourceTimeSeconds,
                "remainingDurationSeconds": max(timelineEnd - compositionFrame.timelineTimeSeconds, 0),
                "volume": Double(clip.volume),
                "muted": clip.isMuted
            ]
        }
    }

    private func normalizedCropRect(for clip: VisualClipSnapshot) -> CGRect? {
        guard let cropRect = clip.transform.cropRect else {
            return nil
        }

        let isNormalized =
            cropRect.origin.x >= 0 && cropRect.origin.x <= 1 &&
            cropRect.origin.y >= 0 && cropRect.origin.y <= 1 &&
            cropRect.size.width > 0 && cropRect.size.width <= 1 &&
            cropRect.size.height > 0 && cropRect.size.height <= 1

        guard isNormalized else {
            return nil
        }

        return cropRect
    }

    private func textOverlaySignature(_ overlays: [[AnyHashable: Any]]) -> String {
        overlays.map { overlay in
            let text = overlay["text"] as? String ?? ""
            let normalizedX = overlay["normalizedX"] as? Double ?? 0
            let normalizedY = overlay["normalizedY"] as? Double ?? 0
            let fontName = overlay["fontName"] as? String ?? ""
            let fontSize = overlay["fontSize"] as? Double ?? 0
            return "\(text)|\(normalizedX)|\(normalizedY)|\(fontName)|\(fontSize)"
        }
        .joined(separator: ",")
    }

    private func visualOverlaySignature(_ overlays: [[AnyHashable: Any]]) -> String {
        overlays.map { overlay in
            let clipId = overlay["clipId"] as? String ?? ""
            let sourcePath = overlay["sourcePath"] as? String ?? ""
            let sourceTimeSeconds = overlay["sourceTimeSeconds"] as? Double ?? 0
            let frameTimelineTimeSeconds = overlay["frameTimelineTimeSeconds"] as? Double ?? 0
            return "\(clipId)|\(sourcePath)|\(sourceTimeSeconds)|\(frameTimelineTimeSeconds)"
        }
        .joined(separator: ",")
    }

    private func audioClipSignature(_ clips: [[AnyHashable: Any]]) -> String {
        clips.map { clip in
            let clipId = clip["clipId"] as? String ?? ""
            let sourcePath = clip["sourcePath"] as? String ?? ""
            let sourceTimeSeconds = clip["sourceTimeSeconds"] as? Double ?? 0
            let remainingDurationSeconds = clip["remainingDurationSeconds"] as? Double ?? 0
            let volume = clip["volume"] as? Double ?? 1
            let muted = clip["muted"] as? Bool ?? false
            return "\(clipId)|\(sourcePath)|\(sourceTimeSeconds)|\(remainingDurationSeconds)|\(volume)|\(muted)"
        }
        .joined(separator: ",")
    }

    final class Coordinator {
        var lastAppliedPreviewDurationSeconds: Double?
        var lastAppliedPlaybackState: Bool?
        var lastAppliedSeekCommandId: UUID?
        var lastAppliedVisualClipCount: Int?
        var lastAppliedAudioClipCount: Int?
        var lastAppliedVisualSummary: String?
        var lastAppliedTextOverlaySignature: String?
        var lastAppliedVisualOverlaySignature: String?
        var lastAppliedAudioClipSignature: String?
    }
}
