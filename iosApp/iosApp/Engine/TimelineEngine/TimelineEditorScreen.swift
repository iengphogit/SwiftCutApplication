import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct TimelineEditorScreen: View {
    let project: WorkspaceProject
    var onBack: () -> Void = {}
    var onProjectReady: () -> Void = {}
    var onUpdateAspectRatio: (AspectRatio) -> Void = { _ in }
    var onUpdateUhdSettings: (UhdResolution, UhdFrameRate, UhdBitrate) -> Void = { _, _, _ in }

    @StateObject private var viewModel = TimelineEditorViewModel()
    @State private var selectedClipId: UUID?
    @State private var showMediaPicker = false
    @State private var mediaPickerTarget: MediaPickerTarget = .video
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomAnchorRequest: TimelineZoomAnchorRequest?
    @State private var isRatioPanelVisible = false
    @State private var isUhdPanelVisible = false
    @State private var selectedRatio: AspectRatio
    @State private var selectedResolution: UhdResolution
    @State private var selectedFrameRate: UhdFrameRate
    @State private var selectedBitrate: UhdBitrate

    init(
        project: WorkspaceProject,
        onBack: @escaping () -> Void = {},
        onProjectReady: @escaping () -> Void = {},
        onUpdateAspectRatio: @escaping (AspectRatio) -> Void = { _ in },
        onUpdateUhdSettings: @escaping (UhdResolution, UhdFrameRate, UhdBitrate) -> Void = { _, _, _ in }
    ) {
        self.project = project
        self.onBack = onBack
        self.onProjectReady = onProjectReady
        self.onUpdateAspectRatio = onUpdateAspectRatio
        self.onUpdateUhdSettings = onUpdateUhdSettings
        _selectedRatio = State(initialValue: project.aspectRatio)
        _selectedResolution = State(initialValue: project.resolution)
        _selectedFrameRate = State(initialValue: project.frameRate)
        _selectedBitrate = State(initialValue: project.bitrate)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    topTitleSection
                    headerSection
                    previewSection(geometry: geometry)
                    toolsSection
                    timelineSection
                    bottomToolsSection
                }
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(target: mediaPickerTarget) { url, kind in
                viewModel.importMedia(
                    url: url,
                    kind: kind,
                    destination: importDestination(for: mediaPickerTarget)
                )
            }
        }
        .task(id: project.id) {
            viewModel.loadProjectIfNeeded(project)
        }
        .onChange(of: viewModel.isProjectLoading) { _, isLoading in
            if !isLoading {
                onProjectReady()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topTitleSection: some View {
        Text(project.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 10)
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
            
            Spacer()

            HStack(spacing: 10) {
                Button(action: { isRatioPanelVisible = true }) {
                    HeaderGlassButton(
                        title: selectedRatio.displayName,
                        ratioIconSize: selectedRatio.iconSize
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isRatioPanelVisible, arrowEdge: .top) {
                    RatioGlassPanel(
                        selectedRatio: selectedRatio,
                        onSelect: { ratio in
                            selectedRatio = ratio
                            isRatioPanelVisible = false
                            onUpdateAspectRatio(ratio)
                        }
                    )
                    .presentationCompactAdaptation(.popover)
                }

                Button(action: { isUhdPanelVisible = true }) {
                    HeaderGlassButton(title: selectedResolution.displayName)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isUhdPanelVisible, arrowEdge: .top) {
                    UhdGlassPanel(
                        onSelectResolution: { resolution in
                            selectedResolution = resolution
                            onUpdateUhdSettings(resolution, selectedFrameRate, selectedBitrate)
                        },
                        onSelectFrameRate: { frameRate in
                            selectedFrameRate = frameRate
                            onUpdateUhdSettings(selectedResolution, frameRate, selectedBitrate)
                        },
                        onSelectBitrate: { bitrate in
                            selectedBitrate = bitrate
                            onUpdateUhdSettings(selectedResolution, selectedFrameRate, bitrate)
                        },
                        onApply: { isUhdPanelVisible = false },
                        selectedResolution: selectedResolution,
                        selectedFrameRate: selectedFrameRate,
                        selectedBitrate: selectedBitrate
                    )
                    .presentationCompactAdaptation(.popover)
                }
            }

            Button(action: { viewModel.exportVideo() }) {
                Text("Export")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
    }
    
    private func previewSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color.black

                if viewModel.compositionFrame != nil || viewModel.duration.seconds > 0 {
                    NativeEnginePreviewHost(
                        compositionFrame: viewModel.compositionFrame,
                        durationSeconds: max(viewModel.duration.seconds, 0),
                        desiredIsPlaying: viewModel.isPlaying,
                        seekCommand: viewModel.previewSeekCommand,
                        onDisplayTimeChange: { seconds in
                            viewModel.syncPreviewDisplayTime(seconds)
                        },
                        onPlaybackStateChange: { playing in
                            viewModel.syncPreviewPlaybackState(playing)
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Tap Add to import video")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: geometry.size.height * 0.29)
            .clipped()

            HStack(spacing: 14) {
                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.canUndo ? .white : .gray)
                        .frame(width: 38, height: 38)
                        .background(Color(white: 0.18))
                        .clipShape(Circle())
                }
                .disabled(!viewModel.canUndo)

                Button(action: { viewModel.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(viewModel.canRedo ? .white : .gray)
                        .frame(width: 38, height: 38)
                        .background(Color(white: 0.18))
                        .clipShape(Circle())
                }
                .disabled(!viewModel.canRedo)

                Spacer()

                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.94))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(white: 0.08))
        }
        .background(Color.black)
    }
    
    private var toolsSection: some View {
        HStack(spacing: 24) {
            TimelineToolButton(icon: "scissors", title: "Split") {
                viewModel.splitAtPlayhead()
            }
            .disabled(!viewModel.canSplit)
            
            TimelineToolButton(icon: "speedometer", title: "Speed") {
                
            }
            
            TimelineToolButton(icon: "speaker.wave.2", title: "Volume") {
                
            }
            
            TimelineToolButton(icon: "crop", title: "Crop") {
                
            }
            
            TimelineToolButton(icon: "trash", title: "Delete") {
                if let clipId = selectedClipId {
                    viewModel.deleteClip(clipId)
                    selectedClipId = nil
                }
            }
            .disabled(selectedClipId == nil)

            TimelineToolButton(icon: "arrow.left.arrow.right", title: "Ripple") {
                if let clipId = selectedClipId {
                    viewModel.deleteClip(clipId, ripple: true)
                    selectedClipId = nil
                }
            }
            .disabled(selectedClipId == nil)
        }
        .padding(.vertical, 16)
        .background(Color(white: 0.1))
    }
    
    private var timelineSection: some View {
        GeometryReader { geometry in
            let leftChannelWidth = min(max(162, geometry.size.width * 0.36), 192)
            let rightLanePadding: CGFloat = 10
            let rightLaneWidth = geometry.size.width - leftChannelWidth
            let playheadXInRightLane = max((geometry.size.width / 2) - leftChannelWidth, 0)
            let leadingTimelineInset = max(playheadXInRightLane - rightLanePadding, 0)
            let timelineWidth = max(
                viewModel.tracks.timelineContentWidth(zoomScale: zoomScale) + leadingTimelineInset,
                rightLaneWidth
            )

            VStack(spacing: 0) {
                timelineHeader
                HStack(spacing: 0) {
                    leftTimelineColumn(leftChannelWidth: leftChannelWidth)

                    ZStack(alignment: .topLeading) {
                    TimelineHorizontalScrollView(
                        currentTime: max(viewModel.currentTime.seconds, 0),
                        zoomScale: zoomScale,
                        pointsPerSecond: 60 * zoomScale,
                        timelineZeroInset: leadingTimelineInset + rightLanePadding,
                        zoomAnchorRequest: zoomAnchorRequest,
                        onTimeChange: { seconds in
                            viewModel.seek(
                                to: CMTime(seconds: seconds, preferredTimescale: 600)
                            )
                        },
                        onZoomChange: { updatedZoomScale in
                            zoomScale = updatedZoomScale
                        },
                        onZoomAnchorConsumed: {
                            zoomAnchorRequest = nil
                        }
                    ) {
                            VStack(spacing: 0) {
                                timelineRuler(
                                    timelineWidth: timelineWidth,
                                    leadingTimelineInset: leadingTimelineInset,
                                    rightLanePadding: rightLanePadding
                                )
                                tracksView(
                                    timelineWidth: timelineWidth,
                                    leadingTimelineInset: leadingTimelineInset,
                                    rightLanePadding: rightLanePadding
                                )
                            }
                        }
                        centeredPlayhead(xInLane: playheadXInRightLane)
                    }
                    .frame(width: rightLaneWidth)
                }
            }
            .background(Color(white: 0.05))
        }
        .frame(height: 272)
    }
    
    private var timelineHeader: some View {
        HStack {
            Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.86))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { updateZoomScale(max(0.5, zoomScale - 0.25)) }) {
                    Image(systemName: "minus")
                        .foregroundColor(.gray)
                }
                
                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 40)
                
                Button(action: { updateZoomScale(min(3.0, zoomScale + 0.25)) }) {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func leftTimelineColumn(leftChannelWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: leftChannelWidth, height: 24)
                .overlay(
                    Text("Tracks")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                )

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.tracks) { track in
                        TrackHeaderView(
                            track: track,
                            leftChannelWidth: leftChannelWidth,
                            onToggleMute: {
                                viewModel.setTrackMuted(track.id, muted: !track.isMuted)
                            },
                            onToggleLock: {
                                viewModel.setTrackLocked(track.id, locked: !track.isLocked)
                            },
                            onRemoveTrack: {
                                viewModel.removeTrack(track.id)
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 200)
        }
    }

    private func timelineRuler(
        timelineWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        let ruler = rulerConfiguration(for: zoomScale)
        let visibleDuration = max(viewModel.duration.seconds + ruler.majorInterval * 2, 30)
        let tickCount = Int(ceil(visibleDuration / ruler.minorInterval)) + 1

        return HStack(spacing: 0) {
            Color.clear
                .frame(width: leadingTimelineInset)

            ZStack(alignment: .topLeading) {
                ForEach(0..<tickCount, id: \.self) { index in
                    let tickTime = Double(index) * ruler.minorInterval
                    let isMajorTick = isRulerTick(tickTime, interval: ruler.majorInterval)
                    let isMediumTick = !isMajorTick && isRulerTick(
                        tickTime,
                        interval: ruler.mediumInterval
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 1, height: isMajorTick ? 12 : (isMediumTick ? 9 : 6))

                        if isMajorTick {
                            Text(formatTimelineLabel(tickTime, step: ruler.majorInterval))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .offset(x: CGFloat(tickTime) * 60 * zoomScale)
                }
            }
            .frame(width: max(timelineWidth - leadingTimelineInset - rightLanePadding, 0), alignment: .leading)
        }
        .padding(.leading, rightLanePadding)
        .frame(width: timelineWidth, height: 24, alignment: .leading)
        .frame(height: 24)
    }
    
    private func tracksView(
        timelineWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tracks) { track in
                    TrackLaneView(
                        track: track,
                        timelineWidth: timelineWidth,
                        leadingTimelineInset: leadingTimelineInset,
                        rightLanePadding: rightLanePadding,
                        zoomScale: zoomScale,
                        selectedClipId: $selectedClipId,
                        onClipTap: { clipId in
                            selectedClipId = selectedClipId == clipId ? nil : clipId
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 200)
    }
    
    private var bottomToolsSection: some View {
        HStack(spacing: 0) {
            TimelineBottomToolButton(icon: "plus", title: "Add") {
                mediaPickerTarget = .video
                showMediaPicker = true
            }
            
            TimelineBottomToolButton(icon: "textformat", title: "Text") {
            }
            .disabled(true)
            
            TimelineBottomToolButton(icon: "music.note", title: "Audio") {
                mediaPickerTarget = .audio
                showMediaPicker = true
            }
            
            TimelineBottomToolButton(icon: "photo", title: "Overlay") {
                mediaPickerTarget = .overlay
                showMediaPicker = true
            }
            
            TimelineBottomToolButton(icon: "sparkles", title: "Effects") {
                
            }
        }
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }
    
    private func formatSecond(_ second: Int) -> String {
        let mins = second / 60
        let secs = second % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatTimelineLabel(_ seconds: Double, step: Double) -> String {
        let totalWholeSeconds = Int(seconds)
        let mins = totalWholeSeconds / 60
        let secs = totalWholeSeconds % 60

        guard step < 1 else {
            return String(format: "%d:%02d", mins, secs)
        }

        let fractional = Int(round((seconds - floor(seconds)) * 10))
        if fractional == 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        return String(format: "%d:%02d.%d", mins, secs, fractional)
    }

    private func rulerConfiguration(for zoomScale: CGFloat) -> (
        majorInterval: Double,
        mediumInterval: Double,
        minorInterval: Double
    ) {
        switch zoomScale {
        case 2.5...:
            return (0.5, 0.25, 0.1)
        case 1.75..<2.5:
            return (1, 0.5, 0.25)
        case 1.1..<1.75:
            return (2, 1, 0.5)
        case 0.8..<1.1:
            return (5, 2.5, 1)
        default:
            return (10, 5, 2)
        }
    }

    private func isRulerTick(_ time: Double, interval: Double) -> Bool {
        guard interval > 0 else { return false }
        let quotient = time / interval
        return abs(quotient.rounded() - quotient) < 0.0001
    }

    private func centeredPlayhead(xInLane: CGFloat) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.white.opacity(0.96))
                .frame(width: 2, height: geometry.size.height)
                .shadow(color: .white.opacity(0.18), radius: 1)
            .position(
                x: min(max(xInLane, 0), geometry.size.width),
                y: geometry.size.height / 2
            )
        }
        .allowsHitTesting(false)
        .zIndex(10)
    }

    private func updateZoomScale(_ newZoomScale: CGFloat) {
        guard abs(newZoomScale - zoomScale) > 0.001 else { return }
        zoomAnchorRequest = TimelineZoomAnchorRequest(
            anchorTime: max(viewModel.currentTime.seconds, 0),
            locationX: nil
        )
        zoomScale = newZoomScale
    }

    private func importDestination(for target: MediaPickerTarget) -> TimelineEditorViewModel.ImportDestination {
        switch target {
        case .video:
            return .video
        case .audio:
            return .audio
        case .overlay:
            return .overlay
        }
    }
}

private struct TimelineZoomAnchorRequest: Equatable {
    let id = UUID()
    let anchorTime: Double
    let locationX: CGFloat?
}

struct PreviewSeekCommand: Equatable {
    let id = UUID()
    let timeSeconds: Double
}

private struct NativeEnginePreviewHost: UIViewRepresentable {
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
        view.onDisplayTimeChange = onDisplayTimeChange
        view.onPlaybackStateChange = onPlaybackStateChange
        view.setPreviewDurationSeconds(durationSeconds)
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
        view.updateCompositionVisualClipCount(
            compositionFrame?.visualClips.count ?? 0,
            audioClipCount: compositionFrame?.audioClips.count ?? 0,
            activeVisualSummary: activeVisualSummary
        )
        view.updateActiveTextOverlays(activeTextOverlays)
        view.updateActiveVisualOverlays(activeVisualOverlays)
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

    final class Coordinator {
        var lastAppliedPlaybackState: Bool?
        var lastAppliedSeekCommandId: UUID?
    }
}

private struct TimelineHorizontalScrollView<Content: View>: UIViewRepresentable {
    let currentTime: Double
    let zoomScale: CGFloat
    let pointsPerSecond: CGFloat
    let timelineZeroInset: CGFloat
    let zoomAnchorRequest: TimelineZoomAnchorRequest?
    let onTimeChange: (Double) -> Void
    let onZoomChange: (CGFloat) -> Void
    let onZoomAnchorConsumed: () -> Void
    let content: Content

    init(
        currentTime: Double,
        zoomScale: CGFloat,
        pointsPerSecond: CGFloat,
        timelineZeroInset: CGFloat,
        zoomAnchorRequest: TimelineZoomAnchorRequest?,
        onTimeChange: @escaping (Double) -> Void,
        onZoomChange: @escaping (CGFloat) -> Void,
        onZoomAnchorConsumed: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentTime = currentTime
        self.zoomScale = zoomScale
        self.pointsPerSecond = pointsPerSecond
        self.timelineZeroInset = timelineZeroInset
        self.zoomAnchorRequest = zoomAnchorRequest
        self.onTimeChange = onTimeChange
        self.onZoomChange = onZoomChange
        self.onZoomAnchorConsumed = onZoomAnchorConsumed
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hostingController: UIHostingController(rootView: content),
            zoomScale: zoomScale,
            pointsPerSecond: pointsPerSecond,
            timelineZeroInset: timelineZeroInset,
            onTimeChange: onTimeChange,
            onZoomChange: onZoomChange,
            onZoomAnchorConsumed: onZoomAnchorConsumed
        )
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.bounces = true
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .clear

        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        pinchGesture.delegate = context.coordinator
        scrollView.addGestureRecognizer(pinchGesture)

        let hostedView = context.coordinator.hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        context.coordinator.zoomScale = zoomScale
        context.coordinator.pointsPerSecond = pointsPerSecond
        context.coordinator.timelineZeroInset = timelineZeroInset
        context.coordinator.onTimeChange = onTimeChange
        context.coordinator.onZoomChange = onZoomChange
        context.coordinator.onZoomAnchorConsumed = onZoomAnchorConsumed

        if let zoomAnchorRequest,
           context.coordinator.lastHandledZoomAnchorId != zoomAnchorRequest.id {
            context.coordinator.pendingZoomAnchor = (
                time: zoomAnchorRequest.anchorTime,
                locationX: zoomAnchorRequest.locationX ?? timelineZeroInset
            )
            context.coordinator.lastHandledZoomAnchorId = zoomAnchorRequest.id
        }

        if let pendingAnchor = context.coordinator.pendingZoomAnchor {
            let anchoredOffsetX = max(
                CGFloat(pendingAnchor.time) * pointsPerSecond + timelineZeroInset - pendingAnchor.locationX,
                0
            )
            context.coordinator.isProgrammaticScroll = true
            uiView.setContentOffset(CGPoint(x: anchoredOffsetX, y: uiView.contentOffset.y), animated: false)
            context.coordinator.isProgrammaticScroll = false
            context.coordinator.pendingZoomAnchor = nil
            context.coordinator.lastCommittedZoomScale = zoomScale
            let anchoredSeconds = max(Double(anchoredOffsetX / max(pointsPerSecond, 1)), 0)
            DispatchQueue.main.async {
                onTimeChange(anchoredSeconds)
                onZoomAnchorConsumed()
            }
            return
        }

        let targetOffsetX = max(CGFloat(currentTime) * pointsPerSecond, 0)
        guard !context.coordinator.isUserInteracting,
              abs(uiView.contentOffset.x - targetOffsetX) > 1
        else {
            return
        }

        context.coordinator.isProgrammaticScroll = true
        uiView.setContentOffset(CGPoint(x: targetOffsetX, y: uiView.contentOffset.y), animated: false)
        context.coordinator.isProgrammaticScroll = false
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let hostingController: UIHostingController<Content>
        var zoomScale: CGFloat
        var pointsPerSecond: CGFloat
        var timelineZeroInset: CGFloat
        var onTimeChange: (Double) -> Void
        var onZoomChange: (CGFloat) -> Void
        var onZoomAnchorConsumed: () -> Void
        var isProgrammaticScroll = false
        var isUserInteracting = false
        var isPinchZooming = false
        var pinchStartZoomScale: CGFloat = 1
        var lastCommittedZoomScale: CGFloat
        var lastHandledZoomAnchorId: UUID?
        var pendingZoomAnchor: (time: Double, locationX: CGFloat)?

        init(
            hostingController: UIHostingController<Content>,
            zoomScale: CGFloat,
            pointsPerSecond: CGFloat,
            timelineZeroInset: CGFloat,
            onTimeChange: @escaping (Double) -> Void,
            onZoomChange: @escaping (CGFloat) -> Void,
            onZoomAnchorConsumed: @escaping () -> Void
        ) {
            self.hostingController = hostingController
            self.zoomScale = zoomScale
            self.pointsPerSecond = pointsPerSecond
            self.timelineZeroInset = timelineZeroInset
            self.onTimeChange = onTimeChange
            self.onZoomChange = onZoomChange
            self.onZoomAnchorConsumed = onZoomAnchorConsumed
            self.lastCommittedZoomScale = zoomScale
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll, !isPinchZooming else { return }

            let seconds = max(scrollView.contentOffset.x / max(pointsPerSecond, 1), 0)
            onTimeChange(seconds)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserInteracting = false
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserInteracting = false
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let scrollView = recognizer.view as? UIScrollView else { return }

            switch recognizer.state {
            case .began:
                isUserInteracting = true
                isPinchZooming = true
                pinchStartZoomScale = zoomScale
                scrollView.panGestureRecognizer.isEnabled = false
            case .changed:
                let clampedZoomScale = min(max(pinchStartZoomScale * recognizer.scale, 0.5), 3.0)
                guard abs(clampedZoomScale - lastCommittedZoomScale) > 0.01 else { return }

                let locationX = recognizer.location(in: scrollView).x
                let contentX = scrollView.contentOffset.x + locationX
                let anchorTime = max(
                    Double((contentX - timelineZeroInset) / max(pointsPerSecond, 1)),
                    0
                )

                pendingZoomAnchor = (time: anchorTime, locationX: locationX)
                lastCommittedZoomScale = clampedZoomScale
                onZoomChange(clampedZoomScale)
            case .ended, .cancelled, .failed:
                isPinchZooming = false
                isUserInteracting = false
                scrollView.panGestureRecognizer.isEnabled = true
                let seconds = max(scrollView.contentOffset.x / max(pointsPerSecond, 1), 0)
                onTimeChange(seconds)
            default:
                break
            }
        }
        
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
