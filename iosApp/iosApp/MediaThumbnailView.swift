import SwiftUI
import AVFoundation
import UIKit

struct MediaThumbnailView: View {
    let project: WorkspaceProject

    @State private var thumbnailImage: UIImage?

    var body: some View {
        ZStack {
            if let thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else {
                AppTheme.surfaceDark
                Image(systemName: placeholderIcon)
                    .foregroundColor(AppTheme.textSecondary)
            }
        }
        .task(id: project.id) {
            thumbnailImage = await generateThumbnail()
        }
    }

    private var placeholderIcon: String {
        if project.isVideo {
            return "video"
        }
        if project.isAudio {
            return "waveform"
        }
        return "photo"
    }

    private func generateThumbnail() async -> UIImage? {
        if project.isVideo {
            return generateVideoThumbnail()
        }
        if project.isAudio {
            return nil
        }
        return UIImage(contentsOfFile: project.mediaUrl.path)
    }

    private func generateVideoThumbnail() -> UIImage? {
        let asset = AVAsset(url: project.mediaUrl)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        guard let image = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}
