#import <Cocoa/Cocoa.h>
#import "DRCryostatScene.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DRInspectorViewDelegate <NSObject>
- (void)inspectorViewDidRequestFocusOnComponent:(DRCryoComponentID)componentID;
@end

@interface DRInspectorView : NSView

@property (nonatomic, weak) id<DRInspectorViewDelegate> delegate;

- (void)inspectComponent:(DRCryoComponentID)componentID;
- (void)scrollToTop;

@end

NS_ASSUME_NONNULL_END









































