#import <Cocoa/Cocoa.h>
#import "DRPhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface DRControlPanelView : NSView

@property (nonatomic, weak) DRPhysicsEngine *physicsEngine;

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine;
- (void)updateTelemetry;
- (void)scrollToTop;

@end

NS_ASSUME_NONNULL_END


















































