import SwiftUI
import AVKit
import UIKit

struct StudioScreen: View {
    let project: WorkspaceProject
    var onBack: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StudioHeader(onBack: onBack)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                MediaPreview(project: project)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxHeight: 320)

                Spacer()

                TimelinePanel()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct StudioHeader: View {
    var onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
            }

            Spacer()

            Text("Edit Media")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Button(action: {}) {
                Text("Export")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentBlue)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct MediaPreview: View {
    let project: WorkspaceProject

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            if project.isVideo {
                VideoPlayer(player: AVPlayer(url: project.mediaUrl))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if project.isAudio {
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Audio Track")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
            } else if let image = UIImage(contentsOfFile: project.mediaUrl.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

private struct TimelinePanel: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("00:04.2 / 00:15.0")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 24) {
                Image(systemName: "arrow.uturn.backward")
                Image(systemName: "arrow.uturn.forward")
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .bold))
                Image(systemName: "plus.circle")
                Image(systemName: "minus.circle")
            }
            .foregroundColor(AppTheme.textSecondary)

            HStack(spacing: 24) {
                ToolButton(title: "Split", symbol: "scissors")
                ToolButton(title: "Speed", symbol: "speedometer")
                ToolButton(title: "Volume", symbol: "speaker.wave.2")
                ToolButton(title: "Crop", symbol: "crop")
                ToolButton(title: "Delete", symbol: "trash")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppTheme.surfaceDark)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

private struct ToolButton: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(AppTheme.surface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: symbol)
                        .foregroundColor(AppTheme.textPrimary)
                )
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}
