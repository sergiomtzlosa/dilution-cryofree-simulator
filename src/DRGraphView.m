#import "DRGraphView.h"
#import "DRTheme.h"

@interface DRGraphView ()

@property (nonatomic, strong) NSMutableArray<NSNumber *> *history50K;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *history4K;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *historyStill;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *historyColdPlate;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *historyMC;

@property (nonatomic, strong) NSButton *scaleToggleBtn;
@property (nonatomic, strong) NSButton *clearBtn;

@end

@implementation DRGraphView

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine {
    self = [super initWithFrame:NSMakeRect(0, 0, 360, 800)];
    if (self) {
        _physicsEngine = engine;
        _isLogarithmicScale = YES;
        _history50K = [NSMutableArray arrayWithCapacity:150];
        _history4K = [NSMutableArray arrayWithCapacity:150];
        _historyStill = [NSMutableArray arrayWithCapacity:150];
        _historyColdPlate = [NSMutableArray arrayWithCapacity:150];
        _historyMC = [NSMutableArray arrayWithCapacity:150];
        
        [self setupControls];
    }
    return self;
}

- (void)setupControls {
    _scaleToggleBtn = [DRTheme styledButtonWithTitle:@"Scale: LOG (10 mK – 300 K)" iconName:@"chart.xyaxis.line" target:self action:@selector(toggleScale:)];
    _scaleToggleBtn.frame = NSMakeRect(16, 12, 235, 26);
    _scaleToggleBtn.font = [DRTheme smallFont];
    [self addSubview:_scaleToggleBtn];
    
    _clearBtn = [DRTheme styledButtonWithTitle:@"Reset" iconName:@"trash" target:self action:@selector(clearHistoryClicked:)];
    _clearBtn.frame = NSMakeRect(257, 12, 85, 26);
    _clearBtn.font = [DRTheme smallFont];
    [self addSubview:_clearBtn];
}

- (void)toggleScale:(id)sender {
    _isLogarithmicScale = !_isLogarithmicScale;
    if (_isLogarithmicScale) {
        _scaleToggleBtn.title = @"Scale: LOG (10 mK – 300 K)";
    } else {
        _scaleToggleBtn.title = @"Scale: LINEAR (0 – 1000 mK)";
    }
    [self setNeedsDisplay:YES];
}

- (void)clearHistoryClicked:(id)sender {
    [self clearHistory];
    [self setNeedsDisplay:YES];
}

- (void)recordDataPoint {
    if (!_physicsEngine) return;
    
    const NSUInteger maxPoints = 120;
    
    [_history50K addObject:@(_physicsEngine.temp50K)];
    if (_history50K.count > maxPoints) [_history50K removeObjectAtIndex:0];
    
    [_history4K addObject:@(_physicsEngine.temp4K)];
    if (_history4K.count > maxPoints) [_history4K removeObjectAtIndex:0];
    
    [_historyStill addObject:@(_physicsEngine.tempStill)];
    if (_historyStill.count > maxPoints) [_historyStill removeObjectAtIndex:0];
    
    [_historyColdPlate addObject:@(_physicsEngine.tempColdPlate)];
    if (_historyColdPlate.count > maxPoints) [_historyColdPlate removeObjectAtIndex:0];
    
    [_historyMC addObject:@(_physicsEngine.tempMixingChamber)];
    if (_historyMC.count > maxPoints) [_historyMC removeObjectAtIndex:0];
    
    [self setNeedsDisplay:YES];
}

- (void)clearHistory {
    [_history50K removeAllObjects];
    [_history4K removeAllObjects];
    [_historyStill removeAllObjects];
    [_historyColdPlate removeAllObjects];
    [_historyMC removeAllObjects];
    [self setNeedsDisplay:YES];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    
    // Background fill
    CGContextSetFillColorWithColor(ctx, [DRTheme surfaceDark].CGColor);
    CGContextFillRect(ctx, self.bounds);
    
    // Plot Area — leave room at the top for the two-line live legend.
    NSRect plotRect = NSMakeRect(45, 60, self.bounds.size.width - 65, self.bounds.size.height - 165);
    CGContextSetFillColorWithColor(ctx, [DRTheme surfaceElevated].CGColor);
    CGContextFillRect(ctx, plotRect);
    
    CGContextSetStrokeColorWithColor(ctx, [DRTheme borderSubtle].CGColor);
    CGContextSetLineWidth(ctx, 1.0);
    CGContextStrokeRect(ctx, plotRect);
    
    // Title
    NSString *header = @"LIVE TEMPERATURE OSCILLOSCOPE";
    NSDictionary *headerAttr = @{
        NSFontAttributeName: [DRTheme titleFont],
        NSForegroundColorAttributeName: [DRTheme cryoCyan]
    };
    [header drawAtPoint:NSMakePoint(16, self.bounds.size.height - 35) withAttributes:headerAttr];
    
    // Grid Lines & Axis Labels
    [self drawGridAndLabelsInRect:plotRect context:ctx];
    
    // Traces. In the 0–1000 mK linear zoom, the 50 K and 4 K stages are
    // intentionally omitted instead of being clamped into a misleading
    // horizontal line at the top of the chart.
    if (_isLogarithmicScale) {
        [self drawTrace:_history50K color:[DRTheme steelMetallic] inRect:plotRect context:ctx];
        [self drawTrace:_history4K color:[DRTheme goldMetallic] inRect:plotRect context:ctx];
    } else {
        NSDictionary *noteAttr = @{
            NSFontAttributeName: [DRTheme monoFontWithSize:8.5],
            NSForegroundColorAttributeName: [DRTheme textMuted]
        };
        [@"mK zoom — 50 K / 4 K hidden; values >1 K clip at top" drawAtPoint:NSMakePoint(plotRect.origin.x + 8, plotRect.origin.y + plotRect.size.height - 16)
                                                                    withAttributes:noteAttr];
    }
    [self drawTrace:_historyStill color:[DRTheme warningAmber] inRect:plotRect context:ctx];
    [self drawTrace:_historyColdPlate color:[DRTheme copperMetallic] inRect:plotRect context:ctx];
    [self drawTrace:_historyMC color:[DRTheme cryoCyan] inRect:plotRect context:ctx];
    
    // Live legend at top, including each stage's current numerical reading.
    [self drawLegendAtY:self.bounds.size.height - 70];
}

- (void)drawGridAndLabelsInRect:(NSRect)rect context:(CGContextRef)ctx {
    NSDictionary *labelAttr = @{
        NSFontAttributeName: [DRTheme monoFontWithSize:9.0],
        NSForegroundColorAttributeName: [DRTheme textMuted]
    };
    
    if (_isLogarithmicScale) {
        // Log scale decades: 10 mK (0.01K), 100 mK (0.1K), 1 K, 10 K, 100 K, 300 K
        double decades[] = {0.01, 0.1, 1.0, 10.0, 100.0, 300.0};
        const char *decadeLabels[] = {"10mK", "100mK", "1K", "10K", "100K", "300K"};
        
        for (int i = 0; i < 6; i++) {
            double val = decades[i];
            CGFloat yNorm = [self normalizedYForKelvin:val];
            CGFloat y = rect.origin.y + (yNorm * rect.size.height);
            
            // Grid line
            CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithCalibratedWhite:0.25 alpha:0.4].CGColor);
            CGContextSetLineWidth(ctx, 0.5);
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, rect.origin.x, y);
            CGContextAddLineToPoint(ctx, rect.origin.x + rect.size.width, y);
            CGContextStrokePath(ctx);
            
            // Label
            NSString *str = [NSString stringWithUTF8String:decadeLabels[i]];
            [str drawAtPoint:NSMakePoint(4, y - 6) withAttributes:labelAttr];
        }
    } else {
        // Linear scale 0 to 1000 mK
        for (int mK = 0; mK <= 1000; mK += 200) {
            CGFloat yNorm = (CGFloat)mK / 1000.0;
            CGFloat y = rect.origin.y + (yNorm * rect.size.height);
            
            CGContextSetStrokeColorWithColor(ctx, [NSColor colorWithCalibratedWhite:0.25 alpha:0.4].CGColor);
            CGContextSetLineWidth(ctx, 0.5);
            CGContextBeginPath(ctx);
            CGContextMoveToPoint(ctx, rect.origin.x, y);
            CGContextAddLineToPoint(ctx, rect.origin.x + rect.size.width, y);
            CGContextStrokePath(ctx);
            
            NSString *str = [NSString stringWithFormat:@"%dmK", mK];
            [str drawAtPoint:NSMakePoint(4, y - 6) withAttributes:labelAttr];
        }
    }
}

- (CGFloat)normalizedYForKelvin:(double)kelvin {
    if (_isLogarithmicScale) {
        // log10(0.008) ~ -2.1 to log10(300) ~ 2.47
        double minLog = -2.0; // 0.01 K
        double maxLog = 2.48; // ~300 K
        double logVal = log10(MAX(0.008, kelvin));
        CGFloat norm = (CGFloat)((logVal - minLog) / (maxLog - minLog));
        return MIN(1.0, MAX(0.0, norm));
    } else {
        // Linear 0 to 1.0 K (1000 mK)
        return (CGFloat)(MIN(1.0, MAX(0.0, kelvin / 1.0)));
    }
}

- (void)drawTrace:(NSArray<NSNumber *> *)points color:(NSColor *)color inRect:(NSRect)rect context:(CGContextRef)ctx {
    if (points.count < 2) return;
    
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeZero, 4.0, color.CGColor);
    CGContextSetStrokeColorWithColor(ctx, color.CGColor);
    CGContextSetLineWidth(ctx, 2.2);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextBeginPath(ctx);
    
    CGFloat dx = rect.size.width / (CGFloat)(points.count - 1);
    for (NSUInteger i = 0; i < points.count; i++) {
        double val = [points[i] doubleValue];
        CGFloat yNorm = [self normalizedYForKelvin:val];
        CGFloat x = rect.origin.x + (i * dx);
        CGFloat y = rect.origin.y + (yNorm * rect.size.height);
        
        if (i == 0) {
            CGContextMoveToPoint(ctx, x, y);
        } else {
            CGContextAddLineToPoint(ctx, x, y);
        }
    }
    CGContextStrokePath(ctx);
    CGContextRestoreGState(ctx);
}

- (NSString *)compactTemperature:(double)kelvin {
    if (kelvin >= 1.0) {
        return [NSString stringWithFormat:@"%.2fK", kelvin];
    } else if (kelvin >= 0.1) {
        return [NSString stringWithFormat:@"%.0fmK", kelvin * 1000.0];
    } else {
        return [NSString stringWithFormat:@"%.1fmK", kelvin * 1000.0];
    }
}

- (void)drawLegendAtY:(CGFloat)y {
    double t50 = _physicsEngine ? _physicsEngine.temp50K : 0.0;
    double t4 = _physicsEngine ? _physicsEngine.temp4K : 0.0;
    double tStill = _physicsEngine ? _physicsEngine.tempStill : 0.0;
    double tCP = _physicsEngine ? _physicsEngine.tempColdPlate : 0.0;
    double tMC = _physicsEngine ? _physicsEngine.tempMixingChamber : 0.0;

    NSArray *items = @[
        @{@"name": @"50K", @"color": [DRTheme steelMetallic], @"value": @(t50)},
        @{@"name": @"4K", @"color": [DRTheme goldMetallic], @"value": @(t4)},
        @{@"name": @"Still", @"color": [DRTheme warningAmber], @"value": @(tStill)},
        @{@"name": @"CP", @"color": [DRTheme copperMetallic], @"value": @(tCP)},
        @{@"name": @"MC", @"color": [DRTheme cryoCyan], @"value": @(tMC)}
    ];

    NSDictionary *nameAttr = @{
        NSFontAttributeName: [DRTheme boldMonoFontWithSize:10.0],
        NSForegroundColorAttributeName: [DRTheme textPrimary]
    };
    NSDictionary *valueAttr = @{
        NSFontAttributeName: [DRTheme monoFontWithSize:9.0],
        NSForegroundColorAttributeName: [DRTheme textSecondary]
    };

    CGFloat x = 16;
    for (NSDictionary *d in items) {
        NSColor *c = d[@"color"];
        NSString *name = d[@"name"];
        NSString *value = [self compactTemperature:[d[@"value"] doubleValue]];

        NSRect dotRect = NSMakeRect(x, y + 2, 8, 8);
        [c setFill];
        [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];

        [name drawAtPoint:NSMakePoint(x + 12, y) withAttributes:nameAttr];
        [value drawAtPoint:NSMakePoint(x + 12, y - 11) withAttributes:valueAttr];

        x += 65;
    }
}

@end
















































