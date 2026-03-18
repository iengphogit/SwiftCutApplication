#import "SCAudioTransportEngine.h"

#import <AVFoundation/AVFoundation.h>

@interface SCAudioTransportEngine ()

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVAudioPlayerNode *> *audioNodes;
@property (nonatomic, strong) NSMutableDictionary<NSString *, AVAudioFile *> *audioFiles;
@property (nonatomic, copy) NSArray<NSDictionary *> *activeAudioClips;
@property (nonatomic, copy) NSString *activeAudioSignature;
@property (nonatomic, assign, readwrite, getter=isPlaying) BOOL playing;
@property (nonatomic, assign) double currentTimeSeconds;

@end

static BOOL SCAudioClipSupportsDirectAVAudioFileRead(NSString *sourcePath) {
    NSString *ext = sourcePath.pathExtension.lowercaseString;
    if (ext.length == 0) {
        return NO;
    }

    static NSSet<NSString *> *supportedExtensions;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        supportedExtensions = [NSSet setWithArray:@[
            @"aac", @"aif", @"aiff", @"caf", @"flac", @"m4a", @"mp3", @"wav"
        ]];
    });

    return [supportedExtensions containsObject:ext];
}

@implementation SCAudioTransportEngine

- (instancetype)init {
    self = [super init];
    if (self) {
        _audioNodes = [NSMutableDictionary dictionary];
        _audioFiles = [NSMutableDictionary dictionary];
        _activeAudioClips = @[];
        _activeAudioSignature = @"";
        _playing = NO;
        _currentTimeSeconds = 0.0;
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (void)setDesiredPlaybackState:(BOOL)playing {
    if (_playing == playing) {
        return;
    }

    _playing = playing;
    if (!_playing) {
        [self pauseAudioNodes];
        return;
    }

    if (self.activeAudioClips.count > 0) {
        [self synchronizeAudioTransport];
    }
}

- (void)seekToTimeSeconds:(double)seconds {
    _currentTimeSeconds = MAX(seconds, 0.0);
    [self synchronizeAudioTransport];
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

- (void)stop {
    self.playing = NO;
    [self stopAndResetAudioNodes];
    [self.audioEngine stop];
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
        NSNumber *sourceStartSeconds = clip[@"sourceStartSeconds"];
        NSNumber *timelineStartSeconds = clip[@"timelineStartSeconds"];
        NSNumber *timelineDurationSeconds = clip[@"timelineDurationSeconds"];
        NSNumber *volume = clip[@"volume"];
        NSNumber *muted = clip[@"muted"];

        if (
            clipId.length == 0 ||
            sourcePath.length == 0 ||
            sourceStartSeconds == nil ||
            timelineStartSeconds == nil ||
            timelineDurationSeconds == nil ||
            !SCAudioClipSupportsDirectAVAudioFileRead(sourcePath)
        ) {
            continue;
        }

        const double elapsedTimelineSeconds = MAX(self.currentTimeSeconds - timelineStartSeconds.doubleValue, 0.0);
        const double remainingDurationSeconds = timelineDurationSeconds.doubleValue - elapsedTimelineSeconds;
        if (remainingDurationSeconds <= 0.0) {
            continue;
        }

        NSError *error = nil;
        AVAudioFile *audioFile = [[AVAudioFile alloc] initForReading:[NSURL fileURLWithPath:sourcePath] error:&error];
        if (audioFile == nil || error != nil) {
            continue;
        }

        const double sourceTimeSeconds = MAX(sourceStartSeconds.doubleValue + elapsedTimelineSeconds, 0.0);

        AVAudioFramePosition startingFrame = MAX(
            0,
            (AVAudioFramePosition)llround(sourceTimeSeconds * audioFile.processingFormat.sampleRate)
        );
        AVAudioFramePosition availableFrames = MAX(0, audioFile.length - startingFrame);
        AVAudioFramePosition requestedFrames = MAX(
            0,
            (AVAudioFramePosition)llround(remainingDurationSeconds * audioFile.processingFormat.sampleRate)
        );
        AVAudioFrameCount frameCount = (AVAudioFrameCount)MIN(availableFrames, requestedFrames);
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

    if (self.isPlaying) {
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
        [self.audioFiles removeAllObjects];
        return;
    }

    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
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

+ (NSString *)audioSignatureForPayloads:(NSArray<NSDictionary *> *)payloads {
    if (payloads.count == 0) {
        return @"";
    }

    NSMutableArray<NSString *> *components = [NSMutableArray arrayWithCapacity:payloads.count];
    for (NSDictionary *clip in payloads) {
        NSString *clipId = clip[@"clipId"] ?: @"";
        NSString *sourcePath = clip[@"sourcePath"] ?: @"";
        double sourceStartSeconds = [clip[@"sourceStartSeconds"] doubleValue];
        double timelineStartSeconds = [clip[@"timelineStartSeconds"] doubleValue];
        double timelineDurationSeconds = [clip[@"timelineDurationSeconds"] doubleValue];
        double volume = clip[@"volume"] != nil ? [clip[@"volume"] doubleValue] : 1.0;
        BOOL muted = [clip[@"muted"] boolValue];
        [components addObject:[NSString stringWithFormat:@"%@|%@|%.4f|%.4f|%.4f|%.3f|%@",
            clipId,
            sourcePath,
            sourceStartSeconds,
            timelineStartSeconds,
            timelineDurationSeconds,
            volume,
            muted ? @"1" : @"0"]];
    }

    return [components componentsJoinedByString:@"#"];
}

@end
