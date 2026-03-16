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
                locked:(BOOL)locked;
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
                     enabled:(BOOL)enabled;
- (BOOL)removeClipWithId:(NSString *)clipId;
- (NSString * _Nullable)splitClipWithId:(NSString *)clipId
                        splitTimeSeconds:(double)splitTimeSeconds;
- (NSDictionary<NSString *, id> *)snapshotDictionary;

@end

NS_ASSUME_NONNULL_END
