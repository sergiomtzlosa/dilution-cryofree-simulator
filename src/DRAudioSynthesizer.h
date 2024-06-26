#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DRAudioSynthesizer : NSObject

+ (instancetype)sharedSynthesizer;

@property (nonatomic, assign) BOOL isMuted;

// Audio Triggers
- (void)ensureEngineRunning; // Call once after run loop starts
- (void)playValveClick;
- (void)updateCompressorHumWithState:(BOOL)running;
- (void)updateTurboWhineWithState:(BOOL)running speedFactor:(double)speed;

@end

NS_ASSUME_NONNULL_END






































