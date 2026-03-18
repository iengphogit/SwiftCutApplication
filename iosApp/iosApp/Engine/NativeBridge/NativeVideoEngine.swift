import AVFoundation
import UIKit

protocol NativeVideoEngineProtocol {
    func thumbnail(for sourcePath: String) async -> UIImage?
    func thumbnailStrip(for sourcePath: String, durationSeconds: Double, frameCount: Int) async -> [UIImage]
    func prewarmSources(_ sourcePaths: [String]) async
}

actor NativeVideoEngine: NativeVideoEngineProtocol {
    static let shared = NativeVideoEngine()

    private let thumbnailCache = NSCache<NSString, UIImage>()
    private let thumbnailStripCache = NSCache<NSString, NSArray>()

    func thumbnail(for sourcePath: String) async -> UIImage? {
        guard !sourcePath.isEmpty else { return nil }

        let cacheKey = sourcePath as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        let image = await Task<UIImage?, Never>.detached(priority: .utility) {
            let asset = AVAsset(url: URL(fileURLWithPath: sourcePath))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true

            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }.value

        if let image {
            thumbnailCache.setObject(image, forKey: cacheKey)
        }
        return image
    }

    func thumbnailStrip(for sourcePath: String, durationSeconds: Double, frameCount: Int) async -> [UIImage] {
        guard !sourcePath.isEmpty else { return [] }

        let sanitizedFrameCount = max(frameCount, 1)
        let cacheKey = "\(sourcePath)#\(Int(durationSeconds * 100))#\(sanitizedFrameCount)" as NSString
        if let cached = thumbnailStripCache.object(forKey: cacheKey) as? [UIImage] {
            return cached
        }

        let generatedImages = await Task<[UIImage], Never>.detached(priority: .utility) {
            let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)

            let assetDuration = max(durationSeconds, 0.1)
            let times = (0..<sanitizedFrameCount).map { index -> CMTime in
                let progress = sanitizedFrameCount == 1
                    ? 0.0
                    : Double(index) / Double(sanitizedFrameCount - 1)
                let second = min(assetDuration * progress, max(assetDuration - 0.01, 0))
                return CMTime(seconds: second, preferredTimescale: 600)
            }

            var images: [UIImage] = []
            for time in times {
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    images.append(UIImage(cgImage: cgImage))
                }
            }
            return images
        }.value

        var resolvedImages = generatedImages
        if resolvedImages.isEmpty, let fallback = thumbnailCache.object(forKey: sourcePath as NSString) {
            resolvedImages = [fallback]
        } else if resolvedImages.isEmpty, let fallback = await thumbnail(for: sourcePath) {
            resolvedImages = [fallback]
        }

        thumbnailStripCache.setObject(resolvedImages as NSArray, forKey: cacheKey)
        return resolvedImages
    }

    func prewarmSources(_ sourcePaths: [String]) async {
        for sourcePath in Set(sourcePaths) where !sourcePath.isEmpty {
            _ = await thumbnail(for: sourcePath)
        }
    }
}
