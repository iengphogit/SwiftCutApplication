import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(AppTheme.accentRed)
                        .frame(width: 72, height: 72)
                        .shadow(color: AppTheme.neonLight.opacity(0.4), radius: 16, y: 8)

                    Image(systemName: "film")
                        .foregroundColor(.white)
                        .font(.system(size: 28, weight: .bold))
                }

                Text("SwiftCut")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
    }
}

#Preview {
    SplashScreen()
}
