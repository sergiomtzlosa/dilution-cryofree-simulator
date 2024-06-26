#import "DRGuideView.h"
#import "DRTheme.h"
#import "DRAudioSynthesizer.h"

@interface DRGuideView ()

@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DRFlippedView *documentView;
@property (nonatomic, strong) NSView *contentView;

@property (nonatomic, strong) NSTextField *stepBadgeLabel;
@property (nonatomic, strong) NSTextField *stepTitleLabel;
@property (nonatomic, strong) NSTextView *stepDescTextView;
@property (nonatomic, strong) NSTextField *stepActionLabel;
@property (nonatomic, strong) NSBox *actionGuideBox;
@property (nonatomic, strong) NSTextField *stepStatusLabel;

@property (nonatomic, strong) NSButton *executeStepBtn;
@property (nonatomic, strong) NSButton *prevStepBtn;
@property (nonatomic, strong) NSButton *nextStepBtn;

// All nine cooling steps are visible at once. Each row jumps directly to
// that step, so the guide can never look like a five-step procedure.
@property (nonatomic, strong) NSMutableArray<NSButton *> *stepRowButtons;

@end

@implementation DRGuideView

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine {
    self = [super initWithFrame:NSMakeRect(0, 0, 360, 800)];
    if (self) {
        _physicsEngine = engine;
        _stepRowButtons = [NSMutableArray array];
        [self setupUI];
        [self updateGuideState];
    }
    return self;
}

- (void)setupUI {
    self.wantsLayer = YES;
    self.layer.backgroundColor = [DRTheme surfaceDark].CGColor;

    _scrollView = [[NSScrollView alloc] initWithFrame:self.bounds];
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.autohidesScrollers = NO;
    _scrollView.scrollerStyle = NSScrollerStyleOverlay;
    _scrollView.drawsBackground = NO;
    [self addSubview:_scrollView];

    // Flipped document view: opens at the procedure header, not the bottom.
    CGFloat totalHeight = 640;
    _documentView = [[DRFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 340, totalHeight)];
    _scrollView.documentView = _documentView;

    _contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 340, totalHeight)];
    _contentView.autoresizingMask = NSViewWidthSizable;
    [_documentView addSubview:_contentView];

    CGFloat yPos = totalHeight - 40;

    // Header
    NSTextField *titleLabel = [DRTheme styledLabelWithText:@"OPERATIONAL PROCEDURE GUIDE" font:[DRTheme titleFont] color:[DRTheme cryoCyan]];
    titleLabel.frame = NSMakeRect(16, yPos, 310, 22);
    [_contentView addSubview:titleLabel];

    NSTextField *subLabel = [DRTheme styledLabelWithText:@"Nine-step cooldown & dilution refrigeration procedure" font:[DRTheme smallFont] color:[DRTheme textMuted]];
    subLabel.frame = NSMakeRect(16, yPos - 18, 310, 16);
    [_contentView addSubview:subLabel];

    yPos -= 55;

    // ── Step navigator: a compact 3×3 grid, so all nine steps are visible
    //    at the same time even in the minimum-height sidebar.
    NSBox *sequenceCard = [DRTheme styledCard];
    sequenceCard.frame = NSMakeRect(12, yPos - 158, 316, 158);
    [_contentView addSubview:sequenceCard];

    NSTextField *seqHeader = [DRTheme styledLabelWithText:@"9-STEP COOLDOWN SEQUENCE" font:[DRTheme subtitleFont] color:[DRTheme textPrimary]];
    seqHeader.frame = NSMakeRect(14, 134, 290, 18);
    [sequenceCard addSubview:seqHeader];

    NSTextField *seqSub = [DRTheme styledLabelWithText:@"Tap any step to jump directly to that stage:" font:[DRTheme smallFont] color:[DRTheme textMuted]];
    seqSub.frame = NSMakeRect(14, 116, 290, 16);
    [sequenceCard addSubview:seqSub];

    for (NSInteger i = 0; i < 9; i++) {
        NSInteger col = i % 3;
        NSInteger rowIndex = i / 3;
        NSButton *row = [[NSButton alloc] initWithFrame:NSMakeRect(12 + col * 100, 84 - rowIndex * 32, 94, 26)];
        row.bezelStyle = NSBezelStyleRounded;
        row.controlSize = NSControlSizeSmall;
        row.alignment = NSTextAlignmentCenter;
        row.font = [DRTheme monoFontWithSize:9.5];
        row.tag = i;
        row.target = self;
        row.action = @selector(jumpToStepRow:);
        row.cell.lineBreakMode = NSLineBreakByTruncatingTail;
        [sequenceCard addSubview:row];
        [_stepRowButtons addObject:row];
    }

    // ── Current step detail card ───────────────────────────────────────────
    yPos -= 168;
    NSBox *stepCard = [DRTheme styledCard];
    stepCard.frame = NSMakeRect(12, yPos - 334, 316, 334);
    [_contentView addSubview:stepCard];

    _stepBadgeLabel = [DRTheme styledLabelWithText:@"STEP 1 OF 9" font:[DRTheme boldMonoFontWithSize:11.0] color:[DRTheme cryoCyan]];
    _stepBadgeLabel.frame = NSMakeRect(14, 312, 180, 18);
    [stepCard addSubview:_stepBadgeLabel];

    _stepStatusLabel = [DRTheme styledLabelWithText:@"● IN PROGRESS" font:[DRTheme boldMonoFontWithSize:10.5] color:[DRTheme warningAmber]];
    _stepStatusLabel.alignment = NSTextAlignmentRight;
    _stepStatusLabel.frame = NSMakeRect(160, 312, 140, 18);
    [stepCard addSubview:_stepStatusLabel];

    _stepTitleLabel = [DRTheme styledLabelWithText:@"1. Pre-Run Room Temp Checks" font:[DRTheme subtitleFont] color:[DRTheme textPrimary]];
    _stepTitleLabel.frame = NSMakeRect(14, 282, 288, 24);
    _stepTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [stepCard addSubview:_stepTitleLabel];

    _stepDescTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(14, 145, 288, 128)];
    _stepDescTextView.editable = NO;
    _stepDescTextView.selectable = YES;
    _stepDescTextView.drawsBackground = NO;
    _stepDescTextView.font = [DRTheme bodyFont];
    _stepDescTextView.textColor = [DRTheme textSecondary];
    [stepCard addSubview:_stepDescTextView];

    // Action Guide Box
    _actionGuideBox = [[NSBox alloc] initWithFrame:NSMakeRect(14, 84, 288, 46)];
    _actionGuideBox.boxType = NSBoxCustom;
    _actionGuideBox.fillColor = [DRTheme surfaceElevated];
    _actionGuideBox.borderColor = [DRTheme borderSubtle];
    _actionGuideBox.cornerRadius = 6.0;
    _actionGuideBox.titlePosition = NSNoTitle;
    [stepCard addSubview:_actionGuideBox];

    _stepActionLabel = [DRTheme styledLabelWithText:@"Action required: ..." font:[DRTheme smallFont] color:[DRTheme cryoCyan]];
    _stepActionLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _stepActionLabel.maximumNumberOfLines = 0;
    _stepActionLabel.cell.wraps = YES;
    _stepActionLabel.cell.usesSingleLineMode = NO;
    _stepActionLabel.frame = NSMakeRect(8, 4, 260, 26);
    [_actionGuideBox addSubview:_stepActionLabel];

    // Execute Button
    _executeStepBtn = [DRTheme styledAccentButtonWithTitle:@"Auto-Execute This Step" target:self action:@selector(executeCurrentStep:)];
    _executeStepBtn.frame = NSMakeRect(14, 46, 288, 30);
    _executeStepBtn.image = [NSImage imageWithSystemSymbolName:@"play.circle.fill" accessibilityDescription:nil];
    _executeStepBtn.imagePosition = NSImageLeading;
    [stepCard addSubview:_executeStepBtn];

    // Prev / Next Navigation
    _prevStepBtn = [DRTheme styledButtonWithTitle:@"◄ Previous" iconName:nil target:self action:@selector(previousStep:)];
    _prevStepBtn.frame = NSMakeRect(14, 10, 136, 26);
    [stepCard addSubview:_prevStepBtn];

    _nextStepBtn = [DRTheme styledButtonWithTitle:@"Next Step ►" iconName:nil target:self action:@selector(nextStep:)];
    _nextStepBtn.frame = NSMakeRect(166, 10, 136, 26);
    [stepCard addSubview:_nextStepBtn];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scrollToTop];
        });
    }
}

- (void)scrollToTop {
    [_scrollView.contentView scrollToPoint:NSZeroPoint];
    [_scrollView reflectScrolledClipView:_scrollView.contentView];
}

- (NSString *)shortTitleForStep:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0: return @"Room";
        case 1: return @"Vacuum";
        case 2: return @"Pre-Cool";
        case 3: return @"Purge";
        case 4: return @"Condense";
        case 5: return @"Circulate";
        case 6: return @"2-Phase";
        case 7: return @"Base 10mK";
        case 8: return @"Recovery";
        default: return @"Step";
    }
}

#pragma mark - Actions

- (void)jumpToStepRow:(NSButton *)sender {
    if (!_physicsEngine) return;
    [[DRAudioSynthesizer sharedSynthesizer] playValveClick];
    [_physicsEngine jumpToWorkflowStep:sender.tag];
    [self updateGuideState];
    [self scrollToTop];
}

- (void)executeCurrentStep:(id)sender {
    if (!_physicsEngine) return;
    [[DRAudioSynthesizer sharedSynthesizer] playValveClick];
    [_physicsEngine autoConfigureForStep:_physicsEngine.currentWorkflowStep];
    [self updateGuideState];
}

- (void)previousStep:(id)sender {
    if (!_physicsEngine) return;
    [_physicsEngine retreatWorkflowStep];
    [self updateGuideState];
}

- (void)nextStep:(id)sender {
    if (!_physicsEngine) return;
    [_physicsEngine advanceWorkflowStep];
    [self updateGuideState];
}

#pragma mark - State Update

- (void)layoutActionGuideForText:(NSString *)text {
    // NSBox insets its content view by 6 pt on each side. Keep 8 pt of inner
    // padding around the wrapped action text and grow the box upward from its
    // fixed bottom edge so every step's message is fully visible.
    CGFloat boxWidth = 288.0;
    CGFloat contentWidth = boxWidth - 12.0;
    CGFloat textWidth = contentWidth - 16.0;

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{
        NSFontAttributeName: _stepActionLabel.font ?: [DRTheme smallFont],
        NSParagraphStyleAttributeName: paragraph
    };
    NSRect textBounds = [text boundingRectWithSize:NSMakeSize(textWidth, CGFLOAT_MAX)
                                           options:(NSStringDrawingUsesLineFragmentOrigin |
                                                    NSStringDrawingUsesFontLeading)
                                        attributes:attributes];
    CGFloat textHeight = ceil(textBounds.size.height);
    CGFloat labelHeight = textHeight + 2.0;
    CGFloat boxHeight = labelHeight + 20.0; // 12 pt NSBox inset + 8 pt padding

    _actionGuideBox.frame = NSMakeRect(14, 84, boxWidth, boxHeight);
    CGFloat contentHeight = boxHeight - 12.0;
    _stepActionLabel.frame = NSMakeRect(8, MAX(2.0, (contentHeight - labelHeight) / 2.0),
                                        textWidth, labelHeight);
}

- (void)updateGuideState {
    if (!_physicsEngine) return;

    NSInteger step = _physicsEngine.currentWorkflowStep;
    NSInteger total = [_physicsEngine totalWorkflowSteps];

    _stepBadgeLabel.stringValue = [NSString stringWithFormat:@"STEP %ld OF %ld", (long)(step + 1), (long)total];
    _stepTitleLabel.stringValue = [_physicsEngine workflowStepTitle:step];
    _stepDescTextView.string = [_physicsEngine workflowStepDescription:step];
    _stepActionLabel.stringValue = [_physicsEngine workflowStepActionGuide:step];
    [self layoutActionGuideForText:_stepActionLabel.stringValue];

    BOOL isDone = [_physicsEngine isWorkflowStepCompleted:step];
    if (isDone) {
        _stepStatusLabel.stringValue = @"● COMPLETED";
        _stepStatusLabel.textColor = [DRTheme phosphorGreen];
    } else {
        _stepStatusLabel.stringValue = @"● IN PROGRESS";
        _stepStatusLabel.textColor = [DRTheme warningAmber];
    }

    _prevStepBtn.enabled = (step > 0);
    _nextStepBtn.enabled = (step < total - 1);

    // Refresh the nine visible rows: current, completed, or pending. Earlier
    // steps stay checked even when a later phase turns off a pump, so the
    // checklist reads as a sequential procedure rather than live interlocks.
    for (NSInteger i = 0; i < (NSInteger)_stepRowButtons.count; i++) {
        NSButton *row = _stepRowButtons[i];
        BOOL rowDone = (i < step) || (i == step && [_physicsEngine isWorkflowStepCompleted:i]);
        NSString *marker = (i == step) ? @"▶" : (rowDone ? @"✓" : @"○");
        NSString *title = [NSString stringWithFormat:@"%@ %ld. %@", marker, (long)(i + 1), [self shortTitleForStep:i]];

        NSColor *color = (i == step) ? [DRTheme cryoCyan] : (rowDone ? [DRTheme phosphorGreen] : [DRTheme textSecondary]);
        NSDictionary *attrs = @{
            NSFontAttributeName: [DRTheme monoFontWithSize:9.5],
            NSForegroundColorAttributeName: color
        };
        row.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
        row.contentTintColor = color;
        row.toolTip = [_physicsEngine workflowStepDescription:i];
    }
}

@end
















































