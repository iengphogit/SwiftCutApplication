import SwiftUI

struct LauncherScreen: View {
    var onStartNewProject: () -> Void = {}
    var onOpenHistory: () -> Void = {}

    private let features: [Feature] = [
        Feature(title: "Frame Precision", symbol: "viewfinder"),
        Feature(title: "No Watermark", symbol: "drop"),
        Feature(title: "Instant Export", symbol: "square.and.arrow.up"),
    ]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HeaderBar()
                        .padding(.horizontal, 24)
                        .padding(.top, 24)

                    HeroCard()
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    VStack(spacing: 12) {
                        (Text("Precision Editing ")
                            + Text("in Your Pocket")
                            .foregroundColor(AppTheme.accentRed))
                            .font(.system(size: 32, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Import your clips and cut the clutter instantly. Trim videos in seconds, not minutes.")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)

                    FeatureGrid(features: features)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    Spacer(minLength: 24)

                    ActionButtons(onStartNewProject: onStartNewProject)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            onOpenHistory()
        }
    }
}

struct HomeScreen: View {
    var onStartNewProject: () -> Void = {}

    var body: some View {
        LauncherScreen(onStartNewProject: onStartNewProject)
    }
}

private struct HeaderBar: View {
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.accentRed)
                        .frame(width: 40, height: 40)
                        .shadow(color: AppTheme.neonLight.opacity(0.35), radius: 10, y: 6)

                    Image(systemName: "film")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                Text("SwiftCut")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "gearshape")
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.neonLight.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }
}

private struct HeroCard: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accentRed.opacity(0.25), AppTheme.heroBase],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.neonLight.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: AppTheme.neonLight.opacity(0.35), radius: 20, y: 12)

            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("REC")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Capsule())
                }
                .padding(16)

                Spacer()
            }

            ZStack {
                Circle()
                    .fill(AppTheme.neonLight.opacity(0.18))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(AppTheme.neonLight.opacity(0.45), lineWidth: 1))

                Image(systemName: "play.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .semibold))
                    .offset(x: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct FeatureGrid: View {
    let features: [Feature]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(features) { feature in
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentBlue.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: feature.symbol)
                            .foregroundColor(AppTheme.accentBlue)
                            .font(.system(size: 18, weight: .semibold))
                    }

                    Text(feature.title)
                        .font(.system(size: 11, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppTheme.textPrimary)
                        .textCase(.uppercase)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
            }
        }
    }
}

private struct ActionButtons: View {
    var onStartNewProject: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onStartNewProject) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("Start New Project")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.white)
                .background(
                    LinearGradient(
                        colors: [AppTheme.accentRed, AppTheme.neonLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: AppTheme.neonLight.opacity(0.4), radius: 16, y: 8)
            }
            .buttonStyle(PrimaryActionButtonStyle())

            Text("Developed in Cambodia 🇰🇭")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}

private struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private struct Feature: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
}

#Preview {
    LauncherScreen()
}
