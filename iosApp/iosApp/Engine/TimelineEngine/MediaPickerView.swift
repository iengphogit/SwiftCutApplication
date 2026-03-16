import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

enum MediaPickerTarget {
    case video
    case audio
    case overlay

    var filter: PHPickerFilter {
        switch self {
        case .video, .audio, .overlay:
            return .videos
        }
    }
}

enum PickedMediaKind {
    case video
}

struct MediaPickerView: UIViewControllerRepresentable {
    let target: MediaPickerTarget
    let onMediaSelected: (URL, PickedMediaKind) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = 1
        configuration.filter = target.filter
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onMediaSelected: onMediaSelected)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onMediaSelected: (URL, PickedMediaKind) -> Void
        
        init(onMediaSelected: @escaping (URL, PickedMediaKind) -> Void) {
            self.onMediaSelected = onMediaSelected
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            let itemProvider = result.itemProvider
            
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                loadAndSaveVideo(from: itemProvider)
            }
        }
        
        private func loadAndSaveVideo(from itemProvider: NSItemProvider) {
            itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                guard let url = url else { return }
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("video_\(UUID().uuidString).mp4")
                
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    
                    DispatchQueue.main.async {
                        self?.onMediaSelected(tempURL, .video)
                    }
                } catch {
                    print("Error copying video: \(error)")
                }
            }
        }
        
    }
}
