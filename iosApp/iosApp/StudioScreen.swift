import SwiftUI
import AVKit
import UIKit

struct StudioScreen: View {
    let project: WorkspaceProject
    var onBack: () -> Void
    var onUpdateAspectRatio: (AspectRatio) -> Void
    var onUpdateUhdSettings: (UhdResolution, UhdFrameRate, UhdBitrate) -> Void

    @State private var isRatioPanelVisible = false
    @State private var isUhdPanelVisible = false
    @State private var selectedRatio: AspectRatio
    @State private var selectedResolution: UhdResolution
    @State private var selectedFrameRate: UhdFrameRate
    @State private var selectedBitrate: UhdBitrate

    init(
        project: WorkspaceProject,
        onBack: @escaping () -> Void,
        onUpdateAspectRatio: @escaping (AspectRatio) -> Void,
        onUpdateUhdSettings: @escaping (UhdResolution, UhdFrameRate, UhdBitrate) -> Void
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
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                StudioHeader(
                    onBack: onBack,
                    selectedRatio: selectedRatio,
                    isRatioPanelVisible: $isRatioPanelVisible,
                    isUhdPanelVisible: $isUhdPanelVisible,
                    onSelectRatio: { ratio in
                        selectedRatio = ratio
                        isRatioPanelVisible = false
                        onUpdateAspectRatio(ratio)
                    },
                    onSelectResolution: { resolution in
                        selectedResolution = resolution
                        onUpdateUhdSettings(
                            resolution,
                            selectedFrameRate,
                            selectedBitrate
                        )
                    },
                    onSelectFrameRate: { frameRate in
                        selectedFrameRate = frameRate
                        onUpdateUhdSettings(
                            selectedResolution,
                            frameRate,
                            selectedBitrate
                        )
                    },
                    onSelectBitrate: { bitrate in
                        selectedBitrate = bitrate
                        onUpdateUhdSettings(
                            selectedResolution,
                            selectedFrameRate,
                            bitrate
                        )
                    },
                    onApplyUhd: { isUhdPanelVisible = false },
                    selectedResolution: selectedResolution,
                    selectedFrameRate: selectedFrameRate,
                    selectedBitrate: selectedBitrate
                )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                DividerLine()
                    .padding(.top, 12)

                MediaPreview(project: project, aspectRatio: selectedRatio)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(maxHeight: 320)

                DividerLine()
                    .padding(.top, 16)

                ToolPanel()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                TrackLinesPanel()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                DividerLine()
                    .padding(.top, 16)

                TimelinePanel()
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.surfaceBorder)
            .frame(height: 1)
    }
}

private struct RatioContextPanel: View {
    let selectedRatio: AspectRatio
    let onSelect: (AspectRatio) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AspectRatio.allCases, id: \.self) { ratio in
                    Button(action: { onSelect(ratio) }) {
                        RatioOptionButtonLabel(ratio: ratio, isSelected: ratio == selectedRatio)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if let lastRatio = AspectRatio.allCases.last, ratio != lastRatio {
                        DividerLine()
                            .frame(height: 24)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct RatioOptionButtonLabel: View {
    let ratio: AspectRatio
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .stroke(AppTheme.textPrimary, lineWidth: 1)
                .frame(width: ratio.iconSize.width, height: ratio.iconSize.height)

            Text(ratio.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
        .opacity(isSelected ? 1.0 : 0.7)
    }
}

private struct UhdContextPanel: View {
    var onSelectResolution: (UhdResolution) -> Void
    var onSelectFrameRate: (UhdFrameRate) -> Void
    var onSelectBitrate: (UhdBitrate) -> Void
    var onApply: () -> Void
    let selectedResolution: UhdResolution
    let selectedFrameRate: UhdFrameRate
    let selectedBitrate: UhdBitrate

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resolution")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            StepSelectorRow(
                items: UhdResolution.allCases,
                selectedItem: selectedResolution,
                label: { $0.displayName },
                onSelect: onSelectResolution
            )

            Text("Frame Rate")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            StepSelectorRow(
                items: UhdFrameRate.allCases,
                selectedItem: selectedFrameRate,
                label: { $0.displayName },
                onSelect: onSelectFrameRate
            )

            Text("Bitrate (Mbps)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            StepSelectorRow(
                items: UhdBitrate.allCases,
                selectedItem: selectedBitrate,
                label: { $0.displayName },
                onSelect: onSelectBitrate
            )

            DividerLine()
                .padding(.top, 4)

            Button(action: onApply) {
                Text("Apply")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct StepSelectorRow<Option: Hashable>: View {
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
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                item == selectedItem
                                    ? AppTheme.accentBlue.opacity(0.15)
                                    : AppTheme.surface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        item == selectedItem
                                            ? AppTheme.accentBlue
                                            : AppTheme.surfaceBorder,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    if let lastItem = items.last, item != lastItem {
                        DividerLine()
                            .frame(height: 20)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private extension AspectRatio {
    var ratioValue: CGFloat {
        switch self {
        case .ratio16x9:
            return 16.0 / 9.0
        case .ratio9x16:
            return 9.0 / 16.0
        case .ratio1x1:
            return 1.0
        }
    }

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

private struct StudioHeader: View {
    var onBack: () -> Void
    let selectedRatio: AspectRatio
    @Binding var isRatioPanelVisible: Bool
    @Binding var isUhdPanelVisible: Bool
    var onSelectRatio: (AspectRatio) -> Void
    var onSelectResolution: (UhdResolution) -> Void
    var onSelectFrameRate: (UhdFrameRate) -> Void
    var onSelectBitrate: (UhdBitrate) -> Void
    var onApplyUhd: () -> Void
    let selectedResolution: UhdResolution
    let selectedFrameRate: UhdFrameRate
    let selectedBitrate: UhdBitrate

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

            HStack(spacing: 12) {
                Button(action: { isRatioPanelVisible = true }) {
                    HeaderOptionButton(
                        title: selectedRatio.displayName,
                        ratioIconSize: selectedRatio.iconSize
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isRatioPanelVisible, arrowEdge: .top) {
                    RatioContextPanel(
                        selectedRatio: selectedRatio,
                        onSelect: onSelectRatio
                    )
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
                }
                Button(action: { isUhdPanelVisible = true }) {
                    HeaderOptionButton(title: "UHD")
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isUhdPanelVisible, arrowEdge: .top) {
                    UhdContextPanel(
                        onSelectResolution: onSelectResolution,
                        onSelectFrameRate: onSelectFrameRate,
                        onSelectBitrate: onSelectBitrate,
                        onApply: onApplyUhd,
                        selectedResolution: selectedResolution,
                        selectedFrameRate: selectedFrameRate,
                        selectedBitrate: selectedBitrate
                    )
                    .padding(12)
                    .presentationCompactAdaptation(.popover)
                }

                Button(action: {}) {
                    Text("Export >")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

private struct HeaderOptionButton: View {
    let title: String
    var ratioIconSize: CGSize? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let ratioIconSize {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(AppTheme.textPrimary, lineWidth: 1)
                    .frame(width: ratioIconSize.width, height: ratioIconSize.height)
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.surface.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

private struct MediaPreview: View {
    let project: WorkspaceProject
    let aspectRatio: AspectRatio

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
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatio.ratioValue, contentMode: .fit)
    }
}

private struct TimelinePanel: View {
    var body: some View {
        VStack(spacing: 16) {
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

private struct ToolPanel: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.uturn.backward")
            Image(systemName: "arrow.uturn.forward")
            Spacer()
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(AppTheme.textSecondary)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

private struct TrackLinesPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Track Lines")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                HStack(spacing: 8) {
                    Text("00:04.2 / 00:15.0")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))

                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(width: 1, height: 14)

                    Button(action: {}) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.textSecondary)
                            .frame(width: 40, height: 32)
                            .background(AppTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 10) {
                TrackLineRow(title: "Video Track")
                TrackLineRow(title: "Audio Track")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
}

private struct TrackLineRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.surfaceDark)
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
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
