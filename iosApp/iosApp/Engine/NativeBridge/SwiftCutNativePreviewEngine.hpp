#pragma once

#include <string>

namespace swiftcut {

struct PreviewFrameState {
    double currentTimeSeconds = 0.0;
    int visualClipCount = 0;
    int audioClipCount = 0;
    bool playing = false;
    std::string activeVisualSummary;
};

class NativePreviewEngine {
public:
    NativePreviewEngine() = default;

    void setCurrentTimeSeconds(double seconds);
    void setClipCounts(int visualClipCount, int audioClipCount);
    void setPlaying(bool playing);
    void setActiveVisualSummary(const std::string &summary);

    PreviewFrameState currentState() const;

private:
    PreviewFrameState state_;
};

}  // namespace swiftcut
