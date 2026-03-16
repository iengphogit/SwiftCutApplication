#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCNativePreviewView : UIView

- (void)setPreviewPlayer:(AVPlayer * _Nullable)player;
- (void)updateCompositionVisualClipCount:(NSInteger)visualClipCount
                          audioClipCount:(NSInteger)audioClipCount
                     activeVisualSummary:(NSString * _Nullable)activeVisualSummary;

@end

NS_ASSUME_NONNULL_END
