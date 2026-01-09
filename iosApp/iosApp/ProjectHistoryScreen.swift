import SwiftUI
import Foundation
import AVFoundation

struct ProjectHistoryScreen: View {
    let projects: [WorkspaceProject]
    var onCreateNewProject: () -> Void
    var onOpenProject: (WorkspaceProject) -> Void
    var onExit: () -> Void
    var onDeleteProject: (WorkspaceProject) -> Void

    private let relativeFormatter = RelativeDateTimeFormatter()

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HeaderBar(onExit: onExit)
                        .padding(.horizontal, 24)
                        .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Start Creating")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        NewProjectCard(onCreate: onCreateNewProject)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    HStack {
                        Text("Project History")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("See All")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.accentBlue)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    VStack(spacing: 12) {
                        ForEach(projects) { project in
                            ProjectHistoryRow(
                                project: project,
                                subtitle: relativeFormatter.localizedString(
                                    for: project.createdAt,
                                    relativeTo: Date()
                                ),
                                onOpen: { onOpenProject(project) },
                                onDelete: { onDeleteProject(project) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct HeaderBar: View {
    var onExit: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.accentRed)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                    )
                Text("SwiftCut")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            HStack(spacing: 8) {
                CircleButton(symbol: "xmark", action: onExit)
            }
        }
    }
}

private struct CircleButton: View {
    let symbol: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct NewProjectCard: View {
    var onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            HStack {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "plus")
                                .foregroundColor(.white)
                                .font(.system(size: 24, weight: .bold))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text("New Project")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                Image(systemName: "video")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.3))
                    .rotationEffect(.degrees(-12))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(AppTheme.accentBlue)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectHistoryRow: View {
    let project: WorkspaceProject
    let subtitle: String
    var onOpen: () -> Void
    var onDelete: () -> Void

    @State private var durationText: String?
    @State private var isOptionsPresented = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                MediaThumbnailView(project: project)
                if project.isVideo {
                    Color.black.opacity(0.2)
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .frame(width: 96, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(durationOverlay)

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(projectTypeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
            }

            Spacer()
            Divider()
                .frame(height: 36)
                .background(AppTheme.surfaceBorder)

            Button(action: { isOptionsPresented = true }) {
                Image(systemName: "ellipsis")
                    .foregroundColor(AppTheme.textSecondary)
                    .rotationEffect(.degrees(90))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .contentShape(Rectangle())
        }
        .padding(10)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .confirmationDialog("Project Options", isPresented: $isOptionsPresented) {
            Button("Delete Project", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Divider()
        }
        .task(id: project.id) {
            durationText = project.isVideo || project.isAudio ? formatDuration() : nil
        }
    }

    private var projectTypeLabel: String {
        if project.isVideo {
            return "Video"
        }
        if project.isAudio {
            return "Audio"
        }
        return "Image"
    }

    private func formatDuration() -> String? {
        let asset = AVAsset(url: project.mediaUrl)
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite else {
            return nil
        }
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private var durationOverlay: some View {
        Group {
            if let durationText {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(durationText)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(6)
            }
        }
    }
}
