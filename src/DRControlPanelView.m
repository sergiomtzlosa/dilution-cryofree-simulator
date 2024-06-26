#import "DRControlPanelView.h"
#import "DRTheme.h"
#import "DRAudioSynthesizer.h"

// ─────────────────────────────────────────────────────────────
// A small LED indicator view drawn via CoreGraphics
// ─────────────────────────────────────────────────────────────
@interface DRLEDView : NSView
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, assign) BOOL isOn;
- (instancetype)initWithFrame:(NSRect)frame color:(NSColor *)color;
@end
@implementation DRLEDView
- (instancetype)initWithFrame:(NSRect)frame color:(NSColor *)color {
    self = [super initWithFrame:frame];
    if (self) { _color = color; _isOn = NO; self.wantsLayer = YES; }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    NSRect r = NSInsetRect(self.bounds, 2, 2);
    // Outer dark ring
    CGContextSetFillColorWithColor(ctx, [NSColor colorWithCalibratedWhite:0.1 alpha:1.0].CGColor);
    CGContextFillEllipseInRect(ctx, r);
    // Inner glow
    NSColor *fill = _isOn ? _color : [_color colorWithAlphaComponent:0.18];
    CGContextSetFillColorWithColor(ctx, fill.CGColor);
    NSRect inner = NSInsetRect(r, 3, 3);
    CGContextFillEllipseInRect(ctx, inner);
    // Highlight specular
    if (_isOn) {
        CGContextSetFillColorWithColor(ctx, [NSColor colorWithCalibratedWhite:1.0 alpha:0.35].CGColor);
        NSRect spec = NSMakeRect(inner.origin.x + inner.size.width*0.2, inner.origin.y + inner.size.height*0.55,
                                  inner.size.width * 0.35, inner.size.height * 0.25);
        CGContextFillEllipseInRect(ctx, spec);
        // Glow shadow
        CGContextSetShadowWithColor(ctx, CGSizeZero, 6.0, [_color colorWithAlphaComponent:0.9].CGColor);
        CGContextFillEllipseInRect(ctx, inner);
    }
}
@end

// ─────────────────────────────────────────────────────────────
// Styled toggle pump/valve row view
// ─────────────────────────────────────────────────────────────
@interface DRToggleRowView : NSView
@property (nonatomic, strong) DRLEDView *led;
@property (nonatomic, strong) NSButton *button;
- (instancetype)initWithTitle:(NSString *)title tag:(nullable NSString *)tag ledColor:(NSColor *)color
                       target:(id)target action:(SEL)action;
@end
@implementation DRToggleRowView
- (instancetype)initWithTitle:(NSString *)title tag:(nullable NSString *)tag ledColor:(NSColor *)color
                       target:(id)target action:(SEL)action {
    self = [super initWithFrame:NSMakeRect(0, 0, 310, 30)];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.08 alpha:0.5].CGColor;
        self.layer.cornerRadius = 6.0;
        self.layer.borderColor = [NSColor colorWithCalibratedWhite:0.22 alpha:0.3].CGColor;
        self.layer.borderWidth = 1.0;
        
        // LED
        _led = [[DRLEDView alloc] initWithFrame:NSMakeRect(10, 7, 16, 16) color:color];
        [self addSubview:_led];
        
        // Tag badge (e.g. "V1")
        if (tag) {
            NSTextField *tagLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(32, 6, 40, 18)];
            tagLabel.stringValue = tag;
            tagLabel.font = [DRTheme boldMonoFontWithSize:9.5];
            tagLabel.textColor = color;
            tagLabel.editable = NO; tagLabel.selectable = NO;
            tagLabel.drawsBackground = NO; tagLabel.bezeled = NO;
            tagLabel.alignment = NSTextAlignmentCenter;
            [self addSubview:tagLabel];
            
            NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(78, 7, 190, 16)];
            titleLabel.stringValue = title;
            titleLabel.font = [DRTheme monoFontWithSize:11.0];
            titleLabel.textColor = [DRTheme textSecondary];
            titleLabel.editable = NO; titleLabel.selectable = NO;
            titleLabel.drawsBackground = NO; titleLabel.bezeled = NO;
            [self addSubview:titleLabel];
        } else {
            NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(34, 7, 220, 16)];
            titleLabel.stringValue = title;
            titleLabel.font = [DRTheme boldBodyFont];
            titleLabel.textColor = [DRTheme textPrimary];
            titleLabel.editable = NO; titleLabel.selectable = NO;
            titleLabel.drawsBackground = NO; titleLabel.bezeled = NO;
            [self addSubview:titleLabel];
        }
        
        // Invisible full-row button for interaction
        _button = [[NSButton alloc] initWithFrame:self.bounds];
        [_button setButtonType:NSButtonTypePushOnPushOff];
        _button.bezelStyle = NSBezelStyleShadowlessSquare;
        _button.title = @"";
        _button.transparent = YES;
        _button.target = target;
        _button.action = action;
        [self addSubview:_button];
    }
    return self;
}
@end


@interface DRControlPanelView ()

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DRFlippedView *documentView;
@property (nonatomic, strong) NSView *contentView;

// Digital Telemetry Displays
@property (nonatomic, strong) NSTextField *temp50KLabel;
@property (nonatomic, strong) NSTextField *temp4KLabel;
@property (nonatomic, strong) NSTextField *tempStillLabel;
@property (nonatomic, strong) NSTextField *tempColdPlateLabel;
@property (nonatomic, strong) NSTextField *tempMCLabel;

@property (nonatomic, strong) NSTextField *pressOVCLabel;
@property (nonatomic, strong) NSTextField *pressDumpLabel;
@property (nonatomic, strong) NSTextField *pressCondLabel;
@property (nonatomic, strong) NSTextField *pressStillLabel;
@property (nonatomic, strong) NSTextField *flowRateLabel;
@property (nonatomic, strong) NSTextField *phaseStatusBadge;

// Hardware Toggle Controls
@property (nonatomic, strong) DRToggleRowView *ptCompressorRow;
@property (nonatomic, strong) DRToggleRowView *turboPumpRow;
@property (nonatomic, strong) DRToggleRowView *scrollPumpRow;

// Valve rows
@property (nonatomic, strong) DRToggleRowView *vOVCRow;
@property (nonatomic, strong) DRToggleRowView *v1Row;
@property (nonatomic, strong) DRToggleRowView *v2Row;
@property (nonatomic, strong) DRToggleRowView *v3Row;
@property (nonatomic, strong) DRToggleRowView *v4Row;
@property (nonatomic, strong) DRToggleRowView *v5Row;
@property (nonatomic, strong) DRToggleRowView *v6Row;

// Heaters
@property (nonatomic, strong) NSSlider *stillHeaterSlider;
@property (nonatomic, strong) NSTextField *stillHeaterValueLabel;
@property (nonatomic, strong) NSSlider *mcHeaterSlider;
@property (nonatomic, strong) NSTextField *mcHeaterValueLabel;

// PID
@property (nonatomic, strong) NSButton *pidToggleBtn;
@property (nonatomic, strong) NSTextField *pidSetpointField;

@end

@implementation DRControlPanelView

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine {
    self = [super initWithFrame:NSMakeRect(0, 0, 360, 800)];
    if (self) {
        _physicsEngine = engine;
        [self setupUI];
        [self updateTelemetry];
    }
    return self;
}

#pragma mark - Label Factory (Frame-based, NOT autolayout)

+ (NSTextField *)labelWithText:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *f = [[NSTextField alloc] init];
    f.stringValue = text;
    f.font = font;
    f.textColor = color;
    f.editable = NO; f.selectable = NO;
    f.drawsBackground = NO; f.bezeled = NO;
    f.translatesAutoresizingMaskIntoConstraints = YES; // Frame-based
    return f;
}

#pragma mark - Setup

- (void)setupUI {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [DRTheme surfaceDark].CGColor;

    _scrollView = [[NSScrollView alloc] initWithFrame:self.bounds];
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.autohidesScrollers = NO;
    _scrollView.scrollerStyle = NSScrollerStyleOverlay;
    _scrollView.drawsBackground = NO;
    [self addSubview:_scrollView];

    // The panel is taller than the viewport. Use a flipped document view so
    // the scroll view always opens at the top (y = 0) instead of the bottom.
    CGFloat totalHeight = 1260;
    _documentView = [[DRFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 344, totalHeight)];
    _scrollView.documentView = _documentView;

    _contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 344, totalHeight)];
    _contentView.autoresizingMask = NSViewWidthSizable;
    [_documentView addSubview:_contentView];

    CGFloat yPos = totalHeight - 12;

    // ── Header ──────────────────────────────────────────────────
    NSTextField *titleLabel = [DRControlPanelView labelWithText:@"GAS HANDLING SYSTEM · GHS GEN-2"
                                                           font:[DRTheme titleFont]
                                                          color:[DRTheme cryoCyan]];
    titleLabel.frame = NSMakeRect(16, yPos - 22, 316, 22);
    [_contentView addSubview:titleLabel];

    NSTextField *subLabel = [DRControlPanelView labelWithText:@"Cryogen-Free Dilution Refrigerator · Cryogenic Control"
                                                         font:[DRTheme smallFont]
                                                        color:[DRTheme textMuted]];
    subLabel.frame = NSMakeRect(16, yPos - 40, 316, 16);
    [_contentView addSubview:subLabel];

    yPos -= 55;

    // ── Card: Quick Automation ────────────────────────────────────
    yPos = [self buildQuickActionsCardAtY:yPos];
    yPos -= 12;

    // ── Card: Telemetry ──────────────────────────────────────────
    yPos = [self buildTelemetryCardAtY:yPos];
    yPos -= 12;

    // ── Card: Pumps ──────────────────────────────────────────────
    yPos = [self buildPumpsCardAtY:yPos];
    yPos -= 12;

    // ── Card: Valves ─────────────────────────────────────────────
    yPos = [self buildValvesCardAtY:yPos];
    yPos -= 12;

    // ── Card: Heaters & PID ──────────────────────────────────────
    [self buildHeatersAndPIDCardAtY:yPos];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        // The clip view may not have its final size until after the window is
        // on screen. Scroll to the top on the next run-loop pass.
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToTop];
        });
    }
}

- (void)scrollToTop {
    [_scrollView.contentView scrollToPoint:NSZeroPoint];
    [_scrollView reflectScrolledClipView:_scrollView.contentView];
}

#pragma mark - Card: Quick Automation

- (CGFloat)buildQuickActionsCardAtY:(CGFloat)top {
    CGFloat h = 120;
    NSBox *card = [self makeCardAtY:top - h width:320 height:h];

    // Section header
    NSTextField *hdr = [DRControlPanelView labelWithText:@"⚡  QUICK AUTOMATION"
                                                    font:[DRTheme boldMonoFontWithSize:11.0]
                                                   color:[DRTheme cryoCyan]];
    hdr.frame = NSMakeRect(14, 92, 292, 16);
    [card addSubview:hdr];

    // Auto Cooldown — primary accent button
    NSButton *autoCoolBtn = [[NSButton alloc] initWithFrame:NSMakeRect(12, 55, 296, 30)];
    autoCoolBtn.title = @"▶  AUTO COOLDOWN  →  10 mK BASE";
    autoCoolBtn.bezelStyle = NSBezelStyleRounded;
    autoCoolBtn.font = [DRTheme boldMonoFontWithSize:10.5];
    autoCoolBtn.contentTintColor = [DRTheme cryoCyan];
    autoCoolBtn.target = self;
    autoCoolBtn.action = @selector(autoFullCooldown:);
    [card addSubview:autoCoolBtn];

    // Jump to base temp — secondary
    NSButton *jumpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(12, 18, 296, 28)];
    jumpBtn.title = @"⚡  FAST-FORWARD → BASE TEMP (< 12 mK)";
    jumpBtn.bezelStyle = NSBezelStyleRounded;
    jumpBtn.font = [DRTheme monoFontWithSize:10.5];
    jumpBtn.contentTintColor = [DRTheme quantumPurple];
    jumpBtn.target = self;
    jumpBtn.action = @selector(jumpToBaseTemp:);
    [card addSubview:jumpBtn];

    return top - h;
}

#pragma mark - Card: Telemetry

- (CGFloat)buildTelemetryCardAtY:(CGFloat)top {
    CGFloat h = 310;
    NSBox *card = [self makeCardAtY:top - h width:320 height:h];

    // Header
    NSTextField *hdr = [DRControlPanelView labelWithText:@"🌡  CRYOGENIC THERMOMETRY & PRESSURES"
                                                    font:[DRTheme boldMonoFontWithSize:11.0]
                                                   color:[DRTheme cryoCyan]];
    hdr.frame = NSMakeRect(14, 282, 292, 16);
    [card addSubview:hdr];

    // Temperature rows
    CGFloat rowY = 256;
    _temp50KLabel    = [self addTempRowInCard:card y:rowY title:@"50 K Stage (PT 1st)" color:[DRTheme steelMetallic]];   rowY -= 28;
    _temp4KLabel     = [self addTempRowInCard:card y:rowY title:@"4 K Condenser (PT 2nd)" color:[DRTheme goldMetallic]];  rowY -= 28;
    _tempStillLabel  = [self addTempRowInCard:card y:rowY title:@"Still Distillation" color:[DRTheme warningAmber]];       rowY -= 28;
    _tempColdPlateLabel = [self addTempRowInCard:card y:rowY title:@"Cold Plate (100 mK)" color:[DRTheme copperMetallic]];rowY -= 28;
    _tempMCLabel     = [self addTempRowInCard:card y:rowY title:@"Mixing Chamber (MC)" color:[DRTheme cryoCyan]];

    // Phase status banner
    rowY -= 30;
    _phaseStatusBadge = [[NSTextField alloc] init];
    _phaseStatusBadge.stringValue = @"● Single Phase Homogeneous";
    _phaseStatusBadge.font = [DRTheme boldMonoFontWithSize:10.5];
    _phaseStatusBadge.textColor = [DRTheme warningAmber];
    _phaseStatusBadge.editable = NO; _phaseStatusBadge.selectable = NO;
    _phaseStatusBadge.drawsBackground = NO; _phaseStatusBadge.bezeled = NO;
    _phaseStatusBadge.translatesAutoresizingMaskIntoConstraints = YES;
    _phaseStatusBadge.frame = NSMakeRect(14, rowY, 292, 16);
    [card addSubview:_phaseStatusBadge];

    // Pressure / flow separator
    rowY -= 18;
    NSBox *sep = [[NSBox alloc] initWithFrame:NSMakeRect(14, rowY, 292, 1)];
    sep.boxType = NSBoxSeparator;
    [card addSubview:sep];
    rowY -= 14;

    // OVC + Flow on same row
    _pressOVCLabel = [self makePressLabelInCard:card x:14 y:rowY prefix:@"OVC" color:[DRTheme textSecondary]];
    _flowRateLabel = [self makePressLabelInCard:card x:165 y:rowY prefix:@"Flow" color:[DRTheme phosphorGreen]];
    rowY -= 20;

    // Dump + Cond
    _pressDumpLabel = [self makePressLabelInCard:card x:14 y:rowY prefix:@"Dump" color:[DRTheme textMuted]];
    _pressCondLabel = [self makePressLabelInCard:card x:165 y:rowY prefix:@"Cond" color:[DRTheme textMuted]];
    rowY -= 20;

    // Still pressure
    _pressStillLabel = [self makePressLabelInCard:card x:14 y:rowY prefix:@"Still" color:[DRTheme warningAmber]];

    return top - h;
}

- (NSTextField *)addTempRowInCard:(NSBox *)card y:(CGFloat)y title:(NSString *)title color:(NSColor *)color {
    // Color swatch strip on left
    NSView *swatch = [[NSView alloc] initWithFrame:NSMakeRect(14, y + 2, 3, 14)];
    swatch.wantsLayer = YES;
    swatch.layer.backgroundColor = color.CGColor;
    swatch.layer.cornerRadius = 1.5;
    [card addSubview:swatch];

    // Stage name label
    NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(22, y, 158, 16)];
    nameLabel.stringValue = title;
    nameLabel.font = [DRTheme bodyFont];
    nameLabel.textColor = [DRTheme textSecondary];
    nameLabel.editable = NO; nameLabel.selectable = NO;
    nameLabel.drawsBackground = NO; nameLabel.bezeled = NO;
    [card addSubview:nameLabel];

    // Value label (right-aligned, monospaced, colored)
    NSTextField *valLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(185, y, 115, 18)];
    valLabel.stringValue = @"---";
    valLabel.font = [DRTheme boldMonoFontWithSize:13.0];
    valLabel.textColor = color;
    valLabel.alignment = NSTextAlignmentRight;
    valLabel.editable = NO; valLabel.selectable = NO;
    valLabel.drawsBackground = NO; valLabel.bezeled = NO;
    [card addSubview:valLabel];

    return valLabel;
}

- (NSTextField *)makePressLabelInCard:(NSBox *)card x:(CGFloat)x y:(CGFloat)y prefix:(NSString *)prefix color:(NSColor *)color {
    NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 148, 15)];
    lbl.stringValue = [NSString stringWithFormat:@"%@: ---", prefix];
    lbl.font = [DRTheme monoFontWithSize:10.0];
    lbl.textColor = color;
    lbl.editable = NO; lbl.selectable = NO;
    lbl.drawsBackground = NO; lbl.bezeled = NO;
    [card addSubview:lbl];
    return lbl;
}

#pragma mark - Card: Pumps & Compressors

- (CGFloat)buildPumpsCardAtY:(CGFloat)top {
    CGFloat h = 150;
    NSBox *card = [self makeCardAtY:top - h width:320 height:h];

    NSTextField *hdr = [DRControlPanelView labelWithText:@"⚙  PUMPS & COMPRESSORS"
                                                    font:[DRTheme boldMonoFontWithSize:11.0]
                                                   color:[DRTheme cryoCyan]];
    hdr.frame = NSMakeRect(14, h - 28, 292, 16);
    [card addSubview:hdr];

    CGFloat rowY = h - 58;
    _ptCompressorRow = [self addToggleRowToCard:card y:rowY title:@"Pulse Tube Compressor" tag:nil
                                       color:[DRTheme phosphorGreen] action:@selector(togglePulseTube:)]; rowY -= 34;
    _turboPumpRow    = [self addToggleRowToCard:card y:rowY title:@"OVC Turbomolecular Pump" tag:nil
                                       color:[DRTheme steelMetallic] action:@selector(toggleTurboPump:)]; rowY -= 34;
    _scrollPumpRow   = [self addToggleRowToCard:card y:rowY title:@"Dry Scroll Backing Pump" tag:nil
                                       color:[DRTheme warningAmber] action:@selector(toggleScrollPump:)];
    return top - h;
}

#pragma mark - Card: Gas Manifold Valves

- (CGFloat)buildValvesCardAtY:(CGFloat)top {
    CGFloat h = 280;
    NSBox *card = [self makeCardAtY:top - h width:320 height:h];

    NSTextField *hdr = [DRControlPanelView labelWithText:@"🔵  GAS MANIFOLD VALVES · P&ID"
                                                    font:[DRTheme boldMonoFontWithSize:11.0]
                                                   color:[DRTheme cryoCyan]];
    hdr.frame = NSMakeRect(14, h - 28, 292, 16);
    [card addSubview:hdr];

    CGFloat rowY = h - 58;
    _vOVCRow = [self addToggleRowToCard:card y:rowY title:@"OVC Turbo Gate Valve" tag:@"V-OVC"
                                  color:[DRTheme steelMetallic] action:@selector(toggleVOVC:)]; rowY -= 34;
    _v1Row   = [self addToggleRowToCard:card y:rowY title:@"Dump Tank Mixture Supply" tag:@"V1"
                                  color:[DRTheme warningAmber] action:@selector(toggleV1:)]; rowY -= 34;
    _v2Row   = [self addToggleRowToCard:card y:rowY title:@"Dump Return (Recovery)" tag:@"V2"
                                  color:[DRTheme warningAmber] action:@selector(toggleV2:)]; rowY -= 34;
    _v3Row   = [self addToggleRowToCard:card y:rowY title:@"Still Backing Pump Line" tag:@"V3"
                                  color:[DRTheme cryoCyan] action:@selector(toggleV3:)]; rowY -= 34;
    _v4Row   = [self addToggleRowToCard:card y:rowY title:@"Circulation Return Loop" tag:@"V4"
                                  color:[DRTheme cryoCyan] action:@selector(toggleV4:)]; rowY -= 34;
    _v5Row   = [self addToggleRowToCard:card y:rowY title:@"4K Condenser Injection" tag:@"V5"
                                  color:[DRTheme goldMetallic] action:@selector(toggleV5:)]; rowY -= 34;
    _v6Row   = [self addToggleRowToCard:card y:rowY title:@"Still Bypass Isolation" tag:@"V6"
                                  color:[DRTheme quantumPurple] action:@selector(toggleV6:)];

    return top - h;
}

#pragma mark - Card: Heaters & PID

- (void)buildHeatersAndPIDCardAtY:(CGFloat)top {
    CGFloat h = 270;
    NSBox *card = [self makeCardAtY:top - h width:320 height:h];

    NSTextField *hdr = [DRControlPanelView labelWithText:@"🔥  HEATERS & PID TEMPERATURE CONTROL"
                                                    font:[DRTheme boldMonoFontWithSize:11.0]
                                                   color:[DRTheme cryoCyan]];
    hdr.frame = NSMakeRect(14, h - 28, 292, 16);
    [card addSubview:hdr];

    // ── Still Heater ───────────────────────────────────────────────
    NSTextField *sLabel = [DRControlPanelView labelWithText:@"Still Heater — Evaporation Control"
                                                       font:[DRTheme bodyFont]
                                                      color:[DRTheme textSecondary]];
    sLabel.frame = NSMakeRect(14, h - 50, 210, 16);
    [card addSubview:sLabel];

    _stillHeaterValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(226, h - 50, 80, 16)];
    _stillHeaterValueLabel.stringValue = @"0.0 µW";
    _stillHeaterValueLabel.font = [DRTheme boldMonoFontWithSize:11.5];
    _stillHeaterValueLabel.textColor = [DRTheme warningAmber];
    _stillHeaterValueLabel.alignment = NSTextAlignmentRight;
    _stillHeaterValueLabel.editable = NO; _stillHeaterValueLabel.selectable = NO;
    _stillHeaterValueLabel.drawsBackground = NO; _stillHeaterValueLabel.bezeled = NO;
    [card addSubview:_stillHeaterValueLabel];

    _stillHeaterSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(14, h - 74, 292, 18)];
    _stillHeaterSlider.minValue = 0.0;
    _stillHeaterSlider.maxValue = 30000.0;
    _stillHeaterSlider.target = self;
    _stillHeaterSlider.action = @selector(stillHeaterSliderChanged:);
    [card addSubview:_stillHeaterSlider];

    NSTextField *sRange = [DRControlPanelView labelWithText:@"0 mW                                          30 mW"
                                                       font:[DRTheme monoFontWithSize:8.5]
                                                      color:[DRTheme textMuted]];
    sRange.frame = NSMakeRect(14, h - 88, 292, 12);
    [card addSubview:sRange];

    // ── MC Heater ──────────────────────────────────────────────────
    NSTextField *mLabel = [DRControlPanelView labelWithText:@"MC Heater — Calibration & Setpoint"
                                                       font:[DRTheme bodyFont]
                                                      color:[DRTheme textSecondary]];
    mLabel.frame = NSMakeRect(14, h - 114, 210, 16);
    [card addSubview:mLabel];

    _mcHeaterValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(226, h - 114, 80, 16)];
    _mcHeaterValueLabel.stringValue = @"0.0 µW";
    _mcHeaterValueLabel.font = [DRTheme boldMonoFontWithSize:11.5];
    _mcHeaterValueLabel.textColor = [DRTheme cryoCyan];
    _mcHeaterValueLabel.alignment = NSTextAlignmentRight;
    _mcHeaterValueLabel.editable = NO; _mcHeaterValueLabel.selectable = NO;
    _mcHeaterValueLabel.drawsBackground = NO; _mcHeaterValueLabel.bezeled = NO;
    [card addSubview:_mcHeaterValueLabel];

    _mcHeaterSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(14, h - 138, 292, 18)];
    _mcHeaterSlider.minValue = 0.0;
    _mcHeaterSlider.maxValue = 1000.0;
    _mcHeaterSlider.target = self;
    _mcHeaterSlider.action = @selector(mcHeaterSliderChanged:);
    [card addSubview:_mcHeaterSlider];

    NSTextField *mRange = [DRControlPanelView labelWithText:@"0 µW                                        1000 µW"
                                                       font:[DRTheme monoFontWithSize:8.5]
                                                      color:[DRTheme textMuted]];
    mRange.frame = NSMakeRect(14, h - 152, 292, 12);
    [card addSubview:mRange];

    // ── PID Controller ─────────────────────────────────────────────
    NSBox *pidSep = [[NSBox alloc] initWithFrame:NSMakeRect(14, h - 166, 292, 1)];
    pidSep.boxType = NSBoxSeparator;
    [card addSubview:pidSep];

    NSTextField *pidHdr = [DRControlPanelView labelWithText:@"PID CLOSED-LOOP TEMPERATURE REGULATOR"
                                                       font:[DRTheme boldMonoFontWithSize:9.5]
                                                      color:[DRTheme textMuted]];
    pidHdr.frame = NSMakeRect(14, h - 184, 292, 14);
    [card addSubview:pidHdr];

    NSTextField *setpointLabel = [DRControlPanelView labelWithText:@"Setpoint (mK):"
                                                              font:[DRTheme bodyFont]
                                                             color:[DRTheme textSecondary]];
    setpointLabel.frame = NSMakeRect(14, h - 210, 140, 16);
    [card addSubview:setpointLabel];

    _pidSetpointField = [[NSTextField alloc] initWithFrame:NSMakeRect(162, h - 212, 70, 22)];
    _pidSetpointField.stringValue = @"20.0";
    _pidSetpointField.font = [DRTheme boldMonoFontWithSize:12.0];
    _pidSetpointField.textColor = [DRTheme cryoCyan];
    _pidSetpointField.target = self;
    _pidSetpointField.action = @selector(pidSetpointEntered:);
    [card addSubview:_pidSetpointField];

    _pidToggleBtn = [[NSButton alloc] initWithFrame:NSMakeRect(12, h - 248, 296, 30)];
    _pidToggleBtn.title = @"Enable PID Auto-Regulation";
    _pidToggleBtn.bezelStyle = NSBezelStyleRounded;
    _pidToggleBtn.font = [DRTheme boldMonoFontWithSize:11.0];
    _pidToggleBtn.image = [NSImage imageWithSystemSymbolName:@"thermometer.snowflake" accessibilityDescription:nil];
    _pidToggleBtn.imagePosition = NSImageLeading;
    _pidToggleBtn.target = self;
    _pidToggleBtn.action = @selector(togglePID:);
    [card addSubview:_pidToggleBtn];
}

#pragma mark - Helper: makeCard

- (NSBox *)makeCardAtY:(CGFloat)y width:(CGFloat)w height:(CGFloat)h {
    NSBox *card = [[NSBox alloc] initWithFrame:NSMakeRect(12, y, w, h)];
    card.boxType = NSBoxCustom;
    card.fillColor = [NSColor colorWithCalibratedRed:0.09 green:0.11 blue:0.15 alpha:0.96];
    card.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.25 blue:0.33 alpha:0.55];
    card.borderWidth = 1.0;
    card.cornerRadius = 10.0;
    card.titlePosition = NSNoTitle;
    [_contentView addSubview:card];
    return card;
}

#pragma mark - Helper: Toggle Row

- (DRToggleRowView *)addToggleRowToCard:(NSBox *)card y:(CGFloat)y title:(NSString *)title
                                    tag:(nullable NSString *)tag color:(NSColor *)color action:(SEL)action {
    DRToggleRowView *row = [[DRToggleRowView alloc] initWithTitle:title tag:tag ledColor:color
                                                           target:self action:action];
    row.frame = NSMakeRect(14, y, 292, 28);
    [card addSubview:row];
    return row;
}

#pragma mark - Actions

- (void)autoFullCooldown:(id)sender {
    [_physicsEngine startAutoCooldownSequence];
    [_physicsEngine fastForwardToPhase:DRCryoPhaseBaseTemperature];
    [self updateTelemetry];
}

- (void)jumpToBaseTemp:(id)sender {
    [_physicsEngine fastForwardToPhase:DRCryoPhaseBaseTemperature];
    [self updateTelemetry];
}

- (void)togglePulseTube:(NSButton *)sender {
    _physicsEngine.ptCompressorOn = !_physicsEngine.ptCompressorOn;
    [[DRAudioSynthesizer sharedSynthesizer] updateCompressorHumWithState:_physicsEngine.ptCompressorOn];
    [self updateTelemetry];
}

- (void)toggleTurboPump:(NSButton *)sender {
    _physicsEngine.turboPumpOn = !_physicsEngine.turboPumpOn;
    [[DRAudioSynthesizer sharedSynthesizer] playValveClick];
    [self updateTelemetry];
}

- (void)toggleScrollPump:(NSButton *)sender {
    _physicsEngine.scrollPumpOn = !_physicsEngine.scrollPumpOn;
    [[DRAudioSynthesizer sharedSynthesizer] playValveClick];
    [self updateTelemetry];
}

- (void)toggleVOVC:(NSButton *)sender { _physicsEngine.valveOVC          = !_physicsEngine.valveOVC;          [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV1:(NSButton *)sender   { _physicsEngine.valveDumpSupply    = !_physicsEngine.valveDumpSupply;    [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV2:(NSButton *)sender   { _physicsEngine.valveDumpReturn    = !_physicsEngine.valveDumpReturn;    [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV3:(NSButton *)sender   { _physicsEngine.valveStillPumping  = !_physicsEngine.valveStillPumping;  [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV4:(NSButton *)sender   { _physicsEngine.valveCirculation   = !_physicsEngine.valveCirculation;   [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV5:(NSButton *)sender   { _physicsEngine.valveCondense      = !_physicsEngine.valveCondense;      [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }
- (void)toggleV6:(NSButton *)sender   { _physicsEngine.valveBypass        = !_physicsEngine.valveBypass;        [[DRAudioSynthesizer sharedSynthesizer] playValveClick]; [self updateTelemetry]; }

- (void)stillHeaterSliderChanged:(NSSlider *)sender {
    _physicsEngine.stillHeaterPower_uW = sender.doubleValue;
    _stillHeaterValueLabel.stringValue = [DRTheme formattedPower:sender.doubleValue];
}

- (void)mcHeaterSliderChanged:(NSSlider *)sender {
    _physicsEngine.mcHeaterPower_uW = sender.doubleValue;
    _mcHeaterValueLabel.stringValue = [DRTheme formattedPower:sender.doubleValue];
}

- (void)togglePID:(NSButton *)sender {
    _physicsEngine.pidEnabled = !_physicsEngine.pidEnabled;
    [self updateTelemetry];
}

- (void)pidSetpointEntered:(NSTextField *)sender {
    double sp = [sender.stringValue doubleValue];
    if (sp >= 10.0 && sp <= 1000.0) _physicsEngine.pidSetpoint_mK = sp;
}

#pragma mark - LED helpers

- (void)setLED:(DRToggleRowView *)row on:(BOOL)on {
    row.led.isOn = on;
    [row.led setNeedsDisplay:YES];
    // Tint the row background
    NSColor *bg = on
        ? [NSColor colorWithCalibratedWhite:0.12 alpha:0.7]
        : [NSColor colorWithCalibratedWhite:0.08 alpha:0.5];
    row.layer.backgroundColor = bg.CGColor;
}

#pragma mark - Telemetry Update

- (void)updateTelemetry {
    if (!_physicsEngine) return;

    // ── Temperatures ──────────────────────────────────────────────
    _temp50KLabel.stringValue       = [DRTheme formattedTemperature:_physicsEngine.temp50K];
    _temp4KLabel.stringValue        = [DRTheme formattedTemperature:_physicsEngine.temp4K];
    _tempStillLabel.stringValue     = [DRTheme formattedTemperature:_physicsEngine.tempStill];
    _tempColdPlateLabel.stringValue = [DRTheme formattedTemperature:_physicsEngine.tempColdPlate];
    _tempMCLabel.stringValue        = [DRTheme formattedTemperature:_physicsEngine.tempMixingChamber];

    // ── Pressures & Flow ──────────────────────────────────────────
    _pressOVCLabel.stringValue  = [NSString stringWithFormat:@"OVC: %@",  [DRTheme formattedPressure:_physicsEngine.pressOVC]];
    _flowRateLabel.stringValue  = [NSString stringWithFormat:@"Flow: %@", [DRTheme formattedFlowRate:_physicsEngine.flowRate_umol_s]];
    _pressDumpLabel.stringValue = [NSString stringWithFormat:@"Dump: %@", [DRTheme formattedPressure:_physicsEngine.pressDump]];
    _pressCondLabel.stringValue = [NSString stringWithFormat:@"Cond: %.2f bar", _physicsEngine.pressCondense];
    _pressStillLabel.stringValue= [NSString stringWithFormat:@"Still: %@",[DRTheme formattedPressure:_physicsEngine.pressStill]];

    // ── Phase badge ───────────────────────────────────────────────
    if (_physicsEngine.phaseSeparated) {
        _phaseStatusBadge.stringValue = @"⬤ Phase Separated · Quantum Dilution ACTIVE";
        _phaseStatusBadge.textColor   = [DRTheme cryoCyan];
    } else {
        _phaseStatusBadge.stringValue = @"⬤ Homogeneous Single Phase";
        _phaseStatusBadge.textColor   = [DRTheme warningAmber];
    }

    // ── Pump LEDs ─────────────────────────────────────────────────
    [self setLED:_ptCompressorRow on:_physicsEngine.ptCompressorOn];
    [self setLED:_turboPumpRow    on:_physicsEngine.turboPumpOn];
    [self setLED:_scrollPumpRow   on:_physicsEngine.scrollPumpOn];

    // ── Valve LEDs ────────────────────────────────────────────────
    [self setLED:_vOVCRow on:_physicsEngine.valveOVC];
    [self setLED:_v1Row   on:_physicsEngine.valveDumpSupply];
    [self setLED:_v2Row   on:_physicsEngine.valveDumpReturn];
    [self setLED:_v3Row   on:_physicsEngine.valveStillPumping];
    [self setLED:_v4Row   on:_physicsEngine.valveCirculation];
    [self setLED:_v5Row   on:_physicsEngine.valveCondense];
    [self setLED:_v6Row   on:_physicsEngine.valveBypass];

    // ── Heaters ───────────────────────────────────────────────────
    if (!_stillHeaterSlider.cell.isHighlighted) {
        _stillHeaterSlider.doubleValue = _physicsEngine.stillHeaterPower_uW;
        _stillHeaterValueLabel.stringValue = [DRTheme formattedPower:_physicsEngine.stillHeaterPower_uW];
    }
    if (!_mcHeaterSlider.cell.isHighlighted) {
        _mcHeaterSlider.doubleValue = _physicsEngine.mcHeaterPower_uW;
        _mcHeaterValueLabel.stringValue = [DRTheme formattedPower:_physicsEngine.mcHeaterPower_uW];
    }

    // ── PID ───────────────────────────────────────────────────────
    if (_physicsEngine.pidEnabled) {
        _pidToggleBtn.title = [NSString stringWithFormat:@"● PID ACTIVE  ·  Setpoint: %.1f mK", _physicsEngine.pidSetpoint_mK];
        _pidToggleBtn.contentTintColor = [DRTheme cryoCyan];
    } else {
        _pidToggleBtn.title = @"Enable PID Auto-Regulation";
        _pidToggleBtn.contentTintColor = [DRTheme textMuted];
    }
}

@end






















































