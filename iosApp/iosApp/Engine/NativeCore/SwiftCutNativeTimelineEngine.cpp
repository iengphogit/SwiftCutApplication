#include "SwiftCutNativeTimelineEngine.hpp"

#include <algorithm>
#include <sstream>

namespace swiftcut {

void NativeTimelineEngine::reset(const TimelineSettings &settings) {
    settings_ = settings;
    tracks_.clear();
    undoStack_.clear();
    redoStack_.clear();
}

void NativeTimelineEngine::setSettings(const TimelineSettings &settings) {
    pushUndoState();
    settings_ = settings;
}

void NativeTimelineEngine::addTrack(const TimelineTrack &track) {
    pushUndoState();
    tracks_.push_back(track);
    std::sort(
        tracks_.begin(),
        tracks_.end(),
        [](const TimelineTrack &lhs, const TimelineTrack &rhs) {
            return lhs.layer < rhs.layer;
        }
    );
}

bool NativeTimelineEngine::removeTrack(const std::string &trackId) {
    auto trackIt = std::find_if(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) { return track.id == trackId; }
    );
    if (trackIt == tracks_.end()) {
        return false;
    }

    pushUndoState();
    tracks_.erase(trackIt);
    return true;
}

bool NativeTimelineEngine::setTrackMuted(const std::string &trackId, bool muted) {
    auto trackIt = std::find_if(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) { return track.id == trackId; }
    );
    if (trackIt == tracks_.end()) {
        return false;
    }

    pushUndoState();
    trackIt->muted = muted;
    return true;
}

bool NativeTimelineEngine::setTrackLocked(const std::string &trackId, bool locked) {
    auto trackIt = std::find_if(
        tracks_.begin(),
        tracks_.end(),
        [&](const TimelineTrack &track) { return track.id == trackId; }
    );
    if (trackIt == tracks_.end()) {
        return false;
    }

    pushUndoState();
    trackIt->locked = locked;
    return true;
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
    if (trackIt->locked || trackIt->type != clip.type) {
        return false;
    }

    TimelineClip resolvedClip = clip;
    resolvedClip.timelineRange.startSeconds = std::max(0.0, resolvedClip.timelineRange.startSeconds);

    auto sortedClips = trackIt->clips;
    std::sort(
        sortedClips.begin(),
        sortedClips.end(),
        [](const TimelineClip &lhs, const TimelineClip &rhs) {
            return lhs.timelineRange.startSeconds < rhs.timelineRange.startSeconds;
        }
    );

    for (const auto &existingClip : sortedClips) {
        const double candidateEnd =
            resolvedClip.timelineRange.startSeconds + resolvedClip.timelineRange.durationSeconds;
        const bool overlaps =
            resolvedClip.timelineRange.startSeconds < existingClip.timelineRange.endSeconds() &&
            candidateEnd > existingClip.timelineRange.startSeconds;

        if (overlaps) {
            resolvedClip.timelineRange.startSeconds = existingClip.timelineRange.endSeconds();
        }
    }

    pushUndoState();
    trackIt->clips.push_back(resolvedClip);
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
        if (track.locked) {
            return false;
        }

        pushUndoState();
        track.clips.erase(clipIt);
        return true;
    }

    return false;
}

bool NativeTimelineEngine::rippleDeleteClip(const std::string &clipId) {
    for (auto &track : tracks_) {
        auto clipIt = std::find_if(
            track.clips.begin(),
            track.clips.end(),
            [&](const TimelineClip &clip) { return clip.id == clipId; }
        );
        if (clipIt == track.clips.end()) {
            continue;
        }
        if (track.locked) {
            return false;
        }

        const double rippleStart = clipIt->timelineRange.endSeconds();
        const double rippleOffset = clipIt->timelineRange.durationSeconds;

        pushUndoState();
        track.clips.erase(clipIt);

        for (auto &candidateTrack : tracks_) {
            if (candidateTrack.locked) {
                continue;
            }

            for (auto &candidateClip : candidateTrack.clips) {
                if (candidateClip.timelineRange.startSeconds < rippleStart) {
                    continue;
                }
                candidateClip.timelineRange.startSeconds = std::max(
                    0.0,
                    candidateClip.timelineRange.startSeconds - rippleOffset
                );
            }

            std::sort(
                candidateTrack.clips.begin(),
                candidateTrack.clips.end(),
                [](const TimelineClip &lhs, const TimelineClip &rhs) {
                    return lhs.timelineRange.startSeconds < rhs.timelineRange.startSeconds;
                }
            );
        }

        return true;
    }

    return false;
}

bool NativeTimelineEngine::moveClip(const std::string &clipId, double timelineStartSeconds) {
    for (auto &track : tracks_) {
        auto clipIt = std::find_if(
            track.clips.begin(),
            track.clips.end(),
            [&](const TimelineClip &clip) { return clip.id == clipId; }
        );
        if (clipIt == track.clips.end()) {
            continue;
        }
        if (track.locked) {
            return false;
        }

        pushUndoState();
        clipIt->timelineRange.startSeconds = std::max(0.0, timelineStartSeconds);
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

bool NativeTimelineEngine::trimClip(
    const std::string &clipId,
    double sourceStartSeconds,
    double sourceDurationSeconds
) {
    if (sourceStartSeconds < 0.0 || sourceDurationSeconds <= 0.0) {
        return false;
    }

    for (auto &track : tracks_) {
        auto clipIt = std::find_if(
            track.clips.begin(),
            track.clips.end(),
            [&](const TimelineClip &clip) { return clip.id == clipId; }
        );
        if (clipIt == track.clips.end()) {
            continue;
        }
        if (track.locked) {
            return false;
        }

        pushUndoState();
        clipIt->sourceRange.startSeconds = sourceStartSeconds;
        clipIt->sourceRange.durationSeconds = sourceDurationSeconds;

        const double clampedSpeed = std::max(clipIt->speed, 0.1);
        clipIt->timelineRange.durationSeconds = clipIt->type == TrackType::video
            ? sourceDurationSeconds / clampedSpeed
            : sourceDurationSeconds;
        return clipIt->timelineRange.durationSeconds > 0.0;
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
        if (track.locked) {
            return false;
        }

        const double firstTimelineDuration = splitTimeSeconds - firstClip.timelineRange.startSeconds;
        const double secondTimelineDuration = firstClip.timelineRange.durationSeconds - firstTimelineDuration;
        const double sourceRatio = firstClip.timelineRange.durationSeconds <= 0.0
            ? 1.0
            : firstClip.sourceRange.durationSeconds / firstClip.timelineRange.durationSeconds;
        const double firstSourceDuration = firstTimelineDuration * sourceRatio;
        const double secondSourceDuration = firstClip.sourceRange.durationSeconds - firstSourceDuration;

        pushUndoState();
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
    return buildSnapshot();
}

bool NativeTimelineEngine::canUndo() const {
    return !undoStack_.empty();
}

bool NativeTimelineEngine::canRedo() const {
    return !redoStack_.empty();
}

bool NativeTimelineEngine::undo() {
    if (undoStack_.empty()) {
        return false;
    }

    redoStack_.push_back(buildSnapshot());
    const TimelineSnapshot snapshot = undoStack_.back();
    undoStack_.pop_back();
    settings_ = snapshot.settings;
    tracks_ = snapshot.tracks;
    return true;
}

bool NativeTimelineEngine::redo() {
    if (redoStack_.empty()) {
        return false;
    }

    undoStack_.push_back(buildSnapshot());
    const TimelineSnapshot snapshot = redoStack_.back();
    redoStack_.pop_back();
    settings_ = snapshot.settings;
    tracks_ = snapshot.tracks;
    return true;
}

void NativeTimelineEngine::pushUndoState() {
    undoStack_.push_back(buildSnapshot());
    redoStack_.clear();
}

TimelineSnapshot NativeTimelineEngine::buildSnapshot() const {
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
