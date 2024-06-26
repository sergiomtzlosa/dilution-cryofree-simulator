#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import "DRPhysicsEngine.h"
#import "DRCryostatScene.h"
#import "DRControlPanelView.h"
#import "DRGuideView.h"
#import "DRInspectorView.h"
#import "DRGraphView.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, DRCryostatSceneDelegate, DRInspectorViewDelegate, NSSplitViewDelegate>

@property (nonatomic, strong) NSWindow *window;

- (void)setupApplicationUI;

@end

NS_ASSUME_NONNULL_END



















































