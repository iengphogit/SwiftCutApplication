#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNativeTimelineBridge : NSObject

- (void)resetWithCanvasWidth:(NSInteger)canvasWidth
                canvasHeight:(NSInteger)canvasHeight
                   frameRate:(NSInteger)frameRate;
- (BOOL)hasTrackWithId:(NSString *)trackId;
- (BOOL)hasClipWithId:(NSString *)clipId;
- (void)addTrackWithId:(NSString *)trackId
                  name:(NSString *)name
                  type:(NSString *)type
                 layer:(NSInteger)layer
                 muted:(BOOL)muted
                volume:(double)volume
                  solo:(BOOL)solo
                locked:(BOOL)locked;
- (BOOL)removeTrackWithId:(NSString *)trackId;
- (BOOL)muteTrackWithId:(NSString *)trackId muted:(BOOL)muted;
- (BOOL)updateTrackVolumeWithId:(NSString *)trackId volume:(double)volume;
- (BOOL)updateTrackSoloWithId:(NSString *)trackId solo:(BOOL)solo;
- (BOOL)lockTrackWithId:(NSString *)trackId locked:(BOOL)locked;
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
                     enabled:(BOOL)enabled;
- (BOOL)removeClipWithId:(NSString *)clipId;
- (BOOL)rippleDeleteClipWithId:(NSString *)clipId;
- (BOOL)moveClipWithId:(NSString *)clipId
    timelineStartSeconds:(double)timelineStartSeconds;
- (BOOL)trimClipWithId:(NSString *)clipId
    sourceStartSeconds:(double)sourceStartSeconds
  sourceDurationSeconds:(double)sourceDurationSeconds;
- (BOOL)updateClipVolumeWithId:(NSString *)clipId volume:(double)volume;
- (BOOL)updateClipMutedWithId:(NSString *)clipId muted:(BOOL)muted;
- (NSString * _Nullable)splitClipWithId:(NSString *)clipId
                        splitTimeSeconds:(double)splitTimeSeconds;
- (BOOL)canUndo;
- (BOOL)canRedo;
- (BOOL)undo;
- (BOOL)redo;
- (NSDictionary<NSString *, id> *)snapshotDictionary;

@end

NS_ASSUME_NONNULL_END
