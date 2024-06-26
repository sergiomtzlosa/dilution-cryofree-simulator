#import <Cocoa/Cocoa.h>
#import "DRPhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface DRGuideView : NSView

@property (nonatomic, weak) DRPhysicsEngine *physicsEngine;

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine;
- (void)updateGuideState;
- (void)scrollToTop;

@end

NS_ASSUME_NONNULL_END











































