#pragma once

#include <string>
#include <vector>

namespace swiftcut {

enum class TrackType {
    video,
    audio,
    text,
    overlay,
    effect,
};

struct TimeRange {
    double startSeconds = 0.0;
    double durationSeconds = 0.0;

    double endSeconds() const {
        return startSeconds + durationSeconds;
    }
};

struct TimelineClip {
    std::string id;
    std::string name;
    std::string sourcePath;
    TrackType type = TrackType::video;
    TimeRange sourceRange;
    TimeRange timelineRange;
    bool enabled = true;
    double speed = 1.0;
};

struct TimelineTrack {
    std::string id;
    std::string name;
    TrackType type = TrackType::video;
    int layer = 0;
    bool muted = false;
    bool locked = false;
    std::vector<TimelineClip> clips;
};

struct TimelineSettings {
    int canvasWidth = 1080;
    int canvasHeight = 1920;
    int frameRate = 30;
};

struct TimelineSnapshot {
    TimelineSettings settings;
    std::vector<TimelineTrack> tracks;
    int totalClipCount = 0;
    double durationSeconds = 0.0;
};

class NativeTimelineEngine {
public:
    NativeTimelineEngine() = default;

    void reset(const TimelineSettings &settings);
    void setSettings(const TimelineSettings &settings);
    void addTrack(const TimelineTrack &track);
    bool addClip(const std::string &trackId, const TimelineClip &clip);
    bool hasTrack(const std::string &trackId) const;
    bool hasClip(const std::string &clipId) const;
    bool removeClip(const std::string &clipId);
    bool splitClip(const std::string &clipId, double splitTimeSeconds, std::string &newClipId);

    TimelineSnapshot snapshot() const;

private:
    TimelineSettings settings_;
    std::vector<TimelineTrack> tracks_;
};

}  // namespace swiftcut
