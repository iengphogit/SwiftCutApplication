import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct TimelineEditorScreen: View {
    @StateObject private var viewModel = TimelineEditorViewModel()
    @State private var selectedClipId: UUID?
    @State private var showMediaPicker = false
    @State private var mediaPickerTarget: MediaPickerTarget = .video
    @State private var zoomScale: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
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
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(viewModel.projectName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canUndo ? .white : .gray)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canUndo)

            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.canRedo ? .white : .gray)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.2))
                    .clipShape(Circle())
            }
            .disabled(!viewModel.canRedo)

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
            
            VStack {
                Spacer()
                HStack {
                    Button(action: { viewModel.togglePlayback() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color.black.opacity(0.72))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )
                            .clipShape(Circle())
                    }

                    Spacer()
                    
                    Text(viewModel.currentTimeString)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(12)

                Spacer()
            }
        }
        .frame(height: geometry.size.height * 0.35)
        .clipped()
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
            let trackLabelWidth: CGFloat = 48
            let timelineWidth = max(viewModel.tracks.timelineContentWidth(zoomScale: zoomScale), geometry.size.width)
            let playheadInset = max((geometry.size.width - trackLabelWidth - 8) / 2, 0)

            VStack(spacing: 0) {
                timelineHeader
                ZStack(alignment: .topLeading) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(spacing: 0) {
                            timelineRuler(
                                timelineWidth: timelineWidth,
                                trackLabelWidth: trackLabelWidth,
                                playheadInset: playheadInset
                            )
                            tracksView(
                                timelineWidth: timelineWidth,
                                trackLabelWidth: trackLabelWidth,
                                playheadInset: playheadInset
                            )
                        }
                    }
                    .defaultScrollAnchor(.center)

                    centeredPlayhead(trackLabelWidth: trackLabelWidth + 8)
                }
            }
            .background(Color(white: 0.05))
        }
        .frame(height: 240)
    }
    
    private var timelineHeader: some View {
        HStack {
            Text("Timeline")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            
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
        trackLabelWidth: CGFloat,
        playheadInset: CGFloat
    ) -> some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: trackLabelWidth, height: 24)

            HStack(spacing: 0) {
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
            .frame(width: timelineWidth, alignment: .leading)
            .padding(.horizontal, playheadInset)
        }
        .frame(height: 24)
        .padding(.horizontal, 8)
    }
    
    private func tracksView(
        timelineWidth: CGFloat,
        trackLabelWidth: CGFloat,
        playheadInset: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.tracks) { track in
                    TrackRowView(
                        track: track,
                        timelineWidth: timelineWidth,
                        trackLabelWidth: trackLabelWidth,
                        playheadInset: playheadInset,
                        zoomScale: zoomScale,
                        selectedClipId: $selectedClipId,
                        onClipTap: { clipId in
                            selectedClipId = selectedClipId == clipId ? nil : clipId
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
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

    private func centeredPlayhead(trackLabelWidth: CGFloat) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.red)
                    .frame(width: 20, height: 8)
                    .shadow(color: .red.opacity(0.5), radius: 4)
                
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
                    .frame(width: 3)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 1)
                    )
                    .shadow(color: .red.opacity(0.4), radius: 3)
            }
            .frame(height: geometry.size.height, alignment: .top)
            .position(
                x: trackLabelWidth + ((geometry.size.width - trackLabelWidth) / 2),
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
    let trackLabelWidth: CGFloat
    let playheadInset: CGFloat
    let zoomScale: CGFloat
    @Binding var selectedClipId: UUID?
    let onClipTap: (UUID) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            trackIcon
                .frame(width: trackLabelWidth)

            ZStack(alignment: .leading) {
                ForEach(track.clips) { clip in
                    ClipView(
                        clip: clip,
                        zoomScale: zoomScale,
                        isSelected: selectedClipId == clip.id
                    )
                    .offset(x: clip.startOffset(zoomScale: zoomScale))
                    .onTapGesture {
                        onClipTap(clip.id)
                    }
                }
            }
            .frame(width: timelineWidth, height: 36, alignment: .leading)
            .padding(.horizontal, playheadInset)
        }
        .frame(height: 44)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private var trackIcon: some View {
        VStack(spacing: 2) {
            Image(systemName: iconForType(track.type))
                .font(.system(size: 14))
                .foregroundColor(trackColor(track.type))
            
            Text(track.name)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray)
        }
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
}

private struct ClipView: View {
    let clip: ClipDisplayModel
    let zoomScale: CGFloat
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if clip.hasThumbnail {
                Color.blue.opacity(0.3)
            } else {
                Color.orange.opacity(0.3)
            }
        }
        .frame(width: clip.width(zoomScale: zoomScale), height: 36)
        .background(clipColor(clip.type))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
        )
        .overlay(
            Text(clip.name)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(4)
        )
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
    TimelineEditorScreen()
}
