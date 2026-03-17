#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNativePreviewView : UIView

@property (nonatomic, copy, nullable) void (^onDisplayTimeChange)(double seconds);
@property (nonatomic, copy, nullable) void (^onPlaybackStateChange)(BOOL playing);

- (void)setDesiredPlaybackState:(BOOL)playing;
- (void)seekToTimeSeconds:(double)seconds;
- (void)setPreviewDurationSeconds:(double)seconds;
- (void)updateCompositionVisualClipCount:(NSInteger)visualClipCount
                          audioClipCount:(NSInteger)audioClipCount
                     activeVisualSummary:(NSString * _Nullable)activeVisualSummary;
- (void)updateActiveTextOverlays:(NSArray<NSDictionary *> * _Nullable)overlays;
- (void)updateActiveVisualOverlays:(NSArray<NSDictionary *> * _Nullable)overlays;

@end

NS_ASSUME_NONNULL_END
