import Foundation
import CoreMedia
import Combine

protocol PlaybackEngineProtocol: AnyObject {
    var currentTime: CMTime { get }
    var isPlaying: Bool { get }
    var timePublisher: AnyPublisher<CMTime, Never> { get }

    func configure(frameRate: Int, duration: CMTime)
    func play()
    func pause()
    func stop()
    func seek(to time: CMTime)
    func stepForwardOneFrame()
    func stepBackwardOneFrame()
}

final class PlaybackEngine: PlaybackEngineProtocol {
    private(set) var currentTime: CMTime = .zero {
        didSet { timeSubject.send(currentTime) }
    }

    private(set) var isPlaying: Bool = false

    private var duration: CMTime = .zero
    private var frameRate: Int = 30
    private let timeSubject = CurrentValueSubject<CMTime, Never>(.zero)

    var timePublisher: AnyPublisher<CMTime, Never> {
        timeSubject.eraseToAnyPublisher()
    }

    func configure(frameRate: Int, duration: CMTime) {
        self.frameRate = Swift.max(frameRate, 1)
        self.duration = Swift.max(.zero, duration)
        currentTime = clamped(currentTime)
    }

    func play() {
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentTime = .zero
    }

    func seek(to time: CMTime) {
        currentTime = clamped(time)
    }

    func stepForwardOneFrame() {
        currentTime = clamped(currentTime + frameDuration)
    }

    func stepBackwardOneFrame() {
        currentTime = clamped(currentTime - frameDuration)
    }
}

private extension PlaybackEngine {
    var frameDuration: CMTime {
        CMTime(seconds: 1.0 / Double(frameRate), preferredTimescale: 600)
    }

    func clamped(_ time: CMTime) -> CMTime {
        if time < .zero {
            return .zero
        }
        if duration > .zero, time > duration {
            return duration
        }
        return time
    }
}
