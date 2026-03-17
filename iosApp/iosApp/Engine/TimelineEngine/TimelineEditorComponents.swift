import SwiftUI
import AVFoundation
import UIKit

struct RatioGlassPanel: View {
    let selectedRatio: AspectRatio
    let onSelect: (AspectRatio) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Button(action: { onSelect(ratio) }) {
                        RatioGlassOption(
                            ratio: ratio,
                            isSelected: ratio == selectedRatio
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(8)
    }
}

private struct RatioGlassOption: View {
    let ratio: AspectRatio
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                .frame(width: ratio.iconSize.width, height: ratio.iconSize.height)

            Text(ratio.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.35) : Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.blue.opacity(0.85) : Color.white.opacity(0.14),
                    lineWidth: 1
                )
        )
    }
}

struct UhdGlassPanel: View {
    var onSelectResolution: (UhdResolution) -> Void
    var onSelectFrameRate: (UhdFrameRate) -> Void
    var onSelectBitrate: (UhdBitrate) -> Void
    var onApply: () -> Void
    let selectedResolution: UhdResolution
    let selectedFrameRate: UhdFrameRate
    let selectedBitrate: UhdBitrate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            glassSectionTitle("Resolution")
            GlassStepSelectorRow(
                items: UhdResolution.allCases,
                selectedItem: selectedResolution,
                label: { $0.displayName },
                onSelect: onSelectResolution
            )

            glassSectionTitle("Frame Rate")
            GlassStepSelectorRow(
                items: UhdFrameRate.allCases,
                selectedItem: selectedFrameRate,
                label: { $0.displayName },
                onSelect: onSelectFrameRate
            )

            glassSectionTitle("Bitrate")
            GlassStepSelectorRow(
                items: UhdBitrate.allCases,
                selectedItem: selectedBitrate,
                label: { $0.displayName },
                onSelect: onSelectBitrate
            )

            Button(action: onApply) {
                Text("Apply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(8)
    }

    private func glassSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct GlassStepSelectorRow<Option: Hashable>: View {
    let items: [Option]
    let selectedItem: Option
    let label: (Option) -> String
    var onSelect: (Option) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button(action: { onSelect(item) }) {
                        Text(label(item))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        item == selectedItem
                                            ? Color.blue.opacity(0.32)
                                            : Color.white.opacity(0.08)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        item == selectedItem
                                            ? Color.blue.opacity(0.85)
                                            : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HeaderGlassButton: View {
    let title: String
    var ratioIconSize: CGSize? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let ratioIconSize {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
                    .frame(width: ratioIconSize.width, height: ratioIconSize.height)
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct TimelineToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    )
                
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct TimelineBottomToolButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

struct TrackLaneView: View {
    let track: TrackDisplayModel
    let timelineWidth: CGFloat
    let leadingTimelineInset: CGFloat
    let rightLanePadding: CGFloat
    let zoomScale: CGFloat
    @Binding var selectedClipId: UUID?
    let onClipTap: (UUID) -> Void
    let onClipMove: (UUID, Double) -> Void
    let onClipTrimLeading: (UUID, Double, Double, Double) -> Void
    let onClipTrimTrailing: (UUID, Double, Double) -> Void
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.035))
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )

            ForEach(track.clips) { clip in
                TimelineClipItemView(
                    clip: clip,
                    zoomScale: zoomScale,
                    isSelected: selectedClipId == clip.id,
                    expandsVideoAudio: track.type == .video,
                    baseOffset: leadingTimelineInset + clip.startOffset(zoomScale: zoomScale),
                    pointsPerSecond: 60 * zoomScale,
                    canMove: !track.isLocked,
                    onTap: {
                        onClipTap(clip.id)
                    },
                    onMoveCommit: { newStartSeconds in
                        onClipMove(clip.id, newStartSeconds)
                    },
                    onLeadingTrimCommit: { timelineStartSeconds, sourceStartSeconds, sourceDurationSeconds in
                        onClipTrimLeading(
                            clip.id,
                            timelineStartSeconds,
                            sourceStartSeconds,
                            sourceDurationSeconds
                        )
                    },
                    onTrailingTrimCommit: { sourceStartSeconds, sourceDurationSeconds in
                        onClipTrimTrailing(
                            clip.id,
                            sourceStartSeconds,
                            sourceDurationSeconds
                        )
                    }
                )
            }
        }
        .padding(.leading, rightLanePadding)
        .frame(width: timelineWidth, height: laneBodyHeight, alignment: .leading)
        .frame(height: laneHeight)
        .background(
            Rectangle()
                .fill(Color(white: 0.11))
        )
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    private var laneHeight: CGFloat {
        track.type == .video ? 74 : 52
    }

    private var laneBodyHeight: CGFloat {
        track.type == .video ? 66 : 44
    }
}

private struct TimelineClipItemView: View {
    let clip: ClipDisplayModel
    let zoomScale: CGFloat
    let isSelected: Bool
    let expandsVideoAudio: Bool
    let baseOffset: CGFloat
    let pointsPerSecond: CGFloat
    let canMove: Bool
    let onTap: () -> Void
    let onMoveCommit: (Double) -> Void
    let onLeadingTrimCommit: (Double, Double, Double) -> Void
    let onTrailingTrimCommit: (Double, Double) -> Void

    @GestureState private var dragTranslationX: CGFloat = 0
    @GestureState private var leadingTrimTranslationX: CGFloat = 0
    @GestureState private var trailingTrimTranslationX: CGFloat = 0
    @State private var isMoveGestureActive = false
    @State private var isLeadingTrimActive = false
    @State private var isTrailingTrimActive = false

    var body: some View {
        ZStack {
            ClipView(
                clip: clip,
                zoomScale: zoomScale,
                isSelected: isSelected || isMoveGestureActive || isLeadingTrimActive || isTrailingTrimActive,
                expandsVideoAudio: expandsVideoAudio
            )
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isMoveGestureActive, !isLeadingTrimActive, !isTrailingTrimActive else { return }
                onTap()
            }
            .simultaneousGesture(canMove ? moveGesture : nil)

            if canMove {
                HStack(spacing: 0) {
                    trimHandle
                        .gesture(leadingTrimGesture)
                    Spacer(minLength: 0)
                    trimHandle
                        .gesture(trailingTrimGesture)
                }
            }
        }
        .frame(width: clipWidth, height: nil, alignment: .center)
        .offset(
            x: baseOffset + activeDragOffset + leadingTrimVisualOffset,
            y: 0
        )
    }

    private var activeDragOffset: CGFloat {
        max(-baseOffset, dragTranslationX)
    }

    private var clipWidth: CGFloat {
        clip.width(zoomScale: zoomScale)
    }

    private var leadingTrimVisualOffset: CGFloat {
        if isTrailingTrimActive {
            return 0
        }
        return clampedLeadingTrimTranslation
    }

    private var clampedLeadingTrimTranslation: CGFloat {
        min(
            max(leadingTrimTranslationX, -baseOffset),
            max(clipWidth - minimumClipWidth, 0)
        )
    }

    private var clampedTrailingTrimTranslation: CGFloat {
        max(trailingTrimTranslationX, -(clipWidth - minimumClipWidth))
    }

    private var minimumClipWidth: CGFloat {
        max(pointsPerSecond * minimumTimelineDurationSeconds, 28)
    }

    private var minimumTimelineDurationSeconds: Double {
        0.25
    }

    private var sourceSecondsPerTimelineSecond: Double {
        guard clip.durationSeconds > 0.0001 else { return 1 }
        return clip.sourceDurationSeconds / clip.durationSeconds
    }

    private var trimHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.88))
            .frame(width: 8, height: 26)
            .padding(.horizontal, 2)
    }

    private var moveGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .updating($dragTranslationX) { value, state, _ in
                if case .second(true, let drag?) = value {
                    state = drag.translation.width
                }
            }
            .onChanged { value in
                if case .second(true, _) = value {
                    isMoveGestureActive = true
                }
            }
            .onEnded { value in
                defer { isMoveGestureActive = false }
                guard case .second(true, let drag?) = value else { return }
                let deltaSeconds = Double(activeDragOffset / max(pointsPerSecond, 1))
                let newStartSeconds = max(0, clip.startSeconds + deltaSeconds)
                onMoveCommit(newStartSeconds)
            }
    }

    private var leadingTrimGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($leadingTrimTranslationX) { value, state, _ in
                state = value.translation.width
            }
            .onChanged { _ in
                isLeadingTrimActive = true
            }
            .onEnded { _ in
                defer { isLeadingTrimActive = false }
                let deltaTimelineSeconds = Double(clampedLeadingTrimTranslation / max(pointsPerSecond, 1))
                guard abs(deltaTimelineSeconds) > 0.0001 else { return }

                let newTimelineStart = max(0, clip.startSeconds + deltaTimelineSeconds)
                let deltaSourceSeconds = deltaTimelineSeconds * sourceSecondsPerTimelineSecond
                let newSourceStart = max(0, clip.sourceStartSeconds + deltaSourceSeconds)
                let newSourceDuration = max(
                    minimumTimelineDurationSeconds * sourceSecondsPerTimelineSecond,
                    clip.sourceDurationSeconds - deltaSourceSeconds
                )

                onLeadingTrimCommit(newTimelineStart, newSourceStart, newSourceDuration)
            }
    }

    private var trailingTrimGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($trailingTrimTranslationX) { value, state, _ in
                state = value.translation.width
            }
            .onChanged { _ in
                isTrailingTrimActive = true
            }
            .onEnded { _ in
                defer { isTrailingTrimActive = false }
                let deltaTimelineSeconds = Double(clampedTrailingTrimTranslation / max(pointsPerSecond, 1))
                guard abs(deltaTimelineSeconds) > 0.0001 else { return }

                let deltaSourceSeconds = deltaTimelineSeconds * sourceSecondsPerTimelineSecond
                let newSourceDuration = max(
                    minimumTimelineDurationSeconds * sourceSecondsPerTimelineSecond,
                    clip.sourceDurationSeconds + deltaSourceSeconds
                )

                onTrailingTrimCommit(clip.sourceStartSeconds, newSourceDuration)
            }
    }
}

struct TrackHeaderView: View {
    let track: TrackDisplayModel
    let leftChannelWidth: CGFloat
    let onToggleMute: () -> Void
    let onToggleLock: () -> Void
    let onRemoveTrack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(trackColor(track.type).opacity(0.18))
                        .frame(width: 24, height: 24)

                    Image(systemName: iconForType(track.type))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(trackColor(track.type))
                }

                Text(trackShortName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .frame(minWidth: 42, alignment: .trailing)

            HStack(spacing: 10) {
                channelButton(
                    systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                    tint: track.isMuted ? .yellow.opacity(0.95) : .white.opacity(0.72),
                    action: onToggleMute
                )

                channelButton(
                    systemName: track.isLocked ? "lock.fill" : "lock.open.fill",
                    tint: track.isLocked ? .red.opacity(0.95) : .white.opacity(0.72),
                    action: onToggleLock
                )

                if canRemoveTrack {
                    channelButton(
                        systemName: "minus.circle.fill",
                        tint: .white.opacity(0.72),
                        action: onRemoveTrack
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(width: max(leftChannelWidth - 26, 0), alignment: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .background(
            Rectangle()
                .fill(trackColor(track.type).opacity(0.12))
        )
        .overlay(
            Rectangle()
                .stroke(trackColor(track.type).opacity(0.32), lineWidth: 1)
        )
        .frame(width: leftChannelWidth, height: laneHeight, alignment: .trailing)
    }

    private func channelButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
    
    private func iconForType(_ type: TrackType) -> String {
        switch type {
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .text: return "textformat"
        case .overlay: return "square.on.square"
        case .effect: return "sparkles"
        }
    }
    
    private func trackColor(_ type: TrackType) -> Color {
        switch type {
        case .video: return .blue
        case .audio: return .green
        case .text: return .orange
        case .overlay: return .purple
        case .effect: return .pink
        }
    }

    private var trackShortName: String {
        switch track.type {
        case .video: return "VID"
        case .audio: return "AUD"
        case .text: return "TXT"
        case .overlay: return "OVR"
        case .effect: return "FX"
        }
    }

    private var canRemoveTrack: Bool {
        track.type != .video
    }

    private var laneHeight: CGFloat {
        track.type == .video ? 74 : 52
    }
}

private struct ClipView: View {
    let clip: ClipDisplayModel
    let zoomScale: CGFloat
    let isSelected: Bool
    let expandsVideoAudio: Bool

    @State private var showsEmbeddedAudio = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            clipBackground

            HStack(spacing: 6) {
                clipLeadingVisual

                Text(clip.name)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.trailing, 4)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.top, overlayTopPadding)
        }
        .frame(width: clip.width(zoomScale: zoomScale), height: clipHeight)
        .background(clipColor(clip.type))
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .task(id: "\(clip.type)-\(clip.sourcePath)") {
            guard clip.type == .video, expandsVideoAudio else {
                showsEmbeddedAudio = false
                return
            }
            showsEmbeddedAudio = await TimelineClipVisualCache.hasAudioTrack(for: clip.sourcePath)
        }
    }

    @ViewBuilder
    private var clipBackground: some View {
        switch clip.type {
        case .audio:
            AudioWaveformStrip(sourcePath: clip.sourcePath)
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
        case .video where expandsVideoAudio && showsEmbeddedAudio:
            VStack(spacing: 1) {
                TimelineClipThumbnailStrip(
                    sourcePath: clip.sourcePath,
                    durationSeconds: clip.durationSeconds
                )
                .frame(height: 34)

                AudioWaveformStrip(sourcePath: clip.sourcePath)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(height: 21)
                    .background(Color.black.opacity(0.18))
            }
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .video, .overlay:
            TimelineClipThumbnailStrip(
                sourcePath: clip.sourcePath,
                durationSeconds: clip.durationSeconds
            )
            .overlay(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.08),
                        Color.black.opacity(0.36)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .text:
            Color.orange.opacity(0.18)
        case .effect:
            Color.pink.opacity(0.18)
        }
    }

    @ViewBuilder
    private var clipLeadingVisual: some View {
        switch clip.type {
        case .audio:
            Image(systemName: "waveform")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        case .video:
            Image(systemName: "film")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        case .overlay:
            Image(systemName: "square.on.square")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        case .text:
            Image(systemName: "textformat")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        case .effect:
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private func clipColor(_ type: TrackType) -> Color {
        switch type {
        case .video: return Color.blue.opacity(0.6)
        case .audio: return Color.green.opacity(0.6)
        case .text: return Color.orange.opacity(0.6)
        case .overlay: return Color.purple.opacity(0.6)
        case .effect: return Color.pink.opacity(0.6)
        }
    }

    private var clipHeight: CGFloat {
        clip.type == .video && expandsVideoAudio && showsEmbeddedAudio ? 56 : 36
    }

    private var overlayTopPadding: CGFloat {
        clip.type == .video && expandsVideoAudio && showsEmbeddedAudio ? 2 : 0
    }
}

struct TimelineClipThumbnailStrip: View {
    let sourcePath: String
    let durationSeconds: Double

    @State private var images: [UIImage] = []

    var body: some View {
        GeometryReader { geometry in
            let thumbnailCount = max(Int(geometry.size.width / 44), 1)

            ZStack {
                if images.isEmpty {
                    Color.white.opacity(0.12)
                    Image(systemName: "film")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    HStack(spacing: 0) {
                        ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: max(geometry.size.width / CGFloat(images.count), 1),
                                    height: geometry.size.height
                                )
                                .clipped()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipped()
            .task(id: "\(sourcePath)-\(thumbnailCount)-\(durationSeconds)") {
                await loadImages(thumbnailCount: thumbnailCount)
            }
        }
    }

    @MainActor
    private func loadImages(thumbnailCount: Int) async {
        if let posterFrame = await TimelineClipVisualCache.thumbnail(for: sourcePath) {
            images = [posterFrame]
        } else {
            images = []
        }

        let strip = await TimelineClipVisualCache.thumbnailStrip(
            for: sourcePath,
            durationSeconds: durationSeconds,
            frameCount: thumbnailCount
        )

        if !strip.isEmpty {
            images = strip
        }
    }
}

struct AudioWaveformStrip: View {
    let sourcePath: String

    @State private var samples: [CGFloat] = []

    var body: some View {
        GeometryReader { geometry in
            let visibleSamples = samples.isEmpty
                ? Array(repeating: CGFloat(0.35), count: 24)
                : samples

            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(visibleSamples.enumerated()), id: \.offset) { _, sample in
                    Capsule()
                        .fill(Color.white.opacity(0.88))
                        .frame(
                            width: max((geometry.size.width / CGFloat(visibleSamples.count)) - 2, 2),
                            height: max(4, geometry.size.height * sample)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .task(id: sourcePath) {
            samples = await TimelineClipVisualCache.waveform(for: sourcePath)
        }
    }
}

private enum TimelineClipVisualCache {
    private static let thumbnailCache = NSCache<NSString, UIImage>()
    private static let thumbnailStripCache = NSCache<NSString, NSArray>()
    private static let waveformCache = NSCache<NSString, NSArray>()
    private static let audioPresenceCache = NSCache<NSString, NSNumber>()

    static func thumbnail(for sourcePath: String) async -> UIImage? {
        guard !sourcePath.isEmpty else { return nil }

        if let cached = thumbnailCache.object(forKey: sourcePath as NSString) {
            return cached
        }

        return await Task<UIImage?, Never>.detached(priority: .utility) {
            let url = URL(fileURLWithPath: sourcePath)
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                return nil
            }

            let image = UIImage(cgImage: cgImage)
            thumbnailCache.setObject(image, forKey: sourcePath as NSString)
            return image
        }.value
    }

    static func thumbnailStrip(
        for sourcePath: String,
        durationSeconds: Double,
        frameCount: Int
    ) async -> [UIImage] {
        guard !sourcePath.isEmpty else { return [] }

        let sanitizedFrameCount = max(frameCount, 1)
        let cacheKey = "\(sourcePath)#\(Int(durationSeconds * 100))#\(sanitizedFrameCount)" as NSString

        if let cached = thumbnailStripCache.object(forKey: cacheKey) as? [UIImage] {
            return cached
        }

        return await Task<[UIImage], Never>.detached(priority: .utility) {
            let url = URL(fileURLWithPath: sourcePath)
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)

            let assetDuration = max(durationSeconds, 0.1)
            let times = (0..<sanitizedFrameCount).map { index -> CMTime in
                let progress = sanitizedFrameCount == 1
                    ? 0.0
                    : Double(index) / Double(sanitizedFrameCount - 1)
                let second = min(assetDuration * progress, max(assetDuration - 0.01, 0))
                return CMTime(seconds: second, preferredTimescale: 600)
            }

            var generatedImages: [UIImage] = []
            for time in times {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    generatedImages.append(UIImage(cgImage: cgImage))
                }
            }

            if generatedImages.isEmpty, let fallback = thumbnailCache.object(forKey: sourcePath as NSString) {
                generatedImages = [fallback]
            } else if generatedImages.isEmpty,
                      let fallback = await thumbnail(for: sourcePath) {
                generatedImages = [fallback]
            }

            thumbnailStripCache.setObject(generatedImages as NSArray, forKey: cacheKey)
            return generatedImages
        }.value
    }

    static func waveform(for sourcePath: String) async -> [CGFloat] {
        guard !sourcePath.isEmpty else { return [] }

        if let cached = waveformCache.object(forKey: sourcePath as NSString) as? [NSNumber] {
            return cached.map { CGFloat(truncating: $0) }
        }

        return await Task<[CGFloat], Never>.detached(priority: .utility) {
            let values = generateWaveformSamples(sourcePath: sourcePath)
            waveformCache.setObject(values.map(NSNumber.init(value:)) as NSArray, forKey: sourcePath as NSString)
            return values.map { CGFloat($0) }
        }.value
    }

    static func hasAudioTrack(for sourcePath: String) async -> Bool {
        guard !sourcePath.isEmpty else { return false }

        if let cached = audioPresenceCache.object(forKey: sourcePath as NSString) {
            return cached.boolValue
        }

        return await Task<Bool, Never>.detached(priority: .utility) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
            let hasAudio = !asset.tracks(withMediaType: .audio).isEmpty
            audioPresenceCache.setObject(NSNumber(value: hasAudio), forKey: sourcePath as NSString)
            return hasAudio
        }.value
    }

    private static func generateWaveformSamples(sourcePath: String) -> [Double] {
        let url = URL(fileURLWithPath: sourcePath)
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else {
            return []
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false

        guard reader.canAdd(output) else {
            return []
        }

        reader.add(output)
        guard reader.startReading() else {
            return []
        }

        var amplitudes: [Double] = []
        let targetBarCount = 28
        let sampleStride = 1024

        while let sampleBuffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(repeating: 0, count: length)

            data.withUnsafeMutableBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: baseAddress)
            }

            data.withUnsafeBytes { bytes in
                guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else { return }
                let count = length / MemoryLayout<Int16>.size
                guard count > 0 else { return }

                var index = 0
                while index < count {
                    let end = min(index + sampleStride, count)
                    var peak = 0.0

                    for sampleIndex in index..<end {
                        let value = Double(abs(Int(samples[sampleIndex])))
                        peak = max(peak, value / Double(Int16.max))
                    }

                    amplitudes.append(peak)
                    index = end
                }
            }

            CMSampleBufferInvalidate(sampleBuffer)
        }

        guard !amplitudes.isEmpty else { return [] }

        let bucketSize = max(amplitudes.count / targetBarCount, 1)
        var buckets: [Double] = []
        var bucketIndex = 0

        while bucketIndex < amplitudes.count {
            let end = min(bucketIndex + bucketSize, amplitudes.count)
            let bucket = amplitudes[bucketIndex..<end]
            let average = bucket.reduce(0, +) / Double(bucket.count)
            buckets.append(max(0.16, min(average * 1.6, 1.0)))
            bucketIndex = end
        }

        if buckets.count > targetBarCount {
            return Array(buckets.prefix(targetBarCount))
        }

        if buckets.count < targetBarCount {
            return buckets + Array(repeating: 0.16, count: targetBarCount - buckets.count)
        }

        return buckets
    }
}

extension Array where Element == TrackDisplayModel {
    func timelineContentWidth(zoomScale: CGFloat) -> CGFloat {
        let clipEnd = flatMap(\.clips).map { $0.startSeconds + $0.durationSeconds }.max() ?? 30
        return Swift.max(CGFloat(clipEnd) * 60 * zoomScale, 100)
    }
}

extension ClipDisplayModel {
    func startOffset(zoomScale: CGFloat) -> CGFloat {
        CGFloat(startSeconds) * 60 * zoomScale
    }

    func width(zoomScale: CGFloat) -> CGFloat {
        max(CGFloat(durationSeconds) * 60 * zoomScale, 40)
    }
}

#Preview {
    TimelineEditorScreen(
        project: WorkspaceProject(
            id: UUID(),
            name: "Project 001",
            mediaUrl: URL(fileURLWithPath: "/tmp/sample.mov"),
            createdAt: Date(),
            mediaKind: .video,
            projectNumber: 1,
            aspectRatio: .ratio16x9,
            resolution: .p1080,
            frameRate: .fps24,
            bitrate: .mbps5
        )
    )
}
