#import <Cocoa/Cocoa.h>
#import "DRPhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface DRGraphView : NSView

@property (nonatomic, weak) DRPhysicsEngine *physicsEngine;
@property (nonatomic, assign) BOOL isLogarithmicScale;

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine;
- (void)recordDataPoint;
- (void)clearHistory;

@end

NS_ASSUME_NONNULL_END













































