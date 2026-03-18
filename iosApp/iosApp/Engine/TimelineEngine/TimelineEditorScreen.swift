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
    @State private var showVideoImportOptions = false
    @State private var mediaPickerTarget: MediaPickerTarget = .video
    @State private var importVideoWithAudio = true
    @State private var zoomScale: CGFloat = 1
    @State private var zoomAnchorRequest: TimelineZoomAnchorRequest?
    @State private var showTimelineDebugLayout = false
    @State private var timelineScrollMetrics = TimelineScrollMetrics()
    @State private var requestedTimelineScrollOffsetX: CGFloat?
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
                    timelineSection
                    bottomToolStrip
                }

                if let toast = viewModel.toast {
                    VStack {
                        Spacer()
                        timelineToastView(toast)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 86)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .sheet(isPresented: $showMediaPicker) {
            MediaPickerView(target: mediaPickerTarget) { url, kind in
                viewModel.importMedia(
                    url: url,
                    kind: kind,
                    destination: importDestination(for: mediaPickerTarget),
                    extractAudioFromVideo: mediaPickerTarget == .video ? importVideoWithAudio : false
                )
            }
        }
        .confirmationDialog("Import Video", isPresented: $showVideoImportOptions) {
            Button("Video + Audio") {
                importVideoWithAudio = true
                mediaPickerTarget = .video
                showMediaPicker = true
            }
            Button("Video Only") {
                importVideoWithAudio = false
                mediaPickerTarget = .video
                showMediaPicker = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose whether to extract embedded audio into a separate audio track.")
        }
        .task(id: project.id) {
            AppLogger.log("TimelineEditorScreen task loadProjectIfNeeded \(project.name)")
            viewModel.loadProjectIfNeeded(project)
        }
        .onChange(of: viewModel.isProjectLoading) { _, isLoading in
            AppLogger.log("TimelineEditorScreen isProjectLoading=\(isLoading) for \(project.name)")
            if !isLoading {
                onProjectReady()
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("timeline-editor-screen")
        .animation(.easeInOut(duration: 0.2), value: viewModel.toast)
        .onChange(of: viewModel.toast) { _, toast in
            guard toast != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if viewModel.toast == toast {
                    viewModel.toast = nil
                }
            }
        }
    }

    private var topTitleSection: some View {
        Text(project.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .accessibilityIdentifier("timeline-editor-title")
    }
    
    private var headerSection: some View {
        return HStack(spacing: 10) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }

            Spacer(minLength: 0)

            ViewThatFits(in: .horizontal) {
                headerTrailingControls(compactExport: false)
                headerTrailingControls(compactExport: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.1))
    }

    private func headerTrailingControls(compactExport: Bool) -> some View {
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
                        viewModel.updateProjectOutputSettings(
                            aspectRatio: ratio,
                            resolution: selectedResolution,
                            frameRate: selectedFrameRate
                        )
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
                        viewModel.updateProjectOutputSettings(
                            aspectRatio: selectedRatio,
                            resolution: resolution,
                            frameRate: selectedFrameRate
                        )
                        onUpdateUhdSettings(resolution, selectedFrameRate, selectedBitrate)
                    },
                    onSelectFrameRate: { frameRate in
                        selectedFrameRate = frameRate
                        viewModel.updateProjectOutputSettings(
                            aspectRatio: selectedRatio,
                            resolution: selectedResolution,
                            frameRate: frameRate
                        )
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

            Button(action: { viewModel.exportVideo() }) {
                if compactExport {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .clipShape(Circle())
                } else {
                    Text("Export")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }

            #if DEBUG
            Menu {
                Button("Debug Off") {
                    showTimelineDebugLayout = false
                }
                Button("Debug On") {
                    showTimelineDebugLayout = true
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            #endif
        }
    }
    
    private func previewSection(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(white: 0.22)

                if viewModel.compositionFrame != nil || viewModel.duration.seconds > 0 {
                    NativeEnginePreviewHost(
                        compositionFrame: viewModel.compositionFrame,
                        durationSeconds: max(viewModel.duration.seconds, 0),
                        desiredIsPlaying: viewModel.isPlaying,
                        seekCommand: viewModel.previewSeekCommand,
                        onDisplayTimeChange: { seconds in
                            DispatchQueue.main.async {
                                viewModel.syncPreviewDisplayTime(seconds)
                            }
                        },
                        onPlaybackStateChange: { playing in
                            DispatchQueue.main.async {
                                viewModel.syncPreviewPlaybackState(playing)
                            }
                        }
                    )
                    .aspectRatio(selectedRatio.ratioValue, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.29)
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
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

                Button(action: { scrollTimelineByButton(delta: -timelineScrollButtonStep) }) {
                    Image(systemName: "backward.frame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canScrollTimelineBackward ? .white.opacity(0.92) : .gray)
                        .frame(width: 38, height: 38)
                        .background(Color(white: 0.18))
                        .clipShape(Circle())
                }

                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.94))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("timeline-playback-toggle")
                .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
                .accessibilityValue(viewModel.isPlaying ? "playing" : "paused")
                .accessibilityAddTraits(.isButton)

                Button(action: { scrollTimelineByButton(delta: timelineScrollButtonStep) }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canScrollTimelineForward ? .white.opacity(0.92) : .gray)
                        .frame(width: 38, height: 38)
                        .background(Color(white: 0.18))
                        .clipShape(Circle())
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(white: 0.08))
        }
        .background(Color.black)
    }
    
    private var timelineSection: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width
            let channelGap: CGFloat = 8
            let rightLanePadding: CGFloat = channelGap
            let leftChannelWidth = min(max(162, viewportWidth * 0.36), 192)
            let rightLaneWidth = viewportWidth - leftChannelWidth
            let playheadXInViewport = viewportWidth / 2
            let playheadXInRightLane = max(playheadXInViewport - leftChannelWidth, channelGap)
            let leadingTimelineInset = max(playheadXInRightLane - rightLanePadding, 0)
            let realTimelineDuration = max(
                viewModel.tracks.timelineContentDurationSeconds,
                max(viewModel.duration.seconds, 0)
            )
            let effectiveTimelineDuration = max(realTimelineDuration * 3, 30)
            let effectiveTimelineContentWidth = max(CGFloat(effectiveTimelineDuration) * 60 * zoomScale, 100)
            let trailingTimelineSpacer = max(rightLaneWidth - playheadXInRightLane, 0)
            let timelineContentWidth = max(
                effectiveTimelineContentWidth + leadingTimelineInset + trailingTimelineSpacer,
                leadingTimelineInset + rightLanePadding,
                rightLaneWidth
            )
            let hostedTimelineWidth = leftChannelWidth + timelineContentWidth

            VStack(spacing: 0) {
                timelineHeaderRow(
                    leftChannelWidth: leftChannelWidth,
                    rightLaneWidth: rightLaneWidth
                )
                ZStack(alignment: .topLeading) {
                    TimelineHorizontalScrollView(
                        currentTime: max(viewModel.currentTime.seconds, 0),
                        isPlaying: viewModel.isPlaying,
                        contentWidth: hostedTimelineWidth,
                        zoomScale: zoomScale,
                        pointsPerSecond: 60 * zoomScale,
                        timelineZeroInset: leftChannelWidth + leadingTimelineInset + rightLanePadding,
                        zoomAnchorRequest: zoomAnchorRequest,
                        onTimePreviewChange: { seconds in
                            viewModel.previewScrub(
                                to: CMTime(seconds: seconds, preferredTimescale: 600)
                            )
                        },
                        onTimeCommit: { seconds in
                            viewModel.seek(
                                to: CMTime(seconds: seconds, preferredTimescale: 600)
                            )
                        },
                        onZoomChange: { updatedZoomScale in
                            zoomScale = updatedZoomScale
                        },
                        onZoomAnchorConsumed: {
                            zoomAnchorRequest = nil
                        },
                        onScrollMetricsChange: { metrics in
                            timelineScrollMetrics = metrics
                        },
                        requestedContentOffsetX: requestedTimelineScrollOffsetX,
                        onRequestedContentOffsetApplied: {
                            requestedTimelineScrollOffsetX = nil
                        }
                    ) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                leftTrackHeaderColumn(leftChannelWidth: leftChannelWidth)
                                    .timelineDebugBox(show: showTimelineDebugLayout, fill: .orange, stroke: .orange)

                                timelineRuler(
                                    timelineWidth: timelineContentWidth,
                                    leadingTimelineInset: leadingTimelineInset,
                                    rightLanePadding: 0
                                )
                                .timelineDebugBox(show: showTimelineDebugLayout, fill: .red, stroke: .red)
                            }

                            trackRowsScrollArea(
                                leftChannelWidth: leftChannelWidth,
                                timelineWidth: timelineContentWidth,
                                leadingTimelineInset: leadingTimelineInset,
                                rightLanePadding: 0
                            )
                            .timelineDebugBox(show: showTimelineDebugLayout, fill: .green, stroke: .green)
                        }
                        .frame(width: hostedTimelineWidth, alignment: .leading)
                    }
                    centeredPlayhead(xInLane: playheadXInViewport)
                    if showTimelineDebugLayout {
                        timelineScrollDebugOverlay(
                            viewportWidth: viewportWidth,
                            leftChannelWidth: leftChannelWidth,
                            rightLaneWidth: rightLaneWidth,
                            hostedTimelineWidth: hostedTimelineWidth,
                            timelineContentWidth: timelineContentWidth
                        )
                        .padding(8)
                    }
                }
                .frame(width: viewportWidth)
                .timelineDebugBox(show: showTimelineDebugLayout, fill: .purple, stroke: .purple)
                scrollbarFooterRow(
                    leftChannelWidth: leftChannelWidth,
                    rightLaneWidth: rightLaneWidth
                )
            }
            .background(Color(white: 0.05))
        }
        .frame(height: 272)
    }
    
    private func timelineHeaderRow(leftChannelWidth: CGFloat, rightLaneWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: leftChannelWidth, height: 40)
                .overlay(
                    Text("\(viewModel.currentTimeString) / \(viewModel.durationString)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                )

            HStack(spacing: 10) {
                Text("Ruler")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.72))

                Spacer(minLength: 0)

                HStack(spacing: 12) {
                    Button(action: { updateZoomScale(max(0.5, zoomScale - 0.25)) }) {
                        Image(systemName: "minus")
                            .foregroundColor(.gray)
                    }

                    Text("\(Int(zoomScale * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 40)

                    Button(action: { updateZoomScale(min(3, zoomScale + 0.25)) }) {
                        Image(systemName: "plus")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(width: rightLaneWidth, height: 40)
            .background(Color.white.opacity(0.03))
        }
    }

    private func timelineToastView(_ toast: TimelineToast) -> some View {
        Text(toast.message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(toastBackgroundColor(toast.style))
            .clipShape(Capsule())
    }

    private func toastBackgroundColor(_ style: TimelineToast.Style) -> Color {
        switch style {
        case .success:
            return Color.green.opacity(0.92)
        case .error:
            return Color.orange.opacity(0.92)
        case .info:
            return Color.white.opacity(0.16)
        }
    }
    
    private func leftTrackHeaderColumn(leftChannelWidth: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(width: leftChannelWidth, height: 24)
            .overlay(
                Text("Tracks")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            )
    }

    private func timelineRuler(
        timelineWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        let pixelsPerSecond = 60 * zoomScale
        let ruler = rulerConfiguration(pointsPerSecond: pixelsPerSecond)
        let visibleDuration = Double(
            max(timelineWidth - leadingTimelineInset - rightLanePadding, 0) / max(pixelsPerSecond, 1)
        )
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
                    .offset(x: CGFloat(tickTime) * pixelsPerSecond)
                }
            }
            .frame(width: max(timelineWidth - leadingTimelineInset - rightLanePadding, 0), alignment: .leading)
        }
        .padding(.leading, rightLanePadding)
        .frame(width: timelineWidth, height: 24, alignment: .leading)
        .frame(height: 24)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedClipId = nil
        }
    }
    
    private func trackRowsScrollArea(
        leftChannelWidth: CGFloat,
        timelineWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tracks) { track in
                    HStack(spacing: 0) {
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
                        .timelineDebugBox(show: showTimelineDebugLayout, fill: .yellow, stroke: .yellow)

                        trackLaneRow(
                            track: track,
                            timelineWidth: timelineWidth,
                            leadingTimelineInset: leadingTimelineInset,
                            rightLanePadding: rightLanePadding
                        )
                        .timelineDebugBox(show: showTimelineDebugLayout, fill: .mint, stroke: .mint)
                    }
                }
            }
            .padding(.top, 0)
            .padding(.bottom, 8)
        }
        .frame(height: 200)
    }

    private func trackLaneRow(
        track: TrackDisplayModel,
        timelineWidth: CGFloat,
        leadingTimelineInset: CGFloat,
        rightLanePadding: CGFloat
    ) -> some View {
        TrackLaneView(
            track: track,
            timelineWidth: timelineWidth,
            leadingTimelineInset: leadingTimelineInset,
            rightLanePadding: rightLanePadding,
            zoomScale: zoomScale,
            selectedClipId: $selectedClipId,
            onClipTap: { clipId in
                selectedClipId = selectedClipId == clipId ? nil : clipId
            },
            onBackgroundTap: {
                selectedClipId = nil
            },
            onClipMove: { clipId, newStartSeconds in
                viewModel.moveClip(
                    clipId,
                    to: CMTime(seconds: newStartSeconds, preferredTimescale: 600)
                )
            },
            onClipTrimLeading: { clipId, timelineStartSeconds, sourceStartSeconds, sourceDurationSeconds in
                viewModel.trimClipLeadingEdge(
                    clipId,
                    timelineStartSeconds: timelineStartSeconds,
                    sourceStartSeconds: sourceStartSeconds,
                    sourceDurationSeconds: sourceDurationSeconds
                )
            },
            onClipTrimTrailing: { clipId, sourceStartSeconds, sourceDurationSeconds in
                viewModel.trimClipTrailingEdge(
                    clipId,
                    sourceStartSeconds: sourceStartSeconds,
                    sourceDurationSeconds: sourceDurationSeconds
                )
            }
        )
    }

    private func scrollbarFooterRow(leftChannelWidth: CGFloat, rightLaneWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(width: leftChannelWidth, height: 14)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

            TimelineScrollbarTrack(
                metrics: timelineScrollMetrics,
                width: rightLaneWidth,
                onScrollRequest: { offsetX in
                    requestedTimelineScrollOffsetX = offsetX
                }
            )
            .frame(width: rightLaneWidth, height: 14)
        }
        .frame(height: 14)
    }

    private func timelineScrollDebugOverlay(
        viewportWidth: CGFloat,
        leftChannelWidth: CGFloat,
        rightLaneWidth: CGFloat,
        hostedTimelineWidth: CGFloat,
        timelineContentWidth: CGFloat
    ) -> some View {
        let maxOffset = max(timelineScrollMetrics.contentWidth - timelineScrollMetrics.visibleWidth, 0)

        return VStack(alignment: .leading, spacing: 3) {
            Text("viewport \(Int(viewportWidth))  left \(Int(leftChannelWidth))  right \(Int(rightLaneWidth))")
            Text("hosted \(Int(hostedTimelineWidth))  timeline \(Int(timelineContentWidth))")
            Text("visible \(Int(timelineScrollMetrics.visibleWidth))  content \(Int(timelineScrollMetrics.contentWidth))")
            Text("offset \(Int(timelineScrollMetrics.offsetX)) / \(Int(maxOffset))")
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.72))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.85), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .allowsHitTesting(false)
    }
    
    private var bottomToolStrip: some View {
        HStack(spacing: 0) {
            if let leadingToolStripItem {
                TimelineBottomToolButton(
                    icon: leadingToolStripItem.icon,
                    title: leadingToolStripItem.title,
                    isLoading: leadingToolStripItem.isLoading,
                    isEnabled: leadingToolStripItem.isEnabled,
                    action: leadingToolStripItem.action
                )

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 34)
                    .padding(.vertical, 6)
            }

            ForEach(activeToolStripItems) { item in
                TimelineBottomToolButton(
                    icon: item.icon,
                    title: item.title,
                    isLoading: item.isLoading,
                    isEnabled: item.isEnabled,
                    action: item.action
                )
            }
        }
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
    }

    private var selectedClip: ClipDisplayModel? {
        guard let selectedClipId else { return nil }
        return viewModel.tracks
            .flatMap(\.clips)
            .first(where: { $0.id == selectedClipId })
    }

    private var contextualToolItems: [BottomBarItem] {
        guard let selectedClip else { return [] }

        var items: [BottomBarItem] = [
            BottomBarItem(id: "split", icon: "scissors", title: "Split") {
                viewModel.splitAtPlayhead()
            }
        ]

        switch selectedClip.type {
        case .video:
            items.append(
                BottomBarItem(id: "volume", icon: "speaker.wave.2", title: "Volume") {}
            )
            items.append(
                BottomBarItem(id: "crop", icon: "crop", title: "Crop") {}
            )
            if canExtractAudioFromSelectedClip {
                items.append(
                    BottomBarItem(
                        id: "extract",
                        icon: "waveform.badge.plus",
                        title: viewModel.isExtractingAudio ? "Extracting..." : "Extract",
                        isLoading: viewModel.isExtractingAudio,
                        isEnabled: !viewModel.isExtractingAudio
                    ) {
                        if let selectedClipId {
                            viewModel.extractAudio(from: selectedClipId)
                        }
                    }
                )
            }
        case .audio:
            items.append(
                BottomBarItem(id: "volume", icon: "speaker.wave.2", title: "Volume") {}
            )
        case .text:
            items.append(
                BottomBarItem(id: "style", icon: "paintbrush", title: "Style") {}
            )
        case .overlay:
            items.append(
                BottomBarItem(id: "crop", icon: "crop", title: "Crop") {}
            )
        case .effect:
            break
        }

        items.append(
            BottomBarItem(id: "delete", icon: "trash", title: "Delete") {
                if let selectedClipId {
                    viewModel.deleteClip(selectedClipId)
                    self.selectedClipId = nil
                }
            }
        )
        items.append(
            BottomBarItem(id: "ripple", icon: "arrow.left.arrow.right", title: "Ripple") {
                if let selectedClipId {
                    viewModel.deleteClip(selectedClipId, ripple: true)
                    self.selectedClipId = nil
                }
            }
        )

        return items
    }

    private var leadingToolStripItem: BottomBarItem? {
        if selectedClip != nil {
            return BottomBarItem(id: "back-to-main", icon: "chevron.left", title: "Back") {
                selectedClipId = nil
            }
        }

        return nil
    }

    private var activeToolStripItems: [BottomBarItem] {
        selectedClip != nil ? contextualToolItems : mainToolStripItems
    }

    private var mainToolStripItems: [BottomBarItem] {
        [
            BottomBarItem(id: "track", icon: "plus", title: "Track") {
                showVideoImportOptions = true
            },
            BottomBarItem(id: "text", icon: "textformat", title: "Text") {},
            BottomBarItem(id: "audio", icon: "music.note", title: "Audio") {
                mediaPickerTarget = .audio
                showMediaPicker = true
            },
            BottomBarItem(id: "overlay", icon: "photo", title: "Overlay") {
                mediaPickerTarget = .overlay
                showMediaPicker = true
            },
            BottomBarItem(id: "effects", icon: "sparkles", title: "Effects") {}
        ]
    }
    
    private func formatSecond(_ second: Int) -> String {
        let mins = second / 60
        let secs = second % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private var timelineScrollButtonStep: CGFloat {
        max(timelineScrollMetrics.visibleWidth * 0.45, 120)
    }

    private var maxTimelineOffsetX: CGFloat {
        max(timelineScrollMetrics.contentWidth - timelineScrollMetrics.visibleWidth, 0)
    }

    private var canScrollTimelineBackward: Bool {
        timelineScrollMetrics.offsetX > 1
    }

    private var canScrollTimelineForward: Bool {
        timelineScrollMetrics.offsetX < maxTimelineOffsetX - 1
    }

    private func scrollTimelineByButton(delta: CGFloat) {
        let targetOffsetX = min(
            max(timelineScrollMetrics.offsetX + delta, 0),
            maxTimelineOffsetX
        )
        requestedTimelineScrollOffsetX = targetOffsetX
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

    private func rulerConfiguration(pointsPerSecond: CGFloat) -> (
        majorInterval: Double,
        mediumInterval: Double,
        minorInterval: Double
    ) {
        let targetMinorPixels: CGFloat = 12
        let rawMinorInterval = Double(targetMinorPixels / max(pointsPerSecond, 1))
        let cleanIntervals: [Double] = [0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60]
        let minorInterval = cleanIntervals.first(where: { $0 >= rawMinorInterval }) ?? 60

        if minorInterval < 1 {
            return (
                majorInterval: minorInterval * 5,
                mediumInterval: minorInterval * 2.5,
                minorInterval: minorInterval
            )
        }

        return (
            majorInterval: minorInterval * 5,
            mediumInterval: minorInterval * 2,
            minorInterval: minorInterval
        )
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

    private var canExtractAudioFromSelectedClip: Bool {
        guard let selectedClipId else {
            return false
        }
        return viewModel.canExtractAudio(from: selectedClipId)
    }
}

private extension View {
    @ViewBuilder
    func timelineDebugBox(show: Bool, fill: Color, stroke: Color) -> some View {
        if show {
            self
                .background(fill.opacity(0.14))
                .overlay(
                    Rectangle()
                        .stroke(stroke.opacity(0.9), lineWidth: 1)
                )
                .allowsHitTesting(false)
        } else {
            self
        }
    }
}

private struct TimelineZoomAnchorRequest: Equatable {
    let id = UUID()
    let anchorTime: Double
    let locationX: CGFloat?
}

private struct TimelineScrollMetrics: Equatable {
    var offsetX: CGFloat = 0
    var visibleWidth: CGFloat = 0
    var contentWidth: CGFloat = 0
}

private struct BottomBarItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    init(
        id: String,
        icon: String,
        title: String,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }
}

private struct TimelineHorizontalScrollView<Content: View>: UIViewRepresentable {
    let currentTime: Double
    let isPlaying: Bool
    let contentWidth: CGFloat
    let zoomScale: CGFloat
    let pointsPerSecond: CGFloat
    let timelineZeroInset: CGFloat
    let zoomAnchorRequest: TimelineZoomAnchorRequest?
    let onTimePreviewChange: (Double) -> Void
    let onTimeCommit: (Double) -> Void
    let onZoomChange: (CGFloat) -> Void
    let onZoomAnchorConsumed: () -> Void
    let onScrollMetricsChange: (TimelineScrollMetrics) -> Void
    let requestedContentOffsetX: CGFloat?
    let onRequestedContentOffsetApplied: () -> Void
    let content: Content

    init(
        currentTime: Double,
        isPlaying: Bool,
        contentWidth: CGFloat,
        zoomScale: CGFloat,
        pointsPerSecond: CGFloat,
        timelineZeroInset: CGFloat,
        zoomAnchorRequest: TimelineZoomAnchorRequest?,
        onTimePreviewChange: @escaping (Double) -> Void,
        onTimeCommit: @escaping (Double) -> Void,
        onZoomChange: @escaping (CGFloat) -> Void,
        onZoomAnchorConsumed: @escaping () -> Void,
        onScrollMetricsChange: @escaping (TimelineScrollMetrics) -> Void,
        requestedContentOffsetX: CGFloat?,
        onRequestedContentOffsetApplied: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.currentTime = currentTime
        self.isPlaying = isPlaying
        self.contentWidth = contentWidth
        self.zoomScale = zoomScale
        self.pointsPerSecond = pointsPerSecond
        self.timelineZeroInset = timelineZeroInset
        self.zoomAnchorRequest = zoomAnchorRequest
        self.onTimePreviewChange = onTimePreviewChange
        self.onTimeCommit = onTimeCommit
        self.onZoomChange = onZoomChange
        self.onZoomAnchorConsumed = onZoomAnchorConsumed
        self.onScrollMetricsChange = onScrollMetricsChange
        self.requestedContentOffsetX = requestedContentOffsetX
        self.onRequestedContentOffsetApplied = onRequestedContentOffsetApplied
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            hostingController: UIHostingController(rootView: content),
            hostedWidth: contentWidth,
            zoomScale: zoomScale,
            pointsPerSecond: pointsPerSecond,
            timelineZeroInset: timelineZeroInset,
            onTimePreviewChange: onTimePreviewChange,
            onTimeCommit: onTimeCommit,
            onZoomChange: onZoomChange,
            onZoomAnchorConsumed: onZoomAnchorConsumed,
            onScrollMetricsChange: onScrollMetricsChange
        )
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.bounces = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
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
        hostedView.insetsLayoutMarginsFromSafeArea = false
        hostedView.layoutMargins = .zero
        hostedView.directionalLayoutMargins = .zero
        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostedView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            context.coordinator.hostedWidthConstraint
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if context.coordinator.isUserInteracting || context.coordinator.isPinchZooming {
            context.coordinator.pendingRootView = content
        } else {
            context.coordinator.hostingController.rootView = content
            context.coordinator.pendingRootView = nil
        }
        context.coordinator.hostedWidthConstraint.constant = contentWidth
        context.coordinator.zoomScale = zoomScale
        context.coordinator.pointsPerSecond = pointsPerSecond
        context.coordinator.timelineZeroInset = timelineZeroInset
        context.coordinator.onTimePreviewChange = onTimePreviewChange
        context.coordinator.onTimeCommit = onTimeCommit
        context.coordinator.onZoomChange = onZoomChange
        context.coordinator.onZoomAnchorConsumed = onZoomAnchorConsumed
        context.coordinator.onScrollMetricsChange = onScrollMetricsChange
        uiView.layoutIfNeeded()
        context.coordinator.hostingController.view.layoutIfNeeded()
        context.coordinator.reportScrollMetricsAsync(for: uiView)

        if let requestedContentOffsetX {
            context.coordinator.applyProgrammaticOffset(
                requestedContentOffsetX,
                to: uiView
            ) {
                let requestedSeconds = context.coordinator.timelineTime(
                    forContentOffsetX: requestedContentOffsetX
                )
                DispatchQueue.main.async {
                    onTimePreviewChange(requestedSeconds)
                    onTimeCommit(requestedSeconds)
                    onRequestedContentOffsetApplied()
                }
            }
            return
        }

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
            context.coordinator.pendingZoomAnchor = nil
            context.coordinator.lastCommittedZoomScale = zoomScale
            context.coordinator.applyProgrammaticOffset(
                anchoredOffsetX,
                to: uiView
            ) {
                let anchoredSeconds = context.coordinator.timelineTime(forContentOffsetX: anchoredOffsetX)
                DispatchQueue.main.async {
                    onTimePreviewChange(anchoredSeconds)
                    onTimeCommit(anchoredSeconds)
                    onZoomAnchorConsumed()
                }
            }
            return
        }

        let targetOffsetX = max(CGFloat(currentTime) * pointsPerSecond, 0)
        let isTrailingPastCommittedTime = !isPlaying && uiView.contentOffset.x > targetOffsetX + 1
        guard !context.coordinator.isUserInteracting,
              !isTrailingPastCommittedTime,
              abs(uiView.contentOffset.x - targetOffsetX) > 1
        else {
            return
        }

        context.coordinator.applyProgrammaticOffset(
            targetOffsetX,
            to: uiView
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        let hostingController: UIHostingController<Content>
        let hostedWidthConstraint: NSLayoutConstraint
        var zoomScale: CGFloat
        var pointsPerSecond: CGFloat
        var timelineZeroInset: CGFloat
        var onTimePreviewChange: (Double) -> Void
        var onTimeCommit: (Double) -> Void
        var onZoomChange: (CGFloat) -> Void
        var onZoomAnchorConsumed: () -> Void
        var onScrollMetricsChange: (TimelineScrollMetrics) -> Void
        var isProgrammaticScroll = false
        var isUserInteracting = false
        var isPinchZooming = false
        var hasAppliedDeferredInitialOffset = false
        var pendingRootView: Content?
        var pinchStartZoomScale: CGFloat = 1
        var lastCommittedZoomScale: CGFloat
        var lastHandledZoomAnchorId: UUID?
        var pendingZoomAnchor: (time: Double, locationX: CGFloat)?

        init(
            hostingController: UIHostingController<Content>,
            hostedWidth: CGFloat,
            zoomScale: CGFloat,
            pointsPerSecond: CGFloat,
            timelineZeroInset: CGFloat,
            onTimePreviewChange: @escaping (Double) -> Void,
            onTimeCommit: @escaping (Double) -> Void,
            onZoomChange: @escaping (CGFloat) -> Void,
            onZoomAnchorConsumed: @escaping () -> Void,
            onScrollMetricsChange: @escaping (TimelineScrollMetrics) -> Void
        ) {
            self.hostingController = hostingController
            self.hostedWidthConstraint = hostingController.view.widthAnchor.constraint(
                equalToConstant: hostedWidth
            )
            self.zoomScale = zoomScale
            self.pointsPerSecond = pointsPerSecond
            self.timelineZeroInset = timelineZeroInset
            self.onTimePreviewChange = onTimePreviewChange
            self.onTimeCommit = onTimeCommit
            self.onZoomChange = onZoomChange
            self.onZoomAnchorConsumed = onZoomAnchorConsumed
            self.onScrollMetricsChange = onScrollMetricsChange
            self.lastCommittedZoomScale = zoomScale
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isProgrammaticScroll, !isPinchZooming else { return }

            reportScrollMetricsAsync(for: scrollView)
            let seconds = timelineTime(forContentOffsetX: scrollView.contentOffset.x)
            DispatchQueue.main.async {
                self.onTimePreviewChange(seconds)
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            let seconds = timelineTime(forContentOffsetX: scrollView.contentOffset.x)
            DispatchQueue.main.async {
                self.onTimeCommit(seconds)
            }
            if !decelerate {
                isUserInteracting = false
                applyPendingRootViewIfNeeded()
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let seconds = timelineTime(forContentOffsetX: scrollView.contentOffset.x)
            DispatchQueue.main.async {
                self.onTimeCommit(seconds)
            }
            isUserInteracting = false
            applyPendingRootViewIfNeeded()
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
                let clampedZoomScale = min(max(pinchStartZoomScale * recognizer.scale, 0.5), 3)
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
                let seconds = timelineTime(forContentOffsetX: scrollView.contentOffset.x)
                DispatchQueue.main.async {
                    self.onTimePreviewChange(seconds)
                    self.onTimeCommit(seconds)
                }
                applyPendingRootViewIfNeeded()
            default:
                break
            }
        }

        func applyPendingRootViewIfNeeded() {
            guard let pendingRootView else { return }
            hostingController.rootView = pendingRootView
            self.pendingRootView = nil
        }

        func applyProgrammaticOffset(
            _ targetOffsetX: CGFloat,
            to scrollView: UIScrollView,
            completion: (() -> Void)? = nil
        ) {
            let applyOffset = {
                self.isProgrammaticScroll = true
                scrollView.setContentOffset(
                    CGPoint(x: targetOffsetX, y: scrollView.contentOffset.y),
                    animated: false
                )
                self.isProgrammaticScroll = false
                self.reportScrollMetricsAsync(for: scrollView)
                completion?()
            }

            scrollView.layoutIfNeeded()
            hostingController.view.layoutIfNeeded()

            let hasValidViewport = scrollView.bounds.width > 0
            let hasValidContent = scrollView.contentSize.width > 0

            if hasValidViewport && hasValidContent {
                hasAppliedDeferredInitialOffset = true
                applyOffset()
                return
            }

            guard !hasAppliedDeferredInitialOffset else {
                applyOffset()
                return
            }

            hasAppliedDeferredInitialOffset = true
            DispatchQueue.main.async { [weak scrollView] in
                guard let scrollView else { return }
                scrollView.layoutIfNeeded()
                self.hostingController.view.layoutIfNeeded()
                applyOffset()
            }
        }

        func timelineTime(forContentOffsetX offsetX: CGFloat) -> Double {
            max(offsetX / max(pointsPerSecond, 1), 0)
        }

        func reportScrollMetrics(for scrollView: UIScrollView) {
            onScrollMetricsChange(
                TimelineScrollMetrics(
                    offsetX: scrollView.contentOffset.x,
                    visibleWidth: scrollView.bounds.width,
                    contentWidth: scrollView.contentSize.width
                )
            )
        }

        func reportScrollMetricsAsync(for scrollView: UIScrollView) {
            let metrics = TimelineScrollMetrics(
                offsetX: scrollView.contentOffset.x,
                visibleWidth: scrollView.bounds.width,
                contentWidth: scrollView.contentSize.width
            )
            DispatchQueue.main.async {
                self.onScrollMetricsChange(metrics)
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

private struct TimelineScrollbarTrack: View {
    let metrics: TimelineScrollMetrics
    let width: CGFloat
    let onScrollRequest: (CGFloat) -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 14)

            Capsule()
                .fill(Color.white.opacity(0.82))
                .frame(width: thumbWidth, height: 6)
                .offset(x: thumbOffset)
        }
        .frame(width: width, height: 14, alignment: .leading)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onScrollRequest(contentOffset(forTrackLocationX: value.location.x))
                }
        )
    }

    private var trackWidth: CGFloat {
        max(width, 1)
    }

    private var thumbWidth: CGFloat {
        guard metrics.contentWidth > 0, metrics.visibleWidth > 0 else { return trackWidth }
        let ratio = min(max(metrics.visibleWidth / metrics.contentWidth, 0.08), 1)
        return max(trackWidth * ratio, 24)
    }

    private var thumbOffset: CGFloat {
        let maxOffset = max(metrics.contentWidth - metrics.visibleWidth, 0)
        guard maxOffset > 0 else { return 0 }
        let progress = min(max(metrics.offsetX / maxOffset, 0), 1)
        return progress * max(trackWidth - thumbWidth, 0)
    }

    private func contentOffset(forTrackLocationX locationX: CGFloat) -> CGFloat {
        let clampedX = min(max(locationX, 0), trackWidth)
        let maxThumbOffset = max(trackWidth - thumbWidth, 0)
        guard maxThumbOffset > 0 else { return 0 }
        let progress = clampedX / maxThumbOffset
        let maxContentOffset = max(metrics.contentWidth - metrics.visibleWidth, 0)
        return min(max(progress * maxContentOffset, 0), maxContentOffset)
    }
}
