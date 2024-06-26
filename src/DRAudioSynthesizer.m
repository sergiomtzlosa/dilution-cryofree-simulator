#import "DRAudioSynthesizer.h"
#import <AVFoundation/AVFoundation.h>

@interface DRAudioSynthesizer ()

@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *valvePlayer;
@property (nonatomic, strong) AVAudioPlayerNode *compressorPlayer;
@property (nonatomic, strong) AVAudioPCMBuffer *valveBuffer;
@property (nonatomic, strong) AVAudioPCMBuffer *compressorBuffer;
@property (nonatomic, assign) BOOL isCompressorPlaying;

@end

@implementation DRAudioSynthesizer

+ (instancetype)sharedSynthesizer {
    static DRAudioSynthesizer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DRAudioSynthesizer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isMuted = NO;
        _isCompressorPlaying = NO;
        [self setupAudioEngine];
    }
    return self;
}

- (void)setupAudioEngine {
    @try {
        _audioEngine = [[AVAudioEngine alloc] init];
        _valvePlayer = [[AVAudioPlayerNode alloc] init];
        _compressorPlayer = [[AVAudioPlayerNode alloc] init];
        
        [_audioEngine attachNode:_valvePlayer];
        [_audioEngine attachNode:_compressorPlayer];
        
        AVAudioFormat *format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:1];
        
        // Connect to main mixer — use the mixer's output format to avoid format mismatch
        [_audioEngine connect:_valvePlayer to:_audioEngine.mainMixerNode format:format];
        [_audioEngine connect:_compressorPlayer to:_audioEngine.mainMixerNode format:format];
        
        [self generateValveBufferWithFormat:format];
        [self generateCompressorBufferWithFormat:format];
        
        // NOTE: We do NOT start the engine here. Call ensureEngineRunning after
        // the NSRunLoop has begun (i.e. from applicationDidFinishLaunching callback).
        NSLog(@"[Audio] Engine configured, ready to start.");
    } @catch (NSException *e) {
        NSLog(@"[Audio] Setup exception: %@", e);
    }
}

- (void)ensureEngineRunning {
    if (_audioEngine.isRunning) return;
    @try {
        NSError *error = nil;
        BOOL ok = [_audioEngine startAndReturnError:&error];
        if (!ok || error) {
            NSLog(@"[Audio] Engine start failed: %@", error);
        } else {
            NSLog(@"[Audio] Engine started successfully.");
        }
    } @catch (NSException *e) {
        NSLog(@"[Audio] ensureEngineRunning exception: %@", e);
    }
}

- (void)generateValveBufferWithFormat:(AVAudioFormat *)format {
    // Sharp pneumatic click / metallic snap (duration 0.08s)
    NSUInteger frameCount = 44100 * 0.08;
    _valveBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:(AVAudioFrameCount)frameCount];
    _valveBuffer.frameLength = (AVAudioFrameCount)frameCount;
    
    float *samples = _valveBuffer.floatChannelData[0];
    for (NSUInteger i = 0; i < frameCount; i++) {
        float t = (float)i / 44100.0f;
        float decay = expf(-t * 60.0f);
        // Dual impulse + noise burst
        float tone = sinf(2.0f * M_PI * 1800.0f * t) * 0.5f + sinf(2.0f * M_PI * 3400.0f * t) * 0.3f;
        float noise = ((float)rand() / (float)RAND_MAX - 0.5f) * 0.4f;
        samples[i] = (tone + noise) * decay * 0.35f;
    }
}

- (void)generateCompressorBufferWithFormat:(AVAudioFormat *)format {
    // Pulse Tube 1.4 Hz acoustic pulse + 50Hz/100Hz motor hum (duration 2.0s loop)
    NSUInteger frameCount = 44100 * 2.0;
    _compressorBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:(AVAudioFrameCount)frameCount];
    _compressorBuffer.frameLength = (AVAudioFrameCount)frameCount;
    
    float *samples = _compressorBuffer.floatChannelData[0];
    for (NSUInteger i = 0; i < frameCount; i++) {
        float t = (float)i / 44100.0f;
        // 1.4 Hz rotary valve expansion envelope
        float pulseEnv = 0.5f + 0.5f * sinf(2.0f * M_PI * 1.4f * t);
        // Motor sub-bass hum
        float subHum = sinf(2.0f * M_PI * 60.0f * t) * 0.15f + sinf(2.0f * M_PI * 120.0f * t) * 0.08f;
        // Expansion gas whoosh
        float gas = sinf(2.0f * M_PI * 240.0f * t) * 0.05f * pulseEnv;
        samples[i] = (subHum + gas) * 0.18f;
    }
}

- (void)playValveClick {
    if (_isMuted || !_valveBuffer || !_audioEngine.isRunning) return;
    @try {
        // Always schedule; player auto-starts if stopped
        if (!_valvePlayer.isPlaying) {
            [_valvePlayer play];
        }
        [_valvePlayer scheduleBuffer:_valveBuffer completionHandler:nil];
    } @catch (NSException *e) {
        NSLog(@"[Audio] playValveClick exception: %@", e);
    }
}

- (void)updateCompressorHumWithState:(BOOL)running {
    if (_isMuted || !_compressorBuffer) {
        if (_isCompressorPlaying) {
            [_compressorPlayer stop];
            _isCompressorPlaying = NO;
        }
        return;
    }
    
    @try {
        if (running && !_isCompressorPlaying) {
            [_compressorPlayer scheduleBuffer:_compressorBuffer atTime:nil options:AVAudioPlayerNodeBufferLoops completionHandler:nil];
            [_compressorPlayer play];
            _isCompressorPlaying = YES;
        } else if (!running && _isCompressorPlaying) {
            [_compressorPlayer stop];
            _isCompressorPlaying = NO;
        }
    } @catch (NSException *e) {}
}

- (void)updateTurboWhineWithState:(BOOL)running speedFactor:(double)speed {
    // Optional additional whining audio node
}

@end














































