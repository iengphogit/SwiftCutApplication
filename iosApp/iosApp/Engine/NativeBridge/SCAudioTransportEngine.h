#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCAudioTransportEngine : NSObject

@property (nonatomic, assign, readonly, getter=isPlaying) BOOL playing;

- (void)setDesiredPlaybackState:(BOOL)playing;
- (void)seekToTimeSeconds:(double)seconds;
- (void)updateActiveAudioClips:(NSArray<NSDictionary *> * _Nullable)clips;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
