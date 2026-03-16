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
            let trackLabelWidth: CGFloat = 72
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
        .frame(height: 272)
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
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
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
                            .fill(Color.white.opacity(0.34))
                            .frame(width: 1)
                    )
                    .shadow(color: .red.opacity(0.45), radius: 4)
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
                    .offset(x: clip.startOffset(zoomScale: zoomScale))
                    .onTapGesture {
                        onClipTap(clip.id)
                    }
                }
            }
            .frame(width: timelineWidth, height: 44, alignment: .leading)
            .padding(.horizontal, playheadInset)
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
        VStack(spacing: 4) {
            Image(systemName: iconForType(track.type))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(trackColor(track.type))
            
            Text(trackShortName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)

            HStack(spacing: 3) {
                if track.isMuted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.yellow.opacity(0.9))
                }

                if track.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.red.opacity(0.9))
                }
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(trackColor(track.type).opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(trackColor(track.type).opacity(0.28), lineWidth: 1)
        )
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
            TimelineClipThumbnail(sourcePath: clip.sourcePath)
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

private struct TimelineClipThumbnail: View {
    let sourcePath: String

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.12)
                Image(systemName: "film")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .clipped()
        .task(id: sourcePath) {
            image = await TimelineClipVisualCache.thumbnail(for: sourcePath)
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
    TimelineEditorScreen()
}
