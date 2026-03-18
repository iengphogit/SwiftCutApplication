import AVFoundation
import CoreMedia
import Foundation

protocol WaveformAnalysisServing: Sendable {
    func waveformSamples(for sourcePath: String, targetBarCount: Int) async -> [CGFloat]
    func hasAudioTrack(for sourcePath: String) async -> Bool
}

actor WaveformAnalysisService: WaveformAnalysisServing {
    static let shared = WaveformAnalysisService()

    private let waveformCache = NSCache<NSString, NSArray>()
    private let audioPresenceCache = NSCache<NSString, NSNumber>()

    func waveformSamples(for sourcePath: String, targetBarCount: Int) async -> [CGFloat] {
        guard !sourcePath.isEmpty else { return [] }

        let resolvedBarCount = max(targetBarCount, 1)
        let cacheKey = "\(sourcePath)#waveform#\(resolvedBarCount)" as NSString
        if let cached = waveformCache.object(forKey: cacheKey) as? [NSNumber] {
            return cached.map { CGFloat(truncating: $0) }
        }

        let samples = Self.decodeWaveformSamples(
            sourcePath: sourcePath,
            targetBarCount: resolvedBarCount
        )
        waveformCache.setObject(samples.map { NSNumber(value: Double($0)) } as NSArray, forKey: cacheKey)
        return samples
    }

    func hasAudioTrack(for sourcePath: String) async -> Bool {
        guard !sourcePath.isEmpty else { return false }

        let cacheKey = sourcePath as NSString
        if let cached = audioPresenceCache.object(forKey: cacheKey) {
            return cached.boolValue
        }

        let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
        let hasAudio = !asset.tracks(withMediaType: .audio).isEmpty
        audioPresenceCache.setObject(NSNumber(value: hasAudio), forKey: cacheKey)
        return hasAudio
    }

    private static func decodeWaveformSamples(sourcePath: String, targetBarCount: Int) -> [CGFloat] {
        let asset = AVURLAsset(url: URL(fileURLWithPath: sourcePath))
        guard let track = asset.tracks(withMediaType: .audio).first,
              let reader = try? AVAssetReader(asset: asset) else {
            return []
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return [] }

        reader.add(output)
        guard reader.startReading() else { return [] }

        let stride = 1024
        var amplitudes: [Double] = []

        while let sampleBuffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            let bufferLength = CMBlockBufferGetDataLength(blockBuffer)
            var data = Data(repeating: 0, count: bufferLength)

            data.withUnsafeMutableBytes { bytes in
                guard let baseAddress = bytes.baseAddress else { return }
                CMBlockBufferCopyDataBytes(
                    blockBuffer,
                    atOffset: 0,
                    dataLength: bufferLength,
                    destination: baseAddress
                )
            }

            data.withUnsafeBytes { bytes in
                guard let samples = bytes.bindMemory(to: Int16.self).baseAddress else { return }
                let count = bufferLength / MemoryLayout<Int16>.size
                guard count > 0 else { return }

                var sampleIndex = 0
                while sampleIndex < count {
                    let chunkEnd = min(sampleIndex + stride, count)
                    var peak = 0.0
                    var sumSquares = 0.0

                    for index in sampleIndex..<chunkEnd {
                        let normalized = Double(samples[index]) / Double(Int16.max)
                        let amplitude = abs(normalized)
                        peak = max(peak, amplitude)
                        sumSquares += amplitude * amplitude
                    }

                    let chunkCount = Double(max(chunkEnd - sampleIndex, 1))
                    let rms = sqrt(sumSquares / chunkCount)
                    amplitudes.append(max(peak, rms))
                    sampleIndex = chunkEnd
                }
            }

            CMSampleBufferInvalidate(sampleBuffer)
        }

        guard !amplitudes.isEmpty else { return [] }

        var bucketPeaks = Array(repeating: 0.0, count: targetBarCount)
        var bucketCounts = Array(repeating: 0, count: targetBarCount)

        for (index, amplitude) in amplitudes.enumerated() {
            let progress = Double(index) / Double(max(amplitudes.count - 1, 1))
            let bucketIndex = min(Int(progress * Double(max(targetBarCount - 1, 0))), targetBarCount - 1)
            bucketPeaks[bucketIndex] = max(bucketPeaks[bucketIndex], amplitude)
            bucketCounts[bucketIndex] += 1
        }

        let peakAmplitude = bucketPeaks.max() ?? 0
        guard peakAmplitude > 0 else {
            return Array(repeating: 0, count: targetBarCount)
        }

        return bucketPeaks.enumerated().map { index, bucketPeak in
            guard bucketCounts[index] > 0 else { return 0 }
            return CGFloat(min(max(bucketPeak / peakAmplitude, 0), 1))
        }
    }
}
