#import <SceneKit/SceneKit.h>
#import "DRPhysicsEngine.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DRCryoComponentID) {
    DRCryoComponentNone = 0,
    DRCryoComponentTopFlange300K,
    DRCryoComponentPulseTube,
    DRCryoComponentOVC,
    DRCryoComponent50KShield,
    DRCryoComponent50KFlange,
    DRCryoComponent4KShield,
    DRCryoComponent4KFlange,
    DRCryoComponentStillStage,
    DRCryoComponentContinuousExchanger,
    DRCryoComponentColdPlate,
    DRCryoComponentStepExchangers,
    DRCryoComponentMixingChamber,
    DRCryoComponentSamplePuck,
    DRCryoComponentRFCoaxLines
};

@protocol DRCryostatSceneDelegate <NSObject>
- (void)cryostatSceneDidSelectComponent:(DRCryoComponentID)componentID name:(NSString *)name;
@end

@interface DRCryostatScene : SCNScene

@property (nonatomic, weak) id<DRCryostatSceneDelegate> cryoDelegate;

// Camera & Controls
@property (nonatomic, strong, readonly) SCNNode *cameraNode;
@property (nonatomic, strong, readonly) SCNNode *cameraPivotNode;

// Display Options
@property (nonatomic, assign) CGFloat explodeProgress;       // 0.0 (closed) to 1.0 (fully exploded)
@property (nonatomic, assign) BOOL showOVC;
@property (nonatomic, assign) BOOL show50KShield;
@property (nonatomic, assign) BOOL show4KShield;
@property (nonatomic, assign) BOOL show3DLabels;
@property (nonatomic, assign) BOOL showFlowParticles;

// Selection
@property (nonatomic, assign, readonly) DRCryoComponentID selectedComponentID;

// Initialization
- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine;

// Interactivity
- (void)handleHitTestAtPoint:(CGPoint)point inView:(SCNView *)view;
- (void)selectComponent:(DRCryoComponentID)componentID;
- (void)focusCameraOnStage:(DRCryoComponentID)stageID;
- (void)resetCamera;

// Live update
- (void)updateWithPhysicsState;

@end

NS_ASSUME_NONNULL_END














































