import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct TimelineTestScreen: View {
    @StateObject private var viewModel = TimelineTestViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var showExportProgress = false
    @State private var exportProgress: Float = 0
    @State private var showPreview = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let previewImage = viewModel.previewImage, showPreview {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                timelineInfoSection
                controlsSection
                tracksSection
                Spacer()
            }
            .padding()
            .navigationTitle("Timeline Engine Test")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                if let newItem = newItem {
                    Task {
                        await viewModel.importVideo(from: newItem)
                    }
                }
            }
            .overlay {
                if showExportProgress {
                    exportProgressOverlay
                }
            }
        }
    }
    
    private var timelineInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline Info")
                .font(.headline)
            
            HStack {
                Label("Duration: \(formatTime(viewModel.duration))", systemImage: "clock")
                Spacer()
                Label("Clips: \(viewModel.totalClips)", systemImage: "film")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var controlsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                viewModel.playPreview()
                showPreview = viewModel.previewImage != nil
            }) {
                Label(showPreview ? "Replay" : "Preview", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            Button(action: { viewModel.splitAtMiddle() }) {
                Label("Split", systemImage: "scissors")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.totalClips == 0)
            
            Button(action: { viewModel.clearTimeline() }) {
                Label("Clear", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.totalClips == 0)
        }
    }
    
    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracks")
                .font(.headline)
            
            ForEach(viewModel.trackInfos, id: \.id) { info in
                TrackRow(info: info)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exportProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView(value: exportProgress) {
                    Text("Exporting...")
                        .font(.headline)
                }
                
                Text("\(Int(exportProgress * 100))%")
                    .font(.title2)
                    .bold()
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = time.seconds
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct TrackRow: View {
    let info: TrackInfo
    
    var body: some View {
        HStack {
            Image(systemName: iconForType(info.type))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(info.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(info.clipCount) clips")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if info.isMuted {
                Image(systemName: "speaker.slash")
                    .foregroundColor(.red)
            }
            
            if info.isLocked {
                Image(systemName: "lock.fill")
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
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
}

struct TrackInfo: Identifiable {
    let id: UUID
    let type: TrackType
    let name: String
    let clipCount: Int
    let isMuted: Bool
    let isLocked: Bool
}

@MainActor
class TimelineTestViewModel: ObservableObject {
    @Published var duration: CMTime = .zero
    @Published var totalClips: Int = 0
    @Published var trackInfos: [TrackInfo] = []
    @Published private(set) var previewImage: UIImage?
    
    private var engine = TimelineEngine()
    
    init() {
        refreshInfo()
    }
    
    func importVideo(from item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self),
           let url = saveToTempFile(data: data) {
            importVideoToTimeline(url: url)
        }
    }
    
    private func saveToTempFile(data: Data) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "import_\(UUID().uuidString).mov"
        let url = tempDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Save error: \(error)")
            return nil
        }
    }
    
    private func importVideoToTimeline(url: URL) {
        engine.importVideo(from: url, toTrackType: .video, at: duration) { result in
            Task { @MainActor in
                switch result {
                case .success(let clipId):
                    print("Imported clip: \(clipId)")
                    self.refreshInfo()
                case .failure(let error):
                    print("Import failed: \(error)")
                }
            }
        }
    }
    
    func playPreview() {
        guard
            let firstVideoClip = engine.timeline.tracks
                .first(where: { $0.type == .video })?
                .clips
                .compactMap({ $0 as? VideoClip })
                .first
        else {
            previewImage = nil
            return
        }

        let asset = AVURLAsset(url: firstVideoClip.sourceUrl)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1280, height: 1280)
        generator.generateCGImageAsynchronously(for: firstVideoClip.sourceRange.start) { [weak self] cgImage, _, _ in
            guard let self, let cgImage else { return }
            Task { @MainActor in
                self.previewImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    func splitAtMiddle() {
        let middleTime = CMTime(seconds: duration.seconds / 2, preferredTimescale: 600)
        let newIds = engine.splitAllClips(at: middleTime)
        print("Split created \(newIds.count) new clips")
        refreshInfo()
    }
    
    func clearTimeline() {
        engine.clearAllClips()
        refreshInfo()
    }
    
    private func refreshInfo() {
        duration = engine.duration
        totalClips = engine.timeline.tracks.reduce(0) { $0 + $1.clips.count }
        
        trackInfos = engine.timeline.tracks.map { track in
            TrackInfo(
                id: track.id,
                type: track.type,
                name: track.name,
                clipCount: track.clips.count,
                isMuted: track.isMuted,
                isLocked: track.isLocked
            )
        }
    }
}

#Preview {
    TimelineTestScreen()
}
