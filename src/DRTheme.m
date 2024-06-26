#import "DRTheme.h"

@implementation DRFlippedView

- (BOOL)isFlipped {
    return YES;
}

@end

@implementation DRTheme

+ (NSColor *)backgroundDark {
    return [NSColor colorWithCalibratedRed:0.04 green:0.05 blue:0.07 alpha:1.0]; // #0a0d12
}

+ (NSColor *)surfaceDark {
    return [NSColor colorWithCalibratedRed:0.08 green:0.09 blue:0.12 alpha:0.95]; // #14171f
}

+ (NSColor *)surfaceElevated {
    return [NSColor colorWithCalibratedRed:0.12 green:0.14 blue:0.18 alpha:1.0]; // #1f242e
}

+ (NSColor *)surfaceCard {
    return [NSColor colorWithCalibratedRed:0.10 green:0.12 blue:0.16 alpha:0.85]; // Frosted card
}

+ (NSColor *)borderSubtle {
    return [NSColor colorWithCalibratedRed:0.22 green:0.26 blue:0.33 alpha:0.5];
}

+ (NSColor *)borderActive {
    return [NSColor colorWithCalibratedRed:0.00 green:0.92 blue:1.00 alpha:0.9];
}

+ (NSColor *)cryoCyan {
    return [NSColor colorWithCalibratedRed:0.00 green:0.94 blue:1.00 alpha:1.0]; // #00f0ff
}

+ (NSColor *)quantumPurple {
    return [NSColor colorWithCalibratedRed:0.74 green:0.58 blue:1.00 alpha:1.0]; // #bd93f9
}

+ (NSColor *)phosphorGreen {
    return [NSColor colorWithCalibratedRed:0.31 green:0.98 blue:0.48 alpha:1.0]; // #50fa7b
}

+ (NSColor *)warningAmber {
    return [NSColor colorWithCalibratedRed:1.00 green:0.72 blue:0.42 alpha:1.0]; // #ffb86c
}

+ (NSColor *)alertRed {
    return [NSColor colorWithCalibratedRed:1.00 green:0.33 blue:0.33 alpha:1.0]; // #ff5555
}

+ (NSColor *)goldMetallic {
    return [NSColor colorWithCalibratedRed:1.00 green:0.84 blue:0.20 alpha:1.0]; // #ffd700
}

+ (NSColor *)copperMetallic {
    return [NSColor colorWithCalibratedRed:0.88 green:0.54 blue:0.35 alpha:1.0]; // #e08a59
}

+ (NSColor *)steelMetallic {
    return [NSColor colorWithCalibratedRed:0.70 green:0.76 blue:0.84 alpha:1.0]; // #b3c2d6
}

+ (NSColor *)textPrimary {
    return [NSColor colorWithCalibratedWhite:0.98 alpha:1.0];
}

+ (NSColor *)textSecondary {
    return [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
}

+ (NSColor *)textMuted {
    return [NSColor colorWithCalibratedWhite:0.48 alpha:1.0];
}

+ (NSColor *)textAccent {
    return [self cryoCyan];
}

// Fonts
+ (NSFont *)titleFont {
    return [NSFont systemFontOfSize:14.5 weight:NSFontWeightBold];
}

+ (NSFont *)subtitleFont {
    return [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
}

+ (NSFont *)bodyFont {
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightRegular];
}

+ (NSFont *)boldBodyFont {
    return [NSFont systemFontOfSize:12.0 weight:NSFontWeightMedium];
}

+ (NSFont *)smallFont {
    return [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
}

+ (NSFont *)monoFontWithSize:(CGFloat)size {
    return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightRegular];
}

+ (NSFont *)boldMonoFontWithSize:(CGFloat)size {
    return [NSFont monospacedSystemFontOfSize:size weight:NSFontWeightBold];
}

// Formatting
+ (NSString *)formattedTemperature:(double)kelvin {
    if (kelvin < 0.0001) {
        return @"0.0 mK";
    } else if (kelvin < 1.0) {
        double mK = kelvin * 1000.0;
        if (mK < 100.0) {
            return [NSString stringWithFormat:@"%.2f mK", mK];
        } else {
            return [NSString stringWithFormat:@"%.1f mK", mK];
        }
    } else if (kelvin < 10.0) {
        return [NSString stringWithFormat:@"%.3f K", kelvin];
    } else if (kelvin < 100.0) {
        return [NSString stringWithFormat:@"%.2f K", kelvin];
    } else {
        return [NSString stringWithFormat:@"%.1f K", kelvin];
    }
}

+ (NSString *)formattedPressure:(double)mbar {
    if (mbar < 1e-4) {
        return [NSString stringWithFormat:@"%.2e mbar", mbar];
    } else if (mbar < 0.1) {
        return [NSString stringWithFormat:@"%.3f mbar", mbar];
    } else if (mbar < 10.0) {
        return [NSString stringWithFormat:@"%.2f mbar", mbar];
    } else if (mbar < 1000.0) {
        return [NSString stringWithFormat:@"%.1f mbar", mbar];
    } else {
        double bar = mbar / 1000.0;
        return [NSString stringWithFormat:@"%.2f bar", bar];
    }
}

+ (NSString *)formattedFlowRate:(double)umolPerSec {
    if (umolPerSec < 1.0) {
        return @"0.0 µmol/s";
    } else if (umolPerSec < 1000.0) {
        return [NSString stringWithFormat:@"%.1f µmol/s", umolPerSec];
    } else {
        return [NSString stringWithFormat:@"%.2f mmol/s", umolPerSec / 1000.0];
    }
}

+ (NSString *)formattedPower:(double)microWatts {
    if (microWatts < 1.0) {
        return @"0.0 µW";
    } else if (microWatts < 1000.0) {
        return [NSString stringWithFormat:@"%.1f µW", microWatts];
    } else {
        return [NSString stringWithFormat:@"%.2f mW", microWatts / 1000.0];
    }
}

// UI Factory
+ (NSButton *)styledButtonWithTitle:(NSString *)title iconName:(nullable NSString *)iconName target:(nullable id)target action:(nullable SEL)action {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 120, 28)];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = target;
    btn.action = action;
    btn.font = [self boldBodyFont];
    if (iconName) {
        btn.image = [NSImage imageWithSystemSymbolName:iconName accessibilityDescription:nil];
        btn.imagePosition = NSImageLeading;
    }
    return btn;
}

+ (NSButton *)styledAccentButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action {
    NSButton *btn = [self styledButtonWithTitle:title iconName:nil target:target action:action];
    btn.contentTintColor = [self cryoCyan];
    return btn;
}

+ (NSButton *)styledToggleButtonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 100, 26)];
    btn.title = title;
    [btn setButtonType:NSButtonTypePushOnPushOff];
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = target;
    btn.action = action;
    btn.font = [self boldBodyFont];
    return btn;
}

+ (NSTextField *)styledLabelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSZeroRect];
    label.stringValue = text;
    label.font = font;
    label.textColor = color;
    label.editable = NO;
    label.selectable = NO;
    label.drawsBackground = NO;
    label.bezeled = NO;
    // Keep frame-based layout so callers can set .frame directly
    label.translatesAutoresizingMaskIntoConstraints = YES;
    return label;
}

+ (NSBox *)styledCard {
    NSBox *card = [[NSBox alloc] initWithFrame:NSZeroRect];
    card.boxType = NSBoxCustom;
    card.fillColor = [self surfaceCard];
    card.borderColor = [self borderSubtle];
    card.borderWidth = 1.0;
    card.cornerRadius = 10.0;
    card.titlePosition = NSNoTitle;
    card.translatesAutoresizingMaskIntoConstraints = YES;
    return card;
}

+ (NSVisualEffectView *)styledVibrancyViewWithFrame:(NSRect)frame {
    NSVisualEffectView *v = [[NSVisualEffectView alloc] initWithFrame:frame];
    v.material = NSVisualEffectMaterialUnderWindowBackground;
    v.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    v.state = NSVisualEffectStateActive;
    v.wantsLayer = YES;
    v.layer.backgroundColor = [self backgroundDark].CGColor;
    return v;
}

@end












































