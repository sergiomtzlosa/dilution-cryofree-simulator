#import "AppDelegate.h"
#import "DRTheme.h"
#import "DRAudioSynthesizer.h"

@interface AppDelegate ()

@property (nonatomic, assign) BOOL isUISetup;
@property (nonatomic, strong) DRPhysicsEngine *physicsEngine;
@property (nonatomic, strong) DRCryostatScene *cryoScene;
@property (nonatomic, strong) NSView *viewportContainer;
@property (nonatomic, strong) SCNView *scnView;

// Aside Panel Views
@property (nonatomic, strong) NSSplitView *splitView;
@property (nonatomic, strong) NSView *asideContainer;
@property (nonatomic, strong) NSSegmentedControl *tabSelector;
@property (nonatomic, strong) DRControlPanelView *controlPanelView;
@property (nonatomic, strong) DRGuideView *guideView;
@property (nonatomic, strong) DRInspectorView *inspectorView;
@property (nonatomic, strong) DRGraphView *graphView;

// Top Bar Elements
@property (nonatomic, strong) NSTextField *phaseBadgeLabel;
@property (nonatomic, strong) NSTextField *mcTempBadgeLabel;
@property (nonatomic, strong) NSSegmentedControl *cameraSelector;
@property (nonatomic, strong) NSSlider *explodeSlider;
@property (nonatomic, strong) NSSegmentedControl *speedSegment;
@property (nonatomic, strong) NSButton *muteBtn;

// Bottom 3D Viewport HUD
@property (nonatomic, strong) NSBox *viewportHUD;
@property (nonatomic, strong) NSTextField *hudStatusLabel;

@property (nonatomic, strong) NSTimer *simulationTimer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self setupApplicationUI];
    // Start audio engine after the run loop is running
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[DRAudioSynthesizer sharedSynthesizer] ensureEngineRunning];
    });
}

- (void)setupApplicationUI {
    if (_isUISetup) return;
    _isUISetup = YES;
    
    _physicsEngine = [DRPhysicsEngine sharedEngine];
    
    [self setupWindow];
    [self setupTopToolbar];
    [self setup3DViewport];
    [self setupAsidePanel];
    [self setupViewportHUD];
    
    // Start simulation loop at 30 Hz
    _simulationTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                        target:self
                                                      selector:@selector(simulationLoop:)
                                                      userInfo:nil
                                                       repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_simulationTimer forMode:NSRunLoopCommonModes];
    
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Window Setup

- (void)setupWindow {
    NSScreen *screen = [NSScreen mainScreen] ?: [NSScreen screens].firstObject;
    NSRect screenRect = [screen visibleFrame];
    CGFloat width = MIN(1360.0, screenRect.size.width - 40.0);
    CGFloat height = MIN(820.0, screenRect.size.height - 40.0);
    NSRect windowRect = NSMakeRect(screenRect.origin.x + (screenRect.size.width - width) / 2.0,
                                   screenRect.origin.y + (screenRect.size.height - height) / 2.0,
                                   width, height);
    
    _window = [[NSWindow alloc] initWithContentRect:windowRect
                                          styleMask:(NSWindowStyleMaskTitled |
                                                     NSWindowStyleMaskClosable |
                                                     NSWindowStyleMaskMiniaturizable |
                                                     NSWindowStyleMaskResizable |
                                                     NSWindowStyleMaskFullSizeContentView)
                                            backing:NSBackingStoreBuffered
                                              defer:NO];
    _window.title = @"Cryogen-Free Dilution Refrigerator Simulator";
    _window.titleVisibility = NSWindowTitleHidden;
    _window.titlebarAppearsTransparent = YES;
    _window.backgroundColor = [DRTheme backgroundDark];
    _window.minSize = NSMakeSize(1100, 700);
    _window.delegate = self;
    
    NSView *contentView = _window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [DRTheme backgroundDark].CGColor;
    
    // Split view dividing 3D Viewport (left) and Aside Control Panel (right)
    _splitView = [[NSSplitView alloc] initWithFrame:NSMakeRect(0, 0, width, height - 56)];
    _splitView.vertical = YES;
    _splitView.dividerStyle = NSSplitViewDividerStyleThin;
    _splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _splitView.delegate = self;
    [contentView addSubview:_splitView];
}

- (void)windowDidResize:(NSNotification *)notification {
    [self pinAsidePanelWidth];
}

- (void)pinAsidePanelWidth {
    if (!_asideContainer || _splitView.subviews.count < 2) return;

    // NSSplitView proportionally rescales its children on window resize,
    // which clips the controls. Pin the instrumentation panel to 360 pt.
    CGFloat width = _splitView.bounds.size.width;
    CGFloat desiredPosition = MAX(620.0, width - 360.0);
    if (fabs(_splitView.subviews[0].frame.size.width - desiredPosition) > 0.5) {
        [_splitView setPosition:desiredPosition ofDividerAtIndex:0];
    }
}

#pragma mark - Top Toolbar

- (void)setupTopToolbar {
    NSView *contentView = _window.contentView;
    CGFloat width = contentView.bounds.size.width;
    CGFloat height = contentView.bounds.size.height;
    
    NSView *topBar = [[NSView alloc] initWithFrame:NSMakeRect(0, height - 56, width, 56)];
    topBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    topBar.wantsLayer = YES;
    topBar.layer.backgroundColor = [DRTheme surfaceDark].CGColor;
    [contentView addSubview:topBar];
    
    // Bottom border line — drawn in drawRect via a sublayer with autoresizing
    CALayer *border = [CALayer layer];
    border.frame = CGRectMake(0, 0, width, 1.0);
    border.backgroundColor = [DRTheme borderSubtle].CGColor;
    border.autoresizingMask = kCALayerWidthSizable;
    [topBar.layer addSublayer:border];
    
    // ── LEFT BLOCK: Logo + title (top row) ─────────────────────
    NSTextField *logo = [DRTheme styledLabelWithText:@"CRYO"
                                               font:[DRTheme boldMonoFontWithSize:13.5]
                                              color:[DRTheme cryoCyan]];
    logo.frame = NSMakeRect(88, 30, 80, 18);
    [topBar addSubview:logo];
    
    // Thin separator
    NSBox *sep = [[NSBox alloc] initWithFrame:NSMakeRect(172, 30, 1, 18)];
    sep.boxType = NSBoxSeparator;
    [topBar addSubview:sep];
    
    NSTextField *title = [DRTheme styledLabelWithText:@"Cryofree Dilution Simulator"
                                                 font:[DRTheme boldBodyFont]
                                                color:[DRTheme textPrimary]];
    title.frame = NSMakeRect(180, 30, 200, 18);
    [topBar addSubview:title];
    
    // ── LEFT BLOCK: Phase badge + MC temp (bottom row) ─────────
    _phaseBadgeLabel = [DRTheme styledLabelWithText:@"● 300 K ROOM TEMP"
                                               font:[DRTheme boldMonoFontWithSize:10.0]
                                              color:[DRTheme steelMetallic]];
    _phaseBadgeLabel.frame = NSMakeRect(88, 8, 160, 16);
    [topBar addSubview:_phaseBadgeLabel];
    
    _mcTempBadgeLabel = [DRTheme styledLabelWithText:@"MC: 295.0 K"
                                               font:[DRTheme boldMonoFontWithSize:10.5]
                                              color:[DRTheme cryoCyan]];
    _mcTempBadgeLabel.frame = NSMakeRect(252, 8, 100, 16);
    [topBar addSubview:_mcTempBadgeLabel];
    
    // ── RIGHT BLOCK: buttons anchored to right edge ─────────────
    // Reset button — rightmost
    NSButton *resetBtn = [DRTheme styledButtonWithTitle:@"Reset 300K"
                                               iconName:@"arrow.counterclockwise"
                                                 target:self
                                                 action:@selector(resetSystemClicked:)];
    resetBtn.frame = NSMakeRect(width - 114, 14, 106, 28);
    resetBtn.autoresizingMask = NSViewMinXMargin;
    [topBar addSubview:resetBtn];
    
    // Mute button — left of reset
    _muteBtn = [DRTheme styledButtonWithTitle:@"Sound: ON"
                                     iconName:@"speaker.wave.2.fill"
                                       target:self
                                       action:@selector(toggleMute:)];
    _muteBtn.frame = NSMakeRect(width - 230, 14, 108, 28);
    _muteBtn.autoresizingMask = NSViewMinXMargin;
    [topBar addSubview:_muteBtn];
    
    // Sim Speed segment — left of mute
    NSTextField *speedLabel = [DRTheme styledLabelWithText:@"Speed:"
                                                      font:[DRTheme smallFont]
                                                     color:[DRTheme textMuted]];
    speedLabel.frame = NSMakeRect(width - 362, 34, 48, 14);
    speedLabel.autoresizingMask = NSViewMinXMargin;
    [topBar addSubview:speedLabel];
    
    _speedSegment = [NSSegmentedControl segmentedControlWithLabels:@[@"1×", @"5×", @"20×", @"100×"]
                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                           target:self
                                                           action:@selector(speedChanged:)];
    _speedSegment.selectedSegment = 1; // 5× default
    _speedSegment.frame = NSMakeRect(width - 360, 14, 122, 22);
    _speedSegment.font = [DRTheme smallFont];
    _speedSegment.autoresizingMask = NSViewMinXMargin;
    [topBar addSubview:_speedSegment];
    
    // ── CENTER BLOCK: Camera presets + explode slider ───────────
    // A fixed-width container keeps the two rows aligned while the window
    // resizes. Resizing each control with flexible margins independently
    // would let the label drift into the slider knob.
    CGFloat centerX = floor(width / 2.0) - 145.0;
    NSView *centerBlock = [[NSView alloc] initWithFrame:NSMakeRect(centerX, 6, 290, 48)];
    centerBlock.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
    [topBar addSubview:centerBlock];

    NSSegmentedControl *camSeg = [NSSegmentedControl
        segmentedControlWithLabels:@[@"Overview", @"Dilution Core", @"Mixing Chamber", @"Exploded"]
                      trackingMode:NSSegmentSwitchTrackingSelectOne
                            target:self
                            action:@selector(cameraSegmentChanged:)];
    camSeg.segmentDistribution = NSSegmentDistributionFillEqually;
    camSeg.selectedSegment = 0;
    camSeg.frame = NSMakeRect(0, 24, 290, 22);
    camSeg.font = [DRTheme smallFont];
    _cameraSelector = camSeg;
    [centerBlock addSubview:camSeg];
    
    // Disassemble slider (bottom row, centre)
    NSTextField *expLabel = [DRTheme styledLabelWithText:@"Shields:"
                                                    font:[DRTheme smallFont]
                                                   color:[DRTheme textMuted]];
    expLabel.frame = NSMakeRect(0, 5, 52, 14);
    [centerBlock addSubview:expLabel];
    
    // Leave clearance for the knob at its leftmost (0 %) position.
    _explodeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(58, 2, 232, 18)];
    _explodeSlider.minValue = 0.0;
    _explodeSlider.maxValue = 1.0;
    _explodeSlider.doubleValue = 0.0;
    _explodeSlider.target = self;
    _explodeSlider.action = @selector(explodeSliderChanged:);
    [centerBlock addSubview:_explodeSlider];
}


#pragma mark - 3D Viewport

- (void)setup3DViewport {
    _cryoScene = [[DRCryostatScene alloc] initWithPhysicsEngine:_physicsEngine];
    _cryoScene.cryoDelegate = self;
    
    // Keep the SCNView and the HUD in separate sibling views. This prevents
    // SceneKit's camera gestures from swallowing clicks aimed at the HUD
    // buttons (Reset View / Disassemble Shields).
    _viewportContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 850, 750)];
    _viewportContainer.wantsLayer = YES;
    _viewportContainer.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.03 green:0.04 blue:0.06 alpha:1.0].CGColor;

    _scnView = [[SCNView alloc] initWithFrame:_viewportContainer.bounds];
    _scnView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scnView.scene = _cryoScene;
    _scnView.pointOfView = _cryoScene.cameraNode;
    _scnView.backgroundColor = [NSColor colorWithCalibratedRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    _scnView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    _scnView.preferredFramesPerSecond = 60;
    _scnView.autoenablesDefaultLighting = NO;
    _scnView.allowsCameraControl = YES; // Built-in fluid 3D orbit, pan, zoom!
    
    // Add Click Gesture Recognizer for component selection
    NSClickGestureRecognizer *clickRecognizer = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(viewportClicked:)];
    clickRecognizer.delaysPrimaryMouseButtonEvents = NO;
    [_scnView addGestureRecognizer:clickRecognizer];
    
    [_viewportContainer addSubview:_scnView];
    [_splitView addSubview:_viewportContainer];
}

- (void)viewportClicked:(NSClickGestureRecognizer *)recognizer {
    NSPoint p = [recognizer locationInView:_scnView];
    [_cryoScene handleHitTestAtPoint:p inView:_scnView];
}

#pragma mark - Aside Panel Setup

- (void)setupAsidePanel {
    _asideContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 750)];
    _asideContainer.wantsLayer = YES;
    _asideContainer.layer.backgroundColor = [DRTheme surfaceDark].CGColor;
    
    // Tab Segmented Control at top of aside panel
    _tabSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"Front Panel", @"Guide", @"Dossier", @"Graph"]
                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                           target:self
                                                           action:@selector(tabChanged:)];
    _tabSelector.segmentDistribution = NSSegmentDistributionFillEqually;
    _tabSelector.selectedSegment = 0;
    _tabSelector.font = [DRTheme boldBodyFont];
    _tabSelector.frame = NSMakeRect(12, _asideContainer.bounds.size.height - 40, 336, 28);
    _tabSelector.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [_asideContainer addSubview:_tabSelector];
    
    NSRect subFrame = NSMakeRect(0, 0, 360, _asideContainer.bounds.size.height - 46);
    
    _controlPanelView = [[DRControlPanelView alloc] initWithPhysicsEngine:_physicsEngine];
    _controlPanelView.frame = subFrame;
    _controlPanelView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [_asideContainer addSubview:_controlPanelView];
    
    _guideView = [[DRGuideView alloc] initWithPhysicsEngine:_physicsEngine];
    _guideView.frame = subFrame;
    _guideView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _guideView.hidden = YES;
    [_asideContainer addSubview:_guideView];
    
    _inspectorView = [[DRInspectorView alloc] initWithFrame:subFrame];
    _inspectorView.delegate = self;
    _inspectorView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _inspectorView.hidden = YES;
    [_asideContainer addSubview:_inspectorView];
    
    _graphView = [[DRGraphView alloc] initWithPhysicsEngine:_physicsEngine];
    _graphView.frame = subFrame;
    _graphView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _graphView.hidden = YES;
    [_asideContainer addSubview:_graphView];
    
    [_splitView addSubview:_asideContainer];
    // The 3D viewport should absorb window resizes; keep the instrumentation
    // panel at its intended 360 pt width instead of clipping it.
    [_splitView setHoldingPriority:250.0 forSubviewAtIndex:0];
    [_splitView setHoldingPriority:490.0 forSubviewAtIndex:1];
    [_splitView setPosition:(_splitView.bounds.size.width - 360) ofDividerAtIndex:0];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex {
    // Keep the instrumentation panel readable and preserve a useful 3D view.
    CGFloat minimumViewport = 620.0;
    CGFloat maximumPosition = splitView.bounds.size.width - 360.0;
    return MAX(minimumViewport, MIN(maximumPosition, proposedPosition));
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO;
}

#pragma mark - Viewport HUD

- (void)setupViewportHUD {
    CGFloat hudWidth = MAX(0.0, _viewportContainer.bounds.size.width - 40.0);
    CGFloat hudHeight = 44.0;
    _viewportHUD = [DRTheme styledCard];
    _viewportHUD.frame = NSMakeRect(20, 20, hudWidth, hudHeight);
    // Span the full viewport width while staying anchored to the bottom edge.
    _viewportHUD.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
    [_viewportContainer addSubview:_viewportHUD];

    CGFloat resetWidth = 108.0;
    CGFloat coreWidth = 210.0;
    CGFloat buttonGap = 8.0;
    CGFloat rightInset = 14.0;
    CGFloat labelInset = 14.0;
    CGFloat labelGap = 12.0;
    CGFloat labelWidth = MAX(120.0, hudWidth - labelInset - labelGap -
                             resetWidth - buttonGap - coreWidth - rightInset);

    // NSBox reserves 6 pt of padding around its content view. Keep the text
    // and controls vertically centred inside the slimmer bar.
    CGFloat contentHeight = hudHeight - 12.0;
    CGFloat buttonHeight = 26.0;
    CGFloat buttonY = MAX(2.0, (contentHeight - buttonHeight) / 2.0);
    CGFloat labelHeight = 18.0;
    CGFloat labelY = MAX(1.0, (contentHeight - labelHeight) / 2.0);

    _hudStatusLabel = [DRTheme styledLabelWithText:@"Cryostat: Intact  |  Drag • Click to Inspect" font:[DRTheme boldMonoFontWithSize:11.0] color:[DRTheme textPrimary]];
    _hudStatusLabel.frame = NSMakeRect(labelInset, labelY, labelWidth, labelHeight);
    _hudStatusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _hudStatusLabel.autoresizingMask = NSViewWidthSizable;
    [_viewportHUD addSubview:_hudStatusLabel];

    NSButton *resetViewBtn = [DRTheme styledButtonWithTitle:@"Reset View" iconName:@"arrow.counterclockwise" target:self action:@selector(resetViewClicked:)];
    resetViewBtn.frame = NSMakeRect(hudWidth - rightInset - coreWidth - buttonGap - resetWidth, buttonY, resetWidth, buttonHeight);
    resetViewBtn.autoresizingMask = NSViewMinXMargin;
    [_viewportHUD addSubview:resetViewBtn];

    NSButton *quickCoreBtn = [DRTheme styledButtonWithTitle:@"Disassemble Shields" iconName:@"eye" target:self action:@selector(quickExposeCore:)];
    quickCoreBtn.frame = NSMakeRect(hudWidth - rightInset - coreWidth, buttonY, coreWidth, buttonHeight);
    quickCoreBtn.autoresizingMask = NSViewMinXMargin;
    [_viewportHUD addSubview:quickCoreBtn];
}

#pragma mark - Actions & Toolbar Callbacks

- (void)tabChanged:(NSSegmentedControl *)sender {
    _controlPanelView.hidden = (sender.selectedSegment != 0);
    _guideView.hidden = (sender.selectedSegment != 1);
    _inspectorView.hidden = (sender.selectedSegment != 2);
    _graphView.hidden = (sender.selectedSegment != 3);

    // Each tab opens at its own top instead of inheriting a scrolled offset.
    switch (sender.selectedSegment) {
        case 0: [_controlPanelView scrollToTop]; break;
        case 1:
            [_guideView updateGuideState];
            [_guideView scrollToTop];
            break;
        case 2: [_inspectorView scrollToTop]; break;
        default: break;
    }
}

#pragma mark - Camera & Focus Coordination

- (BOOL)componentNeedsRevealedCore:(DRCryoComponentID)componentID {
    switch (componentID) {
        case DRCryoComponentStillStage:
        case DRCryoComponentContinuousExchanger:
        case DRCryoComponentColdPlate:
        case DRCryoComponentStepExchangers:
        case DRCryoComponentMixingChamber:
        case DRCryoComponentSamplePuck:
        case DRCryoComponentRFCoaxLines:
            return YES;
        default:
            return NO;
    }
}

- (NSString *)displayNameForComponent:(DRCryoComponentID)componentID {
    switch (componentID) {
        case DRCryoComponentTopFlange300K: return @"300 K Top Flange";
        case DRCryoComponentPulseTube: return @"Pulse Tube Cryocooler";
        case DRCryoComponentOVC: return @"Outer Vacuum Chamber";
        case DRCryoComponent50KShield: return @"50 K Radiation Shield";
        case DRCryoComponent50KFlange: return @"50 K Flange";
        case DRCryoComponent4KShield: return @"4 K Radiation Shield";
        case DRCryoComponent4KFlange: return @"4 K Flange";
        case DRCryoComponentStillStage: return @"Still Stage";
        case DRCryoComponentContinuousExchanger: return @"Continuous Heat Exchanger";
        case DRCryoComponentColdPlate: return @"Cold Plate";
        case DRCryoComponentStepExchangers: return @"Step Heat Exchangers";
        case DRCryoComponentMixingChamber: return @"Mixing Chamber";
        case DRCryoComponentSamplePuck: return @"Quantum Sample Stage";
        case DRCryoComponentRFCoaxLines: return @"RF Coaxial Lines";
        default: return @"Cryostat";
    }
}

- (void)revealCoreForComponentIfNeeded:(DRCryoComponentID)componentID {
    if (![self componentNeedsRevealedCore:componentID]) return;
    if (_cryoScene.explodeProgress > 0.95) return;

    // Internal stages sit behind three reflective shells. Open the model
    // before focusing so the camera looks at the selected stage instead of
    // the inside of the OVC.
    _explodeSlider.doubleValue = 1.0;
    [self explodeSliderChanged:_explodeSlider];
}

- (void)syncCameraControllerTarget {
    SCNCameraController *controller = _scnView.defaultCameraController;
    if (!controller) return;
    [controller stopInertia];
    controller.target = SCNVector3Make(0, _cryoScene.cameraPivotNode.position.y, 0);
    _scnView.pointOfView = _cryoScene.cameraNode;
}

- (void)showOverviewCamera {
    [_cryoScene resetCamera];
    _cameraSelector.selectedSegment = 0;
    [self syncCameraControllerTarget];

    if (_cryoScene.explodeProgress > 0.05) {
        _hudStatusLabel.stringValue = [NSString stringWithFormat:@"Shields Open: %.0f%%  |  Core Exposed", _cryoScene.explodeProgress * 100.0];
    } else {
        _hudStatusLabel.stringValue = @"Cryostat: Intact  |  Drag • Click to Inspect";
    }
}

- (void)focusOnComponent:(DRCryoComponentID)componentID {
    if ([self componentNeedsRevealedCore:componentID]) {
        [self revealCoreForComponentIfNeeded:componentID];
    } else if (_cryoScene.explodeProgress > 0.05) {
        // Outer shells and the pulse-tube top are faded/slid away in the
        // exploded state. Reassemble so a Dossier focus on those parts does
        // not zoom to an invisible, displaced shell.
        _explodeSlider.doubleValue = 0.0;
        [self explodeSliderChanged:_explodeSlider];
    }
    [_cryoScene focusCameraOnStage:componentID];
    [self syncCameraControllerTarget];
    _hudStatusLabel.stringValue = [NSString stringWithFormat:@"Camera: %@  |  Drag to orbit • Click to inspect",
                                   [self displayNameForComponent:componentID]];
}

- (void)cameraSegmentChanged:(NSSegmentedControl *)sender {
    switch (sender.selectedSegment) {
        case 0: // Overview
            [self showOverviewCamera];
            break;
        case 1: // Dilution Core
            [self focusOnComponent:DRCryoComponentStillStage];
            _hudStatusLabel.stringValue = @"Camera: Dilution Core  |  Drag to orbit • Click to inspect";
            break;
        case 2: // Mixing Chamber
            [self focusOnComponent:DRCryoComponentMixingChamber];
            break;
        case 3: { // Exploded view — always open all three shells.
            _explodeSlider.doubleValue = 1.0;
            [self explodeSliderChanged:_explodeSlider];
            [_cryoScene resetCamera];
            [self syncCameraControllerTarget];
            _cameraSelector.selectedSegment = 3;
            _hudStatusLabel.stringValue = @"Exploded View  |  Shields Open 100%  •  Drag to orbit";
            break;
        }
    }
}

- (void)explodeSliderChanged:(NSSlider *)sender {
    _cryoScene.explodeProgress = sender.doubleValue;
    if (sender.doubleValue > 0.05) {
        _hudStatusLabel.stringValue = [NSString stringWithFormat:@"Shields Open: %.0f%%  |  Core Exposed", sender.doubleValue * 100.0];
    } else {
        _hudStatusLabel.stringValue = @"Cryostat: Intact  |  Drag • Click to Inspect";
        if (_cameraSelector.selectedSegment == 3) {
            _cameraSelector.selectedSegment = 0;
        }
    }
}

- (void)resetViewClicked:(id)sender {
    [self showOverviewCamera];
}

- (void)speedChanged:(NSSegmentedControl *)sender {
    switch (sender.selectedSegment) {
        case 0: _physicsEngine.timeMultiplier = 1.0; break;
        case 1: _physicsEngine.timeMultiplier = 5.0; break;
        case 2: _physicsEngine.timeMultiplier = 20.0; break;
        case 3: _physicsEngine.timeMultiplier = 100.0; break;
    }
}

- (void)toggleMute:(NSButton *)sender {
    DRAudioSynthesizer *synth = [DRAudioSynthesizer sharedSynthesizer];
    synth.isMuted = !synth.isMuted;
    if (synth.isMuted) {
        _muteBtn.title = @"Sound: MUTED";
        _muteBtn.image = [NSImage imageWithSystemSymbolName:@"speaker.slash.fill" accessibilityDescription:nil];
    } else {
        _muteBtn.title = @"Sound: ON";
        _muteBtn.image = [NSImage imageWithSystemSymbolName:@"speaker.wave.2.fill" accessibilityDescription:nil];
    }
}

- (void)resetSystemClicked:(id)sender {
    [_physicsEngine resetToRoomTemperature];
    _explodeSlider.doubleValue = 0.0;
    [self explodeSliderChanged:_explodeSlider];
    [self showOverviewCamera];
    [_graphView clearHistory];
    [_controlPanelView updateTelemetry];
    [_guideView updateGuideState];
}

- (void)quickExposeCore:(id)sender {
    CGFloat target = (_cryoScene.explodeProgress > 0.4) ? 0.0 : 1.0;
    _explodeSlider.doubleValue = target;
    [self explodeSliderChanged:_explodeSlider];
}

#pragma mark - Delegates

- (void)cryostatSceneDidSelectComponent:(DRCryoComponentID)componentID name:(NSString *)name {
    _hudStatusLabel.stringValue = [NSString stringWithFormat:@"Selected: %@  (Detailed in Dossier)", name];
    [_inspectorView inspectComponent:componentID];
    
    // Switch to Dossier tab
    _tabSelector.selectedSegment = 2;
    [self tabChanged:_tabSelector];
    [_inspectorView scrollToTop];
}

- (void)inspectorViewDidRequestFocusOnComponent:(DRCryoComponentID)componentID {
    [self focusOnComponent:componentID];

    // Keep the preset highlight honest when the dossier asks for one of the
    // named stages. Other components have no matching toolbar preset, so
    // clear the highlight instead of leaving a stale "Mixing Chamber" label
    // above an OVC or 4K-shield view.
    if (componentID == DRCryoComponentStillStage) {
        _cameraSelector.selectedSegment = 1;
    } else if (componentID == DRCryoComponentMixingChamber) {
        _cameraSelector.selectedSegment = 2;
    } else if (componentID == DRCryoComponentOVC) {
        _cameraSelector.selectedSegment = 0;
    } else {
        _cameraSelector.selectedSegment = -1;
    }
}

#pragma mark - Simulation Loop (30 Hz)

- (void)simulationLoop:(NSTimer *)timer {
    NSTimeInterval dt = 1.0 / 30.0;
    
    // Step thermodynamic equations
    [_physicsEngine tickWithDeltaTime:dt];
    
    // Update 3D scene visual state
    [_cryoScene updateWithPhysicsState];
    
    // Update Aside Control Panel
    if (!_controlPanelView.hidden) {
        [_controlPanelView updateTelemetry];
    }
    
    // Update Guide View
    if (!_guideView.hidden) {
        [_guideView updateGuideState];
    }
    
    // Record Graph Data point every 3 ticks (~10 Hz)
    static int graphTick = 0;
    if (++graphTick % 3 == 0) {
        [_graphView recordDataPoint];
    }
    
    // Update Top Status Badges
    _phaseBadgeLabel.stringValue = [NSString stringWithFormat:@"● %@", [_physicsEngine.currentPhaseName uppercaseString]];
    if (_physicsEngine.currentPhase >= DRCryoPhaseCirculatingDilution) {
        _phaseBadgeLabel.textColor = [DRTheme cryoCyan];
    } else if (_physicsEngine.currentPhase >= DRCryoPhasePreCoolingPT) {
        _phaseBadgeLabel.textColor = [DRTheme phosphorGreen];
    } else {
        _phaseBadgeLabel.textColor = [DRTheme steelMetallic];
    }
    
    _mcTempBadgeLabel.stringValue = [NSString stringWithFormat:@"MC: %@", [DRTheme formattedTemperature:_physicsEngine.tempMixingChamber]];
}

@end

























































