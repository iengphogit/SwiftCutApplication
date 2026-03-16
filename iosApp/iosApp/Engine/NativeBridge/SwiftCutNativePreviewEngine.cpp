#include "SwiftCutNativePreviewEngine.hpp"

namespace swiftcut {

void NativePreviewEngine::setCurrentTimeSeconds(double seconds) {
    state_.currentTimeSeconds = seconds;
}

void NativePreviewEngine::setClipCounts(int visualClipCount, int audioClipCount) {
    state_.visualClipCount = visualClipCount;
    state_.audioClipCount = audioClipCount;
}

void NativePreviewEngine::setPlaying(bool playing) {
    state_.playing = playing;
}

void NativePreviewEngine::setActiveVisualSummary(const std::string &summary) {
    state_.activeVisualSummary = summary;
}

PreviewFrameState NativePreviewEngine::currentState() const {
    return state_;
}

}  // namespace swiftcut
