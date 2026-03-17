#import "SCNativePreviewView.h"

#import <CoreImage/CoreImage.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#import "SwiftCutNativePreviewEngine.hpp"

@interface SCNativePreviewView ()

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *metricsLabel;
@property (nonatomic, strong) UILabel *activeLabel;
@property (nonatomic, strong) NSMutableArray<UILabel *> *textOverlayLabels;
@property (nonatomic, strong) NSMutableArray<CALayer *> *visualGuideLayers;
@property (nonatomic, strong) CALayer *baseVideoLayer;
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVAudioPlayerNode *> *audioNodes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVAudioFile *> *audioFiles;
@property (nonatomic, copy) NSArray<NSDictionary *> *activeAudioClips;
@property (nonatomic, copy) NSString *activeAudioSignature;
@property (nonatomic, strong, nullable) CADisplayLink *displayLink;
@property (nonatomic, assign) double previewDurationSeconds;
@property (nonatomic, assign) double currentTimeSeconds;
@property (nonatomic, assign) BOOL desiredPlaying;
@property (nonatomic, assign) CFTimeInterval lastDisplayLinkTimestamp;
@property (nonatomic, assign) BOOL hasReportedPlaybackState;
@property (nonatomic, assign) BOOL lastReportedPlaybackState;

@end

@implementation SCNativePreviewView {
    swiftcut::NativePreviewEngine _engine;
    NSUInteger _visualGeneration;
    dispatch_queue_t _thumbnailQueue;
}

static const void *kSCContentSourcePathKey = &kSCContentSourcePathKey;
static const void *kSCContentBaseSourceTimeKey = &kSCContentBaseSourceTimeKey;
static const void *kSCContentFrameTimelineTimeKey = &kSCContentFrameTimelineTimeKey;
static const void *kSCContentGenerationKey = &kSCContentGenerationKey;

static NSString *SCContentsGravityForScaleMode(NSString *scaleMode) {
    if ([scaleMode isEqualToString:@"fill"]) {
        return kCAGravityResizeAspectFill;
    }
    if ([scaleMode isEqualToString:@"stretch"]) {
        return kCAGravityResize;
    }
    return kCAGravityResizeAspect;
}

+ (Class)layerClass {
    return [CALayer class];
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
        _textOverlayLabels = [NSMutableArray array];
        _visualGuideLayers = [NSMutableArray array];
        _audioNodes = [NSMutableDictionary dictionary];
        _audioFiles = [NSMutableDictionary dictionary];
        _activeAudioClips = @[];
        _activeAudioSignature = @"";
        _thumbnailQueue = dispatch_queue_create("space.iengpho.swiftcut.preview.thumbnail", DISPATCH_QUEUE_SERIAL);
        _baseVideoLayer = [CALayer layer];
        _baseVideoLayer.contentsGravity = kCAGravityResizeAspect;
        _baseVideoLayer.frame = self.bounds;
        _baseVideoLayer.hidden = YES;
        _previewDurationSeconds = 0.0;
        _currentTimeSeconds = 0.0;
        _desiredPlaying = NO;
        _lastDisplayLinkTimestamp = 0.0;
        _hasReportedPlaybackState = NO;
        _lastReportedPlaybackState = NO;

        [self.layer addSublayer:_baseVideoLayer];

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

        [self startDisplayLinkIfNeeded];
    }
    return self;
}

- (void)dealloc {
    [self stopAndResetAudioNodes];
    [_audioEngine stop];
    [_displayLink invalidate];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.baseVideoLayer.frame = self.bounds;
}

- (void)setDesiredPlaybackState:(BOOL)playing {
    if (self.desiredPlaying == playing) {
        return;
    }

    self.desiredPlaying = playing;
    if (!playing) {
        self.lastDisplayLinkTimestamp = 0.0;
        [self pauseAudioNodes];
    } else if (self.activeAudioClips.count > 0) {
        [self synchronizeAudioTransport];
    }

    [self notifyPlaybackStateIfNeeded];
}

- (void)seekToTimeSeconds:(double)seconds {
    self.currentTimeSeconds = [self clampedTimeSeconds:seconds];
    self.lastDisplayLinkTimestamp = 0.0;
    [self synchronizeAudioTransport];
    [self updateBaseVideoFrameForDisplayTimeSeconds:self.currentTimeSeconds];
    [self updateOverlayContentLayersForDisplayTimeSeconds:self.currentTimeSeconds generation:_visualGeneration];
    if (self.onDisplayTimeChange != nil) {
        double currentTimeSeconds = self.currentTimeSeconds;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onDisplayTimeChange != nil) {
                self.onDisplayTimeChange(currentTimeSeconds);
            }
        });
    }
    [self refreshOverlayLabels];
}

- (void)setPreviewDurationSeconds:(double)seconds {
    const double clampedDurationSeconds = MAX(seconds, 0.0);
    if (_previewDurationSeconds == clampedDurationSeconds) {
        return;
    }

    _previewDurationSeconds = clampedDurationSeconds;
    self.currentTimeSeconds = [self clampedTimeSeconds:self.currentTimeSeconds];
}

- (void)updateCompositionVisualClipCount:(NSInteger)visualClipCount
                          audioClipCount:(NSInteger)audioClipCount
                     activeVisualSummary:(NSString * _Nullable)activeVisualSummary {
    _engine.setClipCounts((int)visualClipCount, (int)audioClipCount);
    _engine.setActiveVisualSummary(activeVisualSummary != nil ? std::string(activeVisualSummary.UTF8String) : std::string());

    [self refreshOverlayLabels];
}

- (void)updateActiveTextOverlays:(NSArray<NSDictionary *> * _Nullable)overlays {
    for (UILabel *label in self.textOverlayLabels) {
        [label removeFromSuperview];
    }
    [self.textOverlayLabels removeAllObjects];

    if (overlays.count == 0) {
        return;
    }

    for (NSDictionary *overlay in overlays) {
        NSString *text = overlay[@"text"];
        if (text.length == 0) {
            continue;
        }

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.translatesAutoresizingMaskIntoConstraints = YES;
        label.text = text;
        label.numberOfLines = 0;
        label.textAlignment = [self.class textAlignmentFromString:overlay[@"alignment"]];
        CGFloat fontSize = overlay[@"fontSize"] != nil ? [overlay[@"fontSize"] doubleValue] : 24.0;
        label.font = [UIFont fontWithName:overlay[@"fontName"] ?: @"Helvetica-Bold"
                                     size:fontSize] ?: [UIFont boldSystemFontOfSize:24.0];
        label.textColor = [self.class colorFromHexString:overlay[@"textColorHex"] fallback:UIColor.whiteColor];
        label.backgroundColor = [self.class colorFromHexString:overlay[@"backgroundColorHex"] fallback:UIColor.clearColor];
        label.layer.cornerRadius = 4.0;
        label.layer.masksToBounds = YES;
        label.layer.shadowColor = [self.class colorFromHexString:overlay[@"shadowColorHex"] fallback:UIColor.clearColor].CGColor;
        label.layer.shadowOffset = CGSizeMake([overlay[@"shadowOffsetX"] doubleValue], [overlay[@"shadowOffsetY"] doubleValue]);
        label.layer.shadowOpacity = 1.0;
        label.layer.shadowRadius = [overlay[@"shadowBlur"] doubleValue];
        label.layer.masksToBounds = NO;

        CGFloat width = MIN(CGRectGetWidth(self.bounds) - 24.0, 220.0);
        CGSize fitSize = [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
        CGFloat normalizedX = [overlay[@"normalizedX"] doubleValue];
        CGFloat normalizedY = [overlay[@"normalizedY"] doubleValue];
        CGFloat x = normalizedX * CGRectGetWidth(self.bounds);
        CGFloat y = normalizedY * CGRectGetHeight(self.bounds);
        label.frame = CGRectMake(
            x - fitSize.width / 2.0,
            y - fitSize.height / 2.0,
            fitSize.width + 12.0,
            fitSize.height + 8.0
        );

        [self addSubview:label];
        [self.textOverlayLabels addObject:label];
    }
}

- (void)updateActiveVisualOverlays:(NSArray<NSDictionary *> * _Nullable)overlays {
    _visualGeneration += 1;
    const NSUInteger generation = _visualGeneration;
    BOOL rendersPrimaryVideo = NO;
    self.baseVideoLayer.contents = nil;

    for (CALayer *layer in self.visualGuideLayers) {
        [layer removeFromSuperlayer];
    }
    [self.visualGuideLayers removeAllObjects];

    if (overlays.count == 0) {
        return;
    }

    for (NSDictionary *overlay in overlays) {
        NSString *kind = overlay[@"kind"];
        if (kind.length == 0) {
            continue;
        }
        if ([kind isEqualToString:@"video"] && [overlay[@"renderContent"] boolValue]) {
            rendersPrimaryVideo = YES;
        }

        CGFloat normalizedX = [overlay[@"normalizedX"] doubleValue];
        CGFloat normalizedY = [overlay[@"normalizedY"] doubleValue];
        CGFloat scaleX = MAX([overlay[@"scaleX"] doubleValue], 0.2);
        CGFloat scaleY = MAX([overlay[@"scaleY"] doubleValue], 0.2);
        CGFloat opacity = overlay[@"opacity"] != nil ? [overlay[@"opacity"] doubleValue] : 1.0;
        CGFloat rotationRadians = [overlay[@"rotationDegrees"] doubleValue] * M_PI / 180.0;

        CGSize baseSize = [kind isEqualToString:@"overlay"]
            ? CGSizeMake(CGRectGetWidth(self.bounds) * 0.28, CGRectGetHeight(self.bounds) * 0.22)
            : CGSizeMake(CGRectGetWidth(self.bounds) * 0.78, CGRectGetHeight(self.bounds) * 0.78);
        CGSize size = CGSizeMake(baseSize.width * scaleX, baseSize.height * scaleY);
        CGPoint center = CGPointMake(normalizedX * CGRectGetWidth(self.bounds), normalizedY * CGRectGetHeight(self.bounds));

        CALayer *guideLayer = [CALayer layer];
        guideLayer.bounds = CGRectMake(0, 0, size.width, size.height);
        guideLayer.position = center;
        guideLayer.opacity = MIN(MAX(opacity, 0.25), 1.0);
        guideLayer.borderWidth = [kind isEqualToString:@"overlay"] ? 2.0 : 1.5;
        guideLayer.borderColor = [kind isEqualToString:@"overlay"]
            ? [[UIColor colorWithRed:0.72 green:0.48 blue:0.95 alpha:0.95] CGColor]
            : [[UIColor colorWithWhite:1.0 alpha:0.75] CGColor];
        guideLayer.backgroundColor = [kind isEqualToString:@"overlay"]
            ? [[UIColor colorWithRed:0.72 green:0.48 blue:0.95 alpha:0.10] CGColor]
            : [[UIColor colorWithWhite:1.0 alpha:0.05] CGColor];
        guideLayer.cornerRadius = 0.0;
        guideLayer.transform = CATransform3DMakeRotation(rotationRadians, 0, 0, 1);

        CAShapeLayer *crosshair = [CAShapeLayer layer];
        crosshair.frame = guideLayer.bounds;
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path moveToPoint:CGPointMake(CGRectGetMidX(guideLayer.bounds), 0)];
        [path addLineToPoint:CGPointMake(CGRectGetMidX(guideLayer.bounds), CGRectGetHeight(guideLayer.bounds))];
        [path moveToPoint:CGPointMake(0, CGRectGetMidY(guideLayer.bounds))];
        [path addLineToPoint:CGPointMake(CGRectGetWidth(guideLayer.bounds), CGRectGetMidY(guideLayer.bounds))];
        crosshair.path = path.CGPath;
        crosshair.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
        crosshair.lineWidth = 1.0;
        crosshair.lineDashPattern = @[ @4, @4 ];
        [guideLayer addSublayer:crosshair];

        NSNumber *cropX = overlay[@"cropX"];
        NSNumber *cropY = overlay[@"cropY"];
        NSNumber *cropWidth = overlay[@"cropWidth"];
        NSNumber *cropHeight = overlay[@"cropHeight"];
        CGRect normalizedCropRect = CGRectNull;
        if (cropX != nil && cropY != nil && cropWidth != nil && cropHeight != nil) {
            CGFloat normalizedCropX = MIN(MAX(cropX.doubleValue, 0.0), 1.0);
            CGFloat normalizedCropY = MIN(MAX(cropY.doubleValue, 0.0), 1.0);
            CGFloat normalizedCropWidth = MIN(MAX(cropWidth.doubleValue, 0.0), 1.0);
            CGFloat normalizedCropHeight = MIN(MAX(cropHeight.doubleValue, 0.0), 1.0);

            if (normalizedCropWidth > 0.0 && normalizedCropHeight > 0.0) {
                normalizedCropRect = CGRectMake(
                    normalizedCropX,
                    normalizedCropY,
                    normalizedCropWidth,
                    normalizedCropHeight
                );
                CAShapeLayer *cropLayer = [CAShapeLayer layer];
                cropLayer.frame = guideLayer.bounds;
                CGRect cropBounds = CGRectMake(
                    CGRectGetMinX(normalizedCropRect) * CGRectGetWidth(guideLayer.bounds),
                    CGRectGetMinY(normalizedCropRect) * CGRectGetHeight(guideLayer.bounds),
                    CGRectGetWidth(normalizedCropRect) * CGRectGetWidth(guideLayer.bounds),
                    CGRectGetHeight(normalizedCropRect) * CGRectGetHeight(guideLayer.bounds)
                );
                cropLayer.path = [UIBezierPath bezierPathWithRect:cropBounds].CGPath;
                cropLayer.strokeColor = [UIColor colorWithRed:1.0 green:0.92 blue:0.45 alpha:0.95].CGColor;
                cropLayer.fillColor = UIColor.clearColor.CGColor;
                cropLayer.lineWidth = 1.5;
                cropLayer.lineDashPattern = @[ @6, @3 ];
                [guideLayer addSublayer:cropLayer];
            }
        }

        CATextLayer *opacityLayer = [CATextLayer layer];
        opacityLayer.contentsScale = UIScreen.mainScreen.scale;
        opacityLayer.alignmentMode = kCAAlignmentCenter;
        opacityLayer.foregroundColor = UIColor.whiteColor.CGColor;
        opacityLayer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55].CGColor;
        opacityLayer.fontSize = 10.0;
        opacityLayer.cornerRadius = 4.0;
        opacityLayer.frame = CGRectMake(6.0, 6.0, 50.0, 16.0);
        opacityLayer.string = [NSString stringWithFormat:@"%.0f%%", opacity * 100.0];
        [guideLayer addSublayer:opacityLayer];

        NSString *sourcePath = overlay[@"sourcePath"];
        NSString *scaleMode = overlay[@"scaleMode"];
        BOOL renderContent = [overlay[@"renderContent"] boolValue];
        NSNumber *sourceTimeSeconds = overlay[@"sourceTimeSeconds"];
        NSNumber *frameTimelineTimeSeconds = overlay[@"frameTimelineTimeSeconds"];
        if ([kind isEqualToString:@"video"] && renderContent && sourcePath.length > 0 && sourceTimeSeconds != nil) {
            objc_setAssociatedObject(self.baseVideoLayer, kSCContentSourcePathKey, sourcePath, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(self.baseVideoLayer, kSCContentBaseSourceTimeKey, sourceTimeSeconds, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(
                self.baseVideoLayer,
                kSCContentFrameTimelineTimeKey,
                frameTimelineTimeSeconds != nil ? frameTimelineTimeSeconds : sourceTimeSeconds,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            objc_setAssociatedObject(
                self.baseVideoLayer,
                kSCContentGenerationKey,
                @(generation),
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            [self updateBaseVideoFrameForDisplayTimeSeconds:self.currentTimeSeconds];
            [self prefetchNearbyThumbnailsForSourcePath:sourcePath sourceTimeSeconds:sourceTimeSeconds.doubleValue];
        }
        if (renderContent && sourcePath.length > 0 && sourceTimeSeconds != nil) {
            CALayer *contentLayer = [CALayer layer];
            contentLayer.frame = guideLayer.bounds;
            contentLayer.contentsGravity = SCContentsGravityForScaleMode(scaleMode);
            contentLayer.masksToBounds = YES;
            contentLayer.name = @"visual-content";
            if (!CGRectIsNull(normalizedCropRect)) {
                contentLayer.contentsRect = normalizedCropRect;
            }
            objc_setAssociatedObject(contentLayer, kSCContentSourcePathKey, sourcePath, OBJC_ASSOCIATION_COPY_NONATOMIC);
            objc_setAssociatedObject(contentLayer, kSCContentBaseSourceTimeKey, sourceTimeSeconds, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(
                contentLayer,
                kSCContentFrameTimelineTimeKey,
                frameTimelineTimeSeconds != nil ? frameTimelineTimeSeconds : sourceTimeSeconds,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            objc_setAssociatedObject(
                contentLayer,
                kSCContentGenerationKey,
                @(generation),
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            [guideLayer insertSublayer:contentLayer atIndex:0];
            [self loadThumbnailForSourcePath:sourcePath
                           sourceTimeSeconds:sourceTimeSeconds.doubleValue
                                   intoLayer:contentLayer
                                  generation:generation];
            [self prefetchNearbyThumbnailsForSourcePath:sourcePath sourceTimeSeconds:sourceTimeSeconds.doubleValue];
        }

        [self.layer addSublayer:guideLayer];
        [self.visualGuideLayers addObject:guideLayer];
    }

    if (!rendersPrimaryVideo) {
        self.baseVideoLayer.contents = nil;
    }
    self.baseVideoLayer.hidden = !rendersPrimaryVideo;
}

- (void)updateActiveAudioClips:(NSArray<NSDictionary *> * _Nullable)clips {
    NSArray<NSDictionary *> *payloads = clips ?: @[];
    NSString *signature = [self.class audioSignatureForPayloads:payloads];
    BOOL didChange = ![signature isEqualToString:self.activeAudioSignature];
    self.activeAudioClips = payloads;
    self.activeAudioSignature = signature;

    if (didChange || payloads.count == 0) {
        [self synchronizeAudioTransport];
    }
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
    if (self.desiredPlaying) {
        CFTimeInterval timestamp = 0;
        if (@available(iOS 15.0, *)) {
            timestamp = displayLink.targetTimestamp;
        } else {
            timestamp = displayLink.timestamp + displayLink.duration;
        }

        if (self.lastDisplayLinkTimestamp > 0.0) {
            self.currentTimeSeconds = [self clampedTimeSeconds:
                self.currentTimeSeconds + (timestamp - self.lastDisplayLinkTimestamp)
            ];
            if (self.previewDurationSeconds > 0.0 && self.currentTimeSeconds >= self.previewDurationSeconds) {
                self.currentTimeSeconds = self.previewDurationSeconds;
                self.desiredPlaying = NO;
                [self pauseAudioNodes];
            }
        }
        self.lastDisplayLinkTimestamp = timestamp;
    } else {
        self.lastDisplayLinkTimestamp = 0.0;
    }

    _engine.setCurrentTimeSeconds(self.currentTimeSeconds);
    _engine.setPlaying(self.desiredPlaying);
    [self updateBaseVideoFrameForDisplayTimeSeconds:self.currentTimeSeconds];
    [self updateOverlayContentLayersForDisplayTimeSeconds:self.currentTimeSeconds generation:_visualGeneration];
    if (self.onDisplayTimeChange != nil) {
        double currentTimeSeconds = self.currentTimeSeconds;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.onDisplayTimeChange != nil) {
                self.onDisplayTimeChange(currentTimeSeconds);
            }
        });
    }
    [self notifyPlaybackStateIfNeeded];

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

- (void)notifyPlaybackStateIfNeeded {
    if (self.hasReportedPlaybackState && self.lastReportedPlaybackState == self.desiredPlaying) {
        return;
    }

    self.hasReportedPlaybackState = YES;
    self.lastReportedPlaybackState = self.desiredPlaying;

    if (self.onPlaybackStateChange == nil) {
        return;
    }

    BOOL desiredPlaying = self.desiredPlaying;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onPlaybackStateChange != nil) {
            self.onPlaybackStateChange(desiredPlaying);
        }
    });
}


+ (NSString *)formattedTime:(double)seconds {
    if (!isfinite(seconds) || seconds < 0.0) {
        seconds = 0.0;
    }
    NSInteger totalSeconds = (NSInteger)seconds;
    NSInteger minutes = totalSeconds / 60;
    NSInteger remainder = totalSeconds % 60;
    NSInteger centiseconds = (NSInteger)((seconds - floor(seconds)) * 100.0);
    return [NSString stringWithFormat:@"%02ld:%02ld.%02ld", (long)minutes, (long)remainder, (long)centiseconds];
}

+ (UIColor *)colorFromHexString:(NSString * _Nullable)hexString fallback:(UIColor *)fallback {
    if (hexString.length == 0) {
        return fallback;
    }

    NSString *clean = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if (clean.length != 6) {
        return fallback;
    }

    unsigned int rgbValue = 0;
    [[NSScanner scannerWithString:clean] scanHexInt:&rgbValue];
    return [UIColor colorWithRed:((rgbValue & 0xFF0000) >> 16) / 255.0
                           green:((rgbValue & 0x00FF00) >> 8) / 255.0
                            blue:(rgbValue & 0x0000FF) / 255.0
                           alpha:1.0];
}

+ (NSTextAlignment)textAlignmentFromString:(NSString * _Nullable)alignment {
    if ([alignment isEqualToString:@"left"]) {
        return NSTextAlignmentLeft;
    }
    if ([alignment isEqualToString:@"right"]) {
        return NSTextAlignmentRight;
    }
    return NSTextAlignmentCenter;
}

- (void)updateBaseVideoFrameForDisplayTimeSeconds:(double)displayTimeSeconds {
    NSString *sourcePath = objc_getAssociatedObject(self.baseVideoLayer, kSCContentSourcePathKey);
    NSNumber *baseSourceTime = objc_getAssociatedObject(self.baseVideoLayer, kSCContentBaseSourceTimeKey);
    NSNumber *frameTimelineTime = objc_getAssociatedObject(self.baseVideoLayer, kSCContentFrameTimelineTimeKey);
    NSNumber *generation = objc_getAssociatedObject(self.baseVideoLayer, kSCContentGenerationKey);
    if (
        self.baseVideoLayer.hidden ||
        sourcePath.length == 0 ||
        baseSourceTime == nil ||
        frameTimelineTime == nil ||
        generation == nil
    ) {
        return;
    }

    const double timelineDelta = displayTimeSeconds - frameTimelineTime.doubleValue;
    if (!isfinite(timelineDelta) || !isfinite(baseSourceTime.doubleValue)) {
        return;
    }
    const double sourceTimeSeconds = MAX(0.0, baseSourceTime.doubleValue + timelineDelta);
    [self loadThumbnailForSourcePath:sourcePath
                   sourceTimeSeconds:sourceTimeSeconds
                           intoLayer:self.baseVideoLayer
                          generation:generation.unsignedIntegerValue];
    [self prefetchNearbyThumbnailsForSourcePath:sourcePath sourceTimeSeconds:sourceTimeSeconds];
}

- (void)updateOverlayContentLayersForDisplayTimeSeconds:(double)displayTimeSeconds generation:(NSUInteger)generation {
    for (CALayer *guideLayer in self.visualGuideLayers) {
        for (CALayer *sublayer in guideLayer.sublayers) {
            if (![sublayer.name isEqualToString:@"visual-content"]) {
                continue;
            }

            NSNumber *storedGeneration = objc_getAssociatedObject(sublayer, kSCContentGenerationKey);
            if (storedGeneration != nil && storedGeneration.unsignedIntegerValue != generation) {
                continue;
            }

            NSString *sourcePath = objc_getAssociatedObject(sublayer, kSCContentSourcePathKey);
            NSNumber *baseSourceTime = objc_getAssociatedObject(sublayer, kSCContentBaseSourceTimeKey);
            NSNumber *frameTimelineTime = objc_getAssociatedObject(sublayer, kSCContentFrameTimelineTimeKey);
            if (sourcePath.length == 0 || baseSourceTime == nil || frameTimelineTime == nil) {
                continue;
            }

            const double timelineDelta = displayTimeSeconds - frameTimelineTime.doubleValue;
            if (!isfinite(timelineDelta) || !isfinite(baseSourceTime.doubleValue)) {
                continue;
            }
            const double sourceTimeSeconds = MAX(0.0, baseSourceTime.doubleValue + timelineDelta);
            [self loadThumbnailForSourcePath:sourcePath
                           sourceTimeSeconds:sourceTimeSeconds
                                   intoLayer:sublayer
                                  generation:generation];
        }
    }
}

- (double)clampedTimeSeconds:(double)seconds {
    if (!isfinite(seconds)) {
        return 0.0;
    }

    const double lowerBound = MAX(seconds, 0.0);
    if (self.previewDurationSeconds <= 0.0) {
        return lowerBound;
    }
    return MIN(lowerBound, self.previewDurationSeconds);
}

- (void)synchronizeAudioTransport {
    [self stopAndResetAudioNodes];

    if (self.activeAudioClips.count == 0) {
        return;
    }

    if (![self ensureAudioEngineStarted]) {
        return;
    }

    for (NSDictionary *clip in self.activeAudioClips) {
        NSString *clipId = clip[@"clipId"];
        NSString *sourcePath = clip[@"sourcePath"];
        NSNumber *sourceTimeSeconds = clip[@"sourceTimeSeconds"];
        NSNumber *remainingDurationSeconds = clip[@"remainingDurationSeconds"];
        NSNumber *volume = clip[@"volume"];
        NSNumber *muted = clip[@"muted"];

        if (
            clipId.length == 0 ||
            sourcePath.length == 0 ||
            sourceTimeSeconds == nil ||
            remainingDurationSeconds == nil
        ) {
            continue;
        }

        NSError *error = nil;
        AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:sourcePath] error:&error];
        if (audioFile == nil || error != nil) {
            continue;
        }

        const AVAudioFramePosition startingFrame = MAX(
            0,
            (AVAudioFramePosition)llround(sourceTimeSeconds.doubleValue * audioFile.processingFormat.sampleRate)
        );
        const AVAudioFramePosition availableFrames = MAX(0, audioFile.length - startingFrame);
        const AVAudioFramePosition requestedFrames = MAX(
            0,
            (AVAudioFramePosition)llround(remainingDurationSeconds.doubleValue * audioFile.processingFormat.sampleRate)
        );
        const AVAudioFrameCount frameCount = (AVAudioFrameCount)MIN(availableFrames, requestedFrames);
        if (frameCount == 0) {
            continue;
        }

        AVAudioPlayerNode *playerNode = [[AVAudioPlayerNode alloc] init];
        playerNode.volume = muted.boolValue ? 0.0f : (volume != nil ? volume.floatValue : 1.0f);
        [self.audioEngine attachNode:playerNode];
        [self.audioEngine connect:playerNode to:self.audioEngine.mainMixerNode format:audioFile.processingFormat];
        [playerNode scheduleSegment:audioFile
                      startingFrame:startingFrame
                         frameCount:frameCount
                             atTime:nil
                  completionHandler:nil];
        self.audioNodes[clipId] = playerNode;
        self.audioFiles[clipId] = audioFile;
    }

    if (self.desiredPlaying) {
        [self playAudioNodes];
    }
}

- (BOOL)configureAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;
    if (![session setCategory:AVAudioSessionCategoryPlayback
                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                        error:&error]) {
        return NO;
    }

    error = nil;
    if (![session setActive:YES error:&error]) {
        return NO;
    }

    return session.currentRoute.outputs.count > 0;
}

- (BOOL)ensureAudioEngineStarted {
    if (self.audioEngine == nil) {
        self.audioEngine = [[AVAudioEngine alloc] init];
    }

    if (self.audioEngine.isRunning) {
        return YES;
    }

    if (![self configureAudioSession]) {
        return NO;
    }

    NSError *error = nil;
    @try {
        (void)self.audioEngine.outputNode;
        [self.audioEngine startAndReturnError:&error];
    } @catch (NSException *exception) {
        return NO;
    }
    return error == nil && self.audioEngine.isRunning;
}

- (void)stopAndResetAudioNodes {
    if (self.audioEngine == nil) {
        [self.audioNodes removeAllObjects];
        return;
    }

    for (AVAudioPlayerNode *node in self.audioNodes.objectEnumerator) {
        [node stop];
        [self.audioEngine detachNode:node];
    }
    [self.audioNodes removeAllObjects];
    [self.audioFiles removeAllObjects];
    [self.audioEngine reset];
}

- (void)pauseAudioNodes {
    for (AVAudioPlayerNode *node in self.audioNodes.objectEnumerator) {
        if (node.isPlaying) {
            [node pause];
        }
    }
}

- (void)playAudioNodes {
    if (![self ensureAudioEngineStarted]) {
        return;
    }
    for (AVAudioPlayerNode *node in self.audioNodes.objectEnumerator) {
        if (!node.isPlaying) {
            [node play];
        }
    }
}

- (void)loadThumbnailForSourcePath:(NSString *)sourcePath
                 sourceTimeSeconds:(double)sourceTimeSeconds
                         intoLayer:(CALayer *)contentLayer
                        generation:(NSUInteger)generation {
    const double quantizedTimeSeconds = [self.class quantizedPreviewTime:sourceTimeSeconds];
    NSString *cacheKey = [NSString stringWithFormat:@"%@-%.3f", sourcePath, quantizedTimeSeconds];
    UIImage *cachedImage = [[self.class thumbnailCache] objectForKey:cacheKey];
    if (cachedImage != nil) {
        contentLayer.contents = (__bridge id)cachedImage.CGImage;
        return;
    }

    __weak typeof(self) weakSelf = self;
    __weak CALayer *weakLayer = contentLayer;
    [self requestThumbnailForSourcePath:sourcePath
                    quantizedTimeSeconds:quantizedTimeSeconds
                                cacheKey:cacheKey
                              completion:^(UIImage * _Nullable image) {
        if (image == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) strongSelf = weakSelf;
            CALayer *strongLayer = weakLayer;
            if (strongSelf == nil || strongLayer == nil || generation != strongSelf->_visualGeneration) {
                return;
            }
            strongLayer.contents = (__bridge id)image.CGImage;
        });
    }];
}

- (void)prefetchNearbyThumbnailsForSourcePath:(NSString *)sourcePath sourceTimeSeconds:(double)sourceTimeSeconds {
    const double frameStep = [self.class previewFrameStep];
    NSArray<NSNumber *> *offsets = @[ @(-3), @(-2), @(-1), @(1), @(2), @(3) ];

    for (NSNumber *offset in offsets) {
        double nearbyTime = MAX(0.0, sourceTimeSeconds + offset.doubleValue * frameStep);
        double quantizedTimeSeconds = [self.class quantizedPreviewTime:nearbyTime];
        NSString *cacheKey = [NSString stringWithFormat:@"%@-%.3f", sourcePath, quantizedTimeSeconds];
        if ([[self.class thumbnailCache] objectForKey:cacheKey] != nil) {
            continue;
        }

        [self requestThumbnailForSourcePath:sourcePath
                        quantizedTimeSeconds:quantizedTimeSeconds
                                    cacheKey:cacheKey
                                  completion:nil];
    }
}

- (void)requestThumbnailForSourcePath:(NSString *)sourcePath
                  quantizedTimeSeconds:(double)quantizedTimeSeconds
                              cacheKey:(NSString *)cacheKey
                            completion:(void (^ _Nullable)(UIImage * _Nullable image))completion {
    if ([self.class markThumbnailKeyInFlight:cacheKey] == NO) {
        return;
    }

    dispatch_async(_thumbnailQueue, ^{
        AVAssetImageGenerator *generator = [self.class imageGeneratorForSourcePath:sourcePath];
        if (generator == nil) {
            [self.class unmarkThumbnailKeyInFlight:cacheKey];
            return;
        }

        [generator generateCGImageAsynchronouslyForTime:CMTimeMakeWithSeconds(quantizedTimeSeconds, 600)
                                      completionHandler:^(CGImageRef  _Nullable cgImage,
                                                          CMTime actualTime,
                                                          NSError * _Nullable error) {
            UIImage *image = cgImage != nil ? [UIImage imageWithCGImage:cgImage] : nil;
            if (image != nil) {
                [[self.class thumbnailCache] setObject:image forKey:cacheKey];
            }
            [self.class unmarkThumbnailKeyInFlight:cacheKey];

            if (completion != nil) {
                completion(image);
            }
        }];
    });
}

+ (NSCache<NSString *, UIImage *> *)thumbnailCache {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 120;
    });
    return cache;
}

+ (NSCache<NSString *, AVAssetImageGenerator *> *)imageGeneratorCache {
    static NSCache<NSString *, AVAssetImageGenerator *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 24;
    });
    return cache;
}

+ (AVAssetImageGenerator *)imageGeneratorForSourcePath:(NSString *)sourcePath {
    AVAssetImageGenerator *cachedGenerator = [[self imageGeneratorCache] objectForKey:sourcePath];
    if (cachedGenerator != nil) {
        return cachedGenerator;
    }

    NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sourceURL options:nil];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(640, 640);
    generator.requestedTimeToleranceBefore = kCMTimeZero;
    generator.requestedTimeToleranceAfter = kCMTimeZero;
    [[self imageGeneratorCache] setObject:generator forKey:sourcePath];
    return generator;
}

+ (BOOL)markThumbnailKeyInFlight:(NSString *)cacheKey {
    NSMutableSet<NSString *> *set = [self inFlightThumbnailKeys];
    @synchronized (set) {
        if ([set containsObject:cacheKey]) {
            return NO;
        }
        [set addObject:cacheKey];
        return YES;
    }
}

+ (void)unmarkThumbnailKeyInFlight:(NSString *)cacheKey {
    NSMutableSet<NSString *> *set = [self inFlightThumbnailKeys];
    @synchronized (set) {
        [set removeObject:cacheKey];
    }
}

+ (NSMutableSet<NSString *> *)inFlightThumbnailKeys {
    static NSMutableSet<NSString *> *set;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        set = [NSMutableSet set];
    });
    return set;
}

+ (double)quantizedPreviewTime:(double)seconds {
    const double frameStep = [self previewFrameStep];
    return round(seconds / frameStep) * frameStep;
}

+ (double)previewFrameStep {
    return 1.0 / 24.0;
}

+ (NSString *)audioSignatureForPayloads:(NSArray<NSDictionary *> *)payloads {
    if (payloads.count == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *components = [NSMutableArray arrayWithCapacity:payloads.count];
    for (NSDictionary *clip in payloads) {
        NSString *clipId = clip[@"clipId"] ?: @"";
        NSString *sourcePath = clip[@"sourcePath"] ?: @"";
        NSNumber *volume = clip[@"volume"] ?: @1.0;
        NSNumber *muted = clip[@"muted"] ?: @NO;
        [components addObject:[NSString stringWithFormat:@"%@|%@|%.3f|%@", clipId, sourcePath, volume.doubleValue, muted.boolValue ? @"1" : @"0"]];
    }
    return [components componentsJoinedByString:@","];
}

@end
