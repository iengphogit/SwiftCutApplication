import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct TimelineEditorScreen: View {
    let project: WorkspaceProject
    var onBack: () -> Void = {}
    var onUpdateAspectRatio: (AspectRatio) -> Void = { _ in }
    var onUpdateUhdSettings: (UhdResolution, UhdFrameRate, UhdBitrate) -> Void = { _, _, _ in }

    @StateObject private var viewModel = TimelineEditorViewModel()
    @State private var selectedClipId: UUID?
    @State private var showMediaPicker = false
    @State private var mediaPickerTarget: MediaPickerTarget = .video
    @State private var zoomScale: CGFloat = 1.0
    @State private var isRatioPanelVisible = false
    @State private var isUhdPanelVisible = false
    @State private var selectedRatio: AspectRatio
    @State private var selectedResolution: UhdResolution
    @State private var selectedFrameRate: UhdFrameRate
    @State private var selectedBitrate: UhdBitrate

    init(
        project: WorkspaceProject,
        onBack: @escaping () -> Void = {},
        onUpdateAspectRatio: @escaping (AspectRatio) -> Void = { _ in },
        onUpdateUhdSettings: @escaping (UhdResolution, UhdFrameRate, UhdBitrate) -> Void = { _, _, _ in }
    ) {
        self.project = project
        self.onBack = onBack
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
                
                if let player = viewModel.previewPlayer {
                    NativeEnginePreviewHost(
                        player: player,
                        compositionFrame: viewModel.compositionFrame
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
            let leftChannelWidth = geometry.size.width / 2
            let rightLanePadding: CGFloat = 10
            let leadingTimelineInset: CGFloat = 0
            let timelineWidth = max(
                viewModel.tracks.timelineContentWidth(zoomScale: zoomScale) + leadingTimelineInset,
                geometry.size.width - leftChannelWidth
            )

            VStack(spacing: 0) {
                timelineHeader
                ZStack(alignment: .topLeading) {
                    TimelineHorizontalScrollView(
                        currentTime: max(viewModel.currentTime.seconds, 0),
                        pointsPerSecond: 60 * zoomScale,
                        onTimeChange: { seconds in
                            viewModel.seek(
                                to: CMTime(seconds: seconds, preferredTimescale: 600)
                            )
                        }
                    ) {
                        VStack(spacing: 0) {
                            timelineRuler(
                                timelineWidth: timelineWidth,
                                leftChannelWidth: leftChannelWidth,
                                leadingTimelineInset: leadingTimelineInset,
                                rightLanePadding: rightLanePadding
                            )
                            tracksView(
                                timelineWidth: timelineWidth,
                                leftChannelWidth: leftChannelWidth,
                                leadingTimelineInset: leadingTimelineInset,
                                rightLanePadding: rightLanePadding
                            )
                        }
                    }
                    centeredPlayhead()
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
                Button(action: { zoomScale = max(0.5, zoomScale - 0.25) }) {
                    Image(systemName: "minus")
                        .foregroundColor(.gray)
                }
                
                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 40)
                
                Button(action: { zoomScale = min(3.0, zoomScale + 0.25) }) {
                    Image(systemName: "plus")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func timelineRuler(
        timelineWidth: CGFloat,
        leftChannelWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .frame(width: leftChannelWidth, height: 24)
                .overlay(
                    Text("Tracks")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                )

            HStack(spacing: 0) {
                Color.clear
                    .frame(width: leadingTimelineInset)

                ForEach(0..<Int(max(viewModel.duration.seconds + 5, 30)), id: \.self) { second in
                    VStack(alignment: .leading, spacing: 2) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 1, height: second % 5 == 0 ? 12 : 6)

                        if second % 5 == 0 {
                            Text(formatSecond(second))
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 60 * zoomScale)
                }
            }
            .padding(.leading, rightLanePadding)
            .frame(width: timelineWidth, alignment: .leading)
        }
        .frame(height: 24)
    }
    
    private func tracksView(
        timelineWidth: CGFloat,
        leftChannelWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tracks) { track in
                    TrackRowView(
                        track: track,
                        timelineWidth: timelineWidth,
                        leftChannelWidth: leftChannelWidth,
                        leadingTimelineInset: leadingTimelineInset,
                        rightLanePadding: rightLanePadding,
                        zoomScale: zoomScale,
                        selectedClipId: $selectedClipId,
                        onToggleMute: {
                            viewModel.setTrackMuted(track.id, muted: !track.isMuted)
                        },
                        onToggleLock: {
                            viewModel.setTrackLocked(track.id, locked: !track.isLocked)
                        },
                        onRemoveTrack: {
                            viewModel.removeTrack(track.id)
                        },
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

    private func centeredPlayhead() -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 26, height: geometry.size.height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.18), lineWidth: 1)
                    )

                Capsule()
                    .fill(Color.red)
                    .frame(width: 22, height: 10)
                    .shadow(color: .red.opacity(0.55), radius: 5)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red,
                                Color.red.opacity(0.95),
                                Color.red.opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.95))
                            .frame(width: 1.5)
                    )
                    .shadow(color: .red.opacity(0.45), radius: 4)
            }
            .frame(height: geometry.size.height, alignment: .top)
            .position(
                x: geometry.size.width / 2,
                y: geometry.size.height / 2
            )
        }
        .allowsHitTesting(false)
        .zIndex(10)
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

private struct NativeEnginePreviewHost: UIViewRepresentable {
    let player: AVPlayer
    let compositionFrame: CompositionFrame?

    func makeUIView(context: Context) -> SCNativePreviewView {
        let view = SCNativePreviewView()
        view.setPreviewPlayer(player)
        update(view)
        return view
    }

    func updateUIView(_ uiView: SCNativePreviewView, context: Context) {
        uiView.setPreviewPlayer(player)
        update(uiView)
    }

    private func update(_ view: SCNativePreviewView) {
        view.updateCompositionVisualClipCount(
            compositionFrame?.visualClips.count ?? 0,
            audioClipCount: compositionFrame?.audioClips.count ?? 0,
            activeVisualSummary: activeVisualSummary
        )
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
}

private struct TimelineHorizontalScrollView<Content: View>: UIViewRepresentable {
    let currentTime: Double
    let pointsPerSecond: CGFloat
    let onTimeChange: (Double) -> Void
    let content: Content

    init(
        currentTime: Double,
        pointsPerSecond: CGFloat,
        onTimeChange: @escaping (Double) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentTime = currentTime
        self.pointsPerSecond = pointsPerSecond
        self.onTimeChange = onTimeChange
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hostingController: UIHostingController(rootView: content),
            pointsPerSecond: pointsPerSecond,
            onTimeChange: onTimeChange
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
        context.coordinator.pointsPerSecond = pointsPerSecond
        context.coordinator.onTimeChange = onTimeChange

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

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let hostingController: UIHostingController<Content>
        var pointsPerSecond: CGFloat
        var onTimeChange: (Double) -> Void
        var isProgrammaticScroll = false
        var isUserInteracting = false

        init(
            hostingController: UIHostingController<Content>,
            pointsPerSecond: CGFloat,
            onTimeChange: @escaping (Double) -> Void
        ) {
            self.hostingController = hostingController
            self.pointsPerSecond = pointsPerSecond
            self.onTimeChange = onTimeChange
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll else { return }

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
    }
}

private struct RatioGlassPanel: View {
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

private struct UhdGlassPanel: View {
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

private struct HeaderGlassButton: View {
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

private extension AspectRatio {
    var iconSize: CGSize {
        switch self {
        case .ratio16x9:
            return CGSize(width: 18, height: 10)
        case .ratio9x16:
            return CGSize(width: 10, height: 18)
        case .ratio1x1:
            return CGSize(width: 14, height: 14)
        }
    }
}

private struct TimelineToolButton: View {
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

private struct TimelineBottomToolButton: View {
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

private struct TrackRowView: View {
    let track: TrackDisplayModel
    let timelineWidth: CGFloat
    let leftChannelWidth: CGFloat
    let leadingTimelineInset: CGFloat
    let rightLanePadding: CGFloat
    let zoomScale: CGFloat
    @Binding var selectedClipId: UUID?
    let onToggleMute: () -> Void
    let onToggleLock: () -> Void
    let onRemoveTrack: () -> Void
    let onClipTap: (UUID) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            trackIcon
                .frame(width: leftChannelWidth)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )

                ForEach(track.clips) { clip in
                    ClipView(
                        clip: clip,
                        zoomScale: zoomScale,
                        isSelected: selectedClipId == clip.id
                    )
                    .offset(x: leadingTimelineInset + clip.startOffset(zoomScale: zoomScale))
                    .onTapGesture {
                        onClipTap(clip.id)
                    }
                }
            }
            .padding(.leading, rightLanePadding)
            .frame(width: timelineWidth, height: 44, alignment: .leading)
        }
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.11))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var trackIcon: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
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
            .frame(minWidth: 34, alignment: .trailing)

            HStack(spacing: 6) {
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
        .frame(width: max(leftChannelWidth - 10, 0), alignment: .trailing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        .padding(.leading, 10)
        .padding(.trailing, 0)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(trackColor(track.type).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(trackColor(track.type).opacity(0.32), lineWidth: 1)
        )
    }

    private func channelButton(systemName: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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
}

private struct ClipView: View {
    let clip: ClipDisplayModel
    let zoomScale: CGFloat
    let isSelected: Bool
    
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
        }
        .frame(width: clip.width(zoomScale: zoomScale), height: 36)
        .background(clipColor(clip.type))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
    }

    @ViewBuilder
    private var clipBackground: some View {
        switch clip.type {
        case .audio:
            AudioWaveformStrip(sourcePath: clip.sourcePath)
                .padding(.horizontal, 6)
                .padding(.vertical, 7)
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
}

private struct TimelineClipThumbnailStrip: View {
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
                images = await TimelineClipVisualCache.thumbnailStrip(
                    for: sourcePath,
                    durationSeconds: durationSeconds,
                    frameCount: thumbnailCount
                )
            }
        }
    }
}

private struct AudioWaveformStrip: View {
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

private extension Array where Element == TrackDisplayModel {
    func timelineContentWidth(zoomScale: CGFloat) -> CGFloat {
        let clipEnd = flatMap(\.clips).map { $0.startSeconds + $0.durationSeconds }.max() ?? 30
        return Swift.max(CGFloat(clipEnd) * 60 * zoomScale, 100)
    }
}

private extension ClipDisplayModel {
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
