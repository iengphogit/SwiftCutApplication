#include "SwiftCutNativeTimelineEngine.hpp"

#include <algorithm>
#include <sstream>

namespace swiftcut {

void NativeTimelineEngine::reset(const TimelineSettings &settings) {
    settings_ = settings;
    tracks_.clear();
}

void NativeTimelineEngine::setSettings(const TimelineSettings &settings) {
    settings_ = settings;
}

void NativeTimelineEngine::addTrack(const TimelineTrack &track) {
    tracks_.push_back(track);
    std::sort(
        tracks_.begin(),
        tracks_.end(),
        [](const TimelineTrack &lhs, const TimelineTrack &rhs) {
            return lhs.layer < rhs.layer;
        }
    );
}

bool NativeTimelineEngine::hasTrack(const std::string &trackId) const {
    return std::any_of(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) { return track.id == trackId; }
    );
}

bool NativeTimelineEngine::hasClip(const std::string &clipId) const {
    return std::any_of(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) {
            return std::any_of(
                track.clips.begin(),
                track.clips.end(),
                [&](const TimelineClip &clip) { return clip.id == clipId; }
            );
        }
    );
}

bool NativeTimelineEngine::addClip(const std::string &trackId, const TimelineClip &clip) {
    auto trackIt = std::find_if(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) { return track.id == trackId; }
    );
    if (trackIt == tracks_.end()) {
        return false;
    }

    trackIt->clips.push_back(clip);
    std::sort(
        trackIt->clips.begin(),
        trackIt->clips.end(),
        [](const TimelineClip &lhs, const TimelineClip &rhs) {
            return lhs.timelineRange.startSeconds < rhs.timelineRange.startSeconds;
        }
    );
    return true;
}

bool NativeTimelineEngine::removeClip(const std::string &clipId) {
    for (auto &track : tracks_) {
        auto clipIt = std::find_if(
            track.clips.begin(),
            track.clips.end(),
            [&](const TimelineClip &clip) { return clip.id == clipId; }
        );
        if (clipIt == track.clips.end()) {
            continue;
        }

        track.clips.erase(clipIt);
        return true;
    }

    return false;
}

bool NativeTimelineEngine::splitClip(
    const std::string &clipId,
    double splitTimeSeconds,
    std::string &newClipId
) {
    for (auto &track : tracks_) {
        auto clipIt = std::find_if(
            track.clips.begin(),
            track.clips.end(),
            [&](const TimelineClip &clip) { return clip.id == clipId; }
        );
        if (clipIt == track.clips.end()) {
            continue;
        }

        TimelineClip firstClip = *clipIt;
        if (splitTimeSeconds <= firstClip.timelineRange.startSeconds ||
            splitTimeSeconds >= firstClip.timelineRange.endSeconds()) {
            return false;
        }

        const double firstTimelineDuration = splitTimeSeconds - firstClip.timelineRange.startSeconds;
        const double secondTimelineDuration = firstClip.timelineRange.durationSeconds - firstTimelineDuration;
        const double sourceRatio = firstClip.timelineRange.durationSeconds <= 0.0
            ? 1.0
            : firstClip.sourceRange.durationSeconds / firstClip.timelineRange.durationSeconds;
        const double firstSourceDuration = firstTimelineDuration * sourceRatio;
        const double secondSourceDuration = firstClip.sourceRange.durationSeconds - firstSourceDuration;

        TimelineClip secondClip = firstClip;
        std::ostringstream idBuilder;
        idBuilder << firstClip.id << "-split-" << splitTimeSeconds;
        secondClip.id = idBuilder.str();
        newClipId = secondClip.id;

        firstClip.timelineRange.durationSeconds = firstTimelineDuration;
        firstClip.sourceRange.durationSeconds = firstSourceDuration;

        secondClip.timelineRange.startSeconds = splitTimeSeconds;
        secondClip.timelineRange.durationSeconds = secondTimelineDuration;
        secondClip.sourceRange.startSeconds = firstClip.sourceRange.startSeconds + firstSourceDuration;
        secondClip.sourceRange.durationSeconds = secondSourceDuration;

        *clipIt = firstClip;
        track.clips.push_back(secondClip);
        std::sort(
            track.clips.begin(),
            track.clips.end(),
            [](const TimelineClip &lhs, const TimelineClip &rhs) {
                return lhs.timelineRange.startSeconds < rhs.timelineRange.startSeconds;
            }
        );
        return true;
    }

    return false;
}

TimelineSnapshot NativeTimelineEngine::snapshot() const {
    TimelineSnapshot result;
    result.settings = settings_;
    result.tracks = tracks_;

    for (const auto &track : tracks_) {
        result.totalClipCount += static_cast<int>(track.clips.size());
        for (const auto &clip : track.clips) {
            result.durationSeconds = std::max(
                result.durationSeconds,
                clip.timelineRange.endSeconds()
            );
        }
    }

    return result;
}

}  // namespace swiftcut
