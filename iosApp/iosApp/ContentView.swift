import UIKit
import SwiftUI
import ComposeApp

struct ComposeView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        MainViewControllerKt.MainViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            ComposeView()
                .ignoresSafeArea()

            SharedScheduleHighlightView()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SharedScheduleHighlightView: View {
    private let facade = SharedScheduleModule.shared.facade()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared module on SwiftUI")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(facade.highlightHeadline(limit: 2))
                .font(.callout)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 12)
    }
}


