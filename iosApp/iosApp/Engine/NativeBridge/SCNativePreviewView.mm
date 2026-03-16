#import "SCNativePreviewView.h"

#import <QuartzCore/QuartzCore.h>

#import "SwiftCutNativePreviewEngine.hpp"

@interface SCNativePreviewView ()

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *metricsLabel;
@property (nonatomic, strong) UILabel *activeLabel;
@property (nonatomic, strong, nullable) CADisplayLink *displayLink;
@property (nonatomic, weak, nullable) AVPlayer *previewPlayer;

@end

@implementation SCNativePreviewView {
    swiftcut::NativePreviewEngine _engine;
}

+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.blackColor;

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightSemibold];
        _statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        _statusLabel.layer.cornerRadius = 8.0;
        _statusLabel.layer.masksToBounds = YES;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.text = @"00:00.00";

        _metricsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _metricsLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _metricsLabel.textColor = UIColor.whiteColor;
        _metricsLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _metricsLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        _metricsLabel.layer.cornerRadius = 10.0;
        _metricsLabel.layer.masksToBounds = YES;
        _metricsLabel.textAlignment = NSTextAlignmentCenter;
        _metricsLabel.text = @"V:0 A:0";

        _activeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _activeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _activeLabel.textColor = UIColor.whiteColor;
        _activeLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        _activeLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
        _activeLabel.layer.cornerRadius = 10.0;
        _activeLabel.layer.masksToBounds = YES;
        _activeLabel.textAlignment = NSTextAlignmentCenter;
        _activeLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _activeLabel.text = @"No active layer";

        [self addSubview:_statusLabel];
        [self addSubview:_metricsLabel];
        [self addSubview:_activeLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_statusLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
            [_statusLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
            [_statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:82],
            [_statusLabel.heightAnchor constraintEqualToConstant:30],

            [_metricsLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_metricsLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:12],
            [_metricsLabel.widthAnchor constraintGreaterThanOrEqualToConstant:72],
            [_metricsLabel.heightAnchor constraintEqualToConstant:28],

            [_activeLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [_activeLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-72],
            [_activeLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12],
            [_activeLabel.heightAnchor constraintEqualToConstant:30],
        ]];

        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        [self startDisplayLinkIfNeeded];
    }
    return self;
}

- (void)dealloc {
    [_displayLink invalidate];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (void)setPreviewPlayer:(AVPlayer * _Nullable)player {
    _previewPlayer = player;
    self.playerLayer.player = player;
    [self startDisplayLinkIfNeeded];
}

- (void)updateCompositionVisualClipCount:(NSInteger)visualClipCount
                          audioClipCount:(NSInteger)audioClipCount
                     activeVisualSummary:(NSString * _Nullable)activeVisualSummary {
    _engine.setClipCounts((int)visualClipCount, (int)audioClipCount);
    _engine.setActiveVisualSummary(activeVisualSummary != nil ? std::string(activeVisualSummary.UTF8String) : std::string());

    [self refreshOverlayLabels];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window == nil) {
        [_displayLink invalidate];
        _displayLink = nil;
    } else {
        [self startDisplayLinkIfNeeded];
    }
}

- (void)startDisplayLinkIfNeeded {
    if (_displayLink != nil) {
        return;
    }

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDisplayLinkTick:)];
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)handleDisplayLinkTick:(CADisplayLink *)displayLink {
    AVPlayer *player = self.previewPlayer;
    if (player == nil) {
        _engine.setCurrentTimeSeconds(0.0);
        _engine.setPlaying(false);
        [self refreshOverlayLabels];
        return;
    }

    const CMTime time = player.currentTime;
    const double seconds = CMTIME_IS_NUMERIC(time) ? CMTimeGetSeconds(time) : 0.0;
    _engine.setCurrentTimeSeconds(seconds);
    _engine.setPlaying(player.rate > 0.0);

    [self refreshOverlayLabels];
}

- (void)refreshOverlayLabels {
    const swiftcut::PreviewFrameState state = _engine.currentState();
    self.statusLabel.text = [self.class formattedTime:state.currentTimeSeconds];
    self.metricsLabel.text = [NSString stringWithFormat:@"V:%d  A:%d%@", state.visualClipCount, state.audioClipCount, state.playing ? @"  PLAY" : @""];

    NSString *summary = state.activeVisualSummary.empty()
        ? @"No active layer"
        : [NSString stringWithUTF8String:state.activeVisualSummary.c_str()];
    self.activeLabel.text = [NSString stringWithFormat:@"%@", summary];
}


+ (NSString *)formattedTime:(double)seconds {
    NSInteger totalSeconds = (NSInteger)seconds;
    NSInteger minutes = totalSeconds / 60;
    NSInteger remainder = totalSeconds % 60;
    NSInteger centiseconds = (NSInteger)((seconds - floor(seconds)) * 100.0);
    return [NSString stringWithFormat:@"%02ld:%02ld.%02ld", (long)minutes, (long)remainder, (long)centiseconds];
}

@end
