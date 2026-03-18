#import "SCNativeTimelineBridge.h"

#import "../NativeCore/SwiftCutNativeTimelineEngine.hpp"

@implementation SCNativeTimelineBridge {
    swiftcut::NativeTimelineEngine _engine;
}

- (void)resetWithCanvasWidth:(NSInteger)canvasWidth
                canvasHeight:(NSInteger)canvasHeight
                   frameRate:(NSInteger)frameRate {
    swiftcut::TimelineSettings settings;
    settings.canvasWidth = (int)canvasWidth;
    settings.canvasHeight = (int)canvasHeight;
    settings.frameRate = (int)frameRate;
    _engine.reset(settings);
}

- (BOOL)hasTrackWithId:(NSString *)trackId {
    return _engine.hasTrack(trackId.UTF8String);
}

- (BOOL)hasClipWithId:(NSString *)clipId {
    return _engine.hasClip(clipId.UTF8String);
}

- (void)addTrackWithId:(NSString *)trackId
                  name:(NSString *)name
                  type:(NSString *)type
                 layer:(NSInteger)layer
                 muted:(BOOL)muted
                volume:(double)volume
                  solo:(BOOL)solo
                locked:(BOOL)locked {
    swiftcut::TimelineTrack track;
    track.id = trackId.UTF8String;
    track.name = name.UTF8String;
    track.type = [self trackTypeFromString:type];
    track.layer = (int)layer;
    track.muted = muted;
    track.volume = volume;
    track.solo = solo;
    track.locked = locked;
    _engine.addTrack(track);
}

- (BOOL)removeTrackWithId:(NSString *)trackId {
    return _engine.removeTrack(trackId.UTF8String);
}

- (BOOL)muteTrackWithId:(NSString *)trackId muted:(BOOL)muted {
    return _engine.setTrackMuted(trackId.UTF8String, muted);
}

- (BOOL)updateTrackVolumeWithId:(NSString *)trackId volume:(double)volume {
    return _engine.setTrackVolume(trackId.UTF8String, volume);
}

- (BOOL)updateTrackSoloWithId:(NSString *)trackId solo:(BOOL)solo {
    return _engine.setTrackSolo(trackId.UTF8String, solo);
}

- (BOOL)lockTrackWithId:(NSString *)trackId locked:(BOOL)locked {
    return _engine.setTrackLocked(trackId.UTF8String, locked);
}

- (BOOL)addClipToTrackWithId:(NSString *)trackId
                      clipId:(NSString *)clipId
                        name:(NSString *)name
                        type:(NSString *)type
                  sourcePath:(NSString * _Nullable)sourcePath
                 sourceStart:(double)sourceStart
              sourceDuration:(double)sourceDuration
               timelineStart:(double)timelineStart
            timelineDuration:(double)timelineDuration
                       speed:(double)speed
                      volume:(double)volume
                       muted:(BOOL)muted
                     enabled:(BOOL)enabled {
    swiftcut::TimelineClip clip;
    clip.id = clipId.UTF8String;
    clip.name = name.UTF8String;
    clip.type = [self trackTypeFromString:type];
    clip.sourcePath = sourcePath != nil ? sourcePath.UTF8String : "";
    clip.sourceRange.startSeconds = sourceStart;
    clip.sourceRange.durationSeconds = sourceDuration;
    clip.timelineRange.startSeconds = timelineStart;
    clip.timelineRange.durationSeconds = timelineDuration;
    clip.speed = speed;
    clip.volume = volume;
    clip.muted = muted;
    clip.enabled = enabled;
    return _engine.addClip(trackId.UTF8String, clip);
}

- (BOOL)removeClipWithId:(NSString *)clipId {
    return _engine.removeClip(clipId.UTF8String);
}

- (BOOL)rippleDeleteClipWithId:(NSString *)clipId {
    return _engine.rippleDeleteClip(clipId.UTF8String);
}

- (BOOL)moveClipWithId:(NSString *)clipId
    timelineStartSeconds:(double)timelineStartSeconds {
    return _engine.moveClip(clipId.UTF8String, timelineStartSeconds);
}

- (BOOL)trimClipWithId:(NSString *)clipId
    sourceStartSeconds:(double)sourceStartSeconds
  sourceDurationSeconds:(double)sourceDurationSeconds {
    return _engine.trimClip(
        clipId.UTF8String,
        sourceStartSeconds,
        sourceDurationSeconds
    );
}

- (BOOL)updateClipVolumeWithId:(NSString *)clipId volume:(double)volume {
    return _engine.setClipVolume(clipId.UTF8String, volume);
}

- (BOOL)updateClipMutedWithId:(NSString *)clipId muted:(BOOL)muted {
    return _engine.setClipMuted(clipId.UTF8String, muted);
}

- (NSString * _Nullable)splitClipWithId:(NSString *)clipId
                        splitTimeSeconds:(double)splitTimeSeconds {
    std::string newClipId;
    const bool didSplit = _engine.splitClip(clipId.UTF8String, splitTimeSeconds, newClipId);
    if (!didSplit || newClipId.empty()) {
        return nil;
    }
    return [NSString stringWithUTF8String:newClipId.c_str()];
}

- (BOOL)canUndo {
    return _engine.canUndo();
}

- (BOOL)canRedo {
    return _engine.canRedo();
}

- (BOOL)undo {
    return _engine.undo();
}

- (BOOL)redo {
    return _engine.redo();
}

- (NSDictionary<NSString *, id> *)snapshotDictionary {
    const swiftcut::TimelineSnapshot snapshot = _engine.snapshot();
    NSMutableArray<NSDictionary<NSString *, id> *> *tracks = [NSMutableArray array];

    for (const auto &track : snapshot.tracks) {
        NSMutableArray<NSDictionary<NSString *, id> *> *clips = [NSMutableArray array];
        for (const auto &clip : track.clips) {
            [clips addObject:@{
                @"id": [NSString stringWithUTF8String:clip.id.c_str()],
                @"name": [NSString stringWithUTF8String:clip.name.c_str()],
            @"type": [self stringFromTrackType:clip.type],
            @"sourceStart": @(clip.sourceRange.startSeconds),
            @"sourceDuration": @(clip.sourceRange.durationSeconds),
            @"timelineStart": @(clip.timelineRange.startSeconds),
            @"timelineDuration": @(clip.timelineRange.durationSeconds),
            @"volume": @(clip.volume),
            @"muted": @(clip.muted),
            @"sourcePath": clip.sourcePath.empty()
                ? @""
                : [NSString stringWithUTF8String:clip.sourcePath.c_str()]
            }];
        }

        [tracks addObject:@{
            @"id": [NSString stringWithUTF8String:track.id.c_str()],
            @"name": [NSString stringWithUTF8String:track.name.c_str()],
            @"type": [self stringFromTrackType:track.type],
            @"layer": @(track.layer),
            @"muted": @(track.muted),
            @"volume": @(track.volume),
            @"solo": @(track.solo),
            @"locked": @(track.locked),
            @"clips": clips
        }];
    }

    return @{
        @"canvasWidth": @(snapshot.settings.canvasWidth),
        @"canvasHeight": @(snapshot.settings.canvasHeight),
        @"frameRate": @(snapshot.settings.frameRate),
        @"trackCount": @(snapshot.tracks.size()),
        @"clipCount": @(snapshot.totalClipCount),
        @"durationSeconds": @(snapshot.durationSeconds),
        @"tracks": tracks
    };
}

- (swiftcut::TrackType)trackTypeFromString:(NSString *)type {
    if ([type isEqualToString:@"audio"]) {
        return swiftcut::TrackType::audio;
    }
    if ([type isEqualToString:@"text"]) {
        return swiftcut::TrackType::text;
    }
    if ([type isEqualToString:@"overlay"]) {
        return swiftcut::TrackType::overlay;
    }
    if ([type isEqualToString:@"effect"]) {
        return swiftcut::TrackType::effect;
    }
    return swiftcut::TrackType::video;
}

- (NSString *)stringFromTrackType:(swiftcut::TrackType)type {
    switch (type) {
        case swiftcut::TrackType::audio:
            return @"audio";
        case swiftcut::TrackType::text:
            return @"text";
        case swiftcut::TrackType::overlay:
            return @"overlay";
        case swiftcut::TrackType::effect:
            return @"effect";
        case swiftcut::TrackType::video:
        default:
            return @"video";
    }
}

@end
