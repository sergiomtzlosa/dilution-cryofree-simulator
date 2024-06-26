#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// A flipped container used as the document view of NSScrollView. Without this,
// AppKit anchors non-flipped document views at their bottom-left, so tall
// side-panel content opens scrolled to the bottom (showing an empty region).
@interface DRFlippedView : NSView
@end

@interface DRTheme : NSObject

// Palette Colors
+ (NSColor *)backgroundDark;
+ (NSColor *)surfaceDark;
+ (NSColor *)surfaceElevated;
+ (NSColor *)surfaceCard;
+ (NSColor *)borderSubtle;
+ (NSColor *)borderActive;

+ (NSColor *)cryoCyan;
+ (NSColor *)quantumPurple;
+ (NSColor *)phosphorGreen;
+ (NSColor *)warningAmber;
+ (NSColor *)alertRed;
+ (NSColor *)goldMetallic;
+ (NSColor *)copperMetallic;
+ (NSColor *)steelMetallic;

+ (NSColor *)textPrimary;
+ (NSColor *)textSecondary;
+ (NSColor *)textMuted;
+ (NSColor *)textAccent;

// Fonts
+ (NSFont *)titleFont;
+ (NSFont *)subtitleFont;
+ (NSFont *)bodyFont;
+ (NSFont *)boldBodyFont;
+ (NSFont *)smallFont;
+ (NSFont *)monoFontWithSize:(CGFloat)size;
+ (NSFont *)boldMonoFontWithSize:(CGFloat)size;

// Formatting Helpers
+ (NSString *)formattedTemperature:(double)kelvin;
+ (NSString *)formattedPressure:(double)mbar;
+ (NSString *)formattedFlowRate:(double)umolPerSec;
+ (NSString *)formattedPower:(double)microWatts;

// UI Factory Helpers
+ (NSButton *)styledButtonWithTitle:(NSString *)title iconName:(nullable NSString *)iconName target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)styledAccentButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (NSButton *)styledToggleButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (NSTextField *)styledLabelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color;
+ (NSBox *)styledCard;
+ (NSVisualEffectView *)styledVibrancyViewWithFrame:(NSRect)frame;

@end

NS_ASSUME_NONNULL_END





































