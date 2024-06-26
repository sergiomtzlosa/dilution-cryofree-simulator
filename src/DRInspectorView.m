#import "DRInspectorView.h"
#import "DRTheme.h"

@interface DRInspectorView ()

@property (nonatomic, assign) DRCryoComponentID currentComponentID;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) DRFlippedView *documentView;
@property (nonatomic, strong) DRFlippedView *contentView;
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *subtitleLabel;
@property (nonatomic, strong) NSPopUpButton *componentPopUp;
@property (nonatomic, strong) NSBox *specCard;
@property (nonatomic, strong) NSBox *physicsCard;
@property (nonatomic, strong) NSBox *engineeringCard;
@property (nonatomic, strong) NSTextField *componentNameLabel;
@property (nonatomic, strong) NSTextField *tempRangeLabel;
@property (nonatomic, strong) NSTextField *materialLabel;
@property (nonatomic, strong) NSTextField *physicsHeaderLabel;
@property (nonatomic, strong) NSTextField *engineeringHeaderLabel;
@property (nonatomic, strong) NSTextView *physicsDescTextView;
@property (nonatomic, strong) NSTextView *engineeringTextView;
@property (nonatomic, strong) NSButton *focusCameraBtn;

@end

@implementation DRInspectorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self setupUI];
        [self inspectComponent:DRCryoComponentMixingChamber];
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

    CGFloat totalHeight = 730;
    _documentView = [[DRFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 340, totalHeight)];
    _scrollView.documentView = _documentView;

    // A flipped content view lets the dossier stack cards from the top down.
    // Their heights are recalculated from the wrapped text on every selection.
    _contentView = [[DRFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 340, totalHeight)];
    _contentView.autoresizingMask = NSViewWidthSizable;
    [_documentView addSubview:_contentView];

    // Header
    _titleLabel = [DRTheme styledLabelWithText:@"COMPONENT DOSSIER & PHYSICS" font:[DRTheme titleFont] color:[DRTheme cryoCyan]];
    _titleLabel.frame = NSMakeRect(16, 22, 310, 22);
    [_contentView addSubview:_titleLabel];

    _subtitleLabel = [DRTheme styledLabelWithText:@"Scientific Specifications & Operational Theory" font:[DRTheme smallFont] color:[DRTheme textMuted]];
    _subtitleLabel.frame = NSMakeRect(16, 48, 310, 16);
    [_contentView addSubview:_subtitleLabel];

    // Dropdown Component Selector
    _componentPopUp = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(14, 82, 312, 26) pullsDown:NO];
    _componentPopUp.font = [DRTheme boldBodyFont];
    _componentPopUp.target = self;
    _componentPopUp.action = @selector(popUpSelectionChanged:);

    NSArray *items = @[
        @"Mixing Chamber (~10 mK)",
        @"Still Stage (~0.8 K)",
        @"Continuous Spiral Heat Exchanger",
        @"Step Heat Exchangers (Sintered Silver)",
        @"Cold Plate Flange (~100 mK)",
        @"4K Flange & Condenser",
        @"4K Radiation Shield",
        @"50K Flange & Braids",
        @"50K Radiation Shield",
        @"Pulse Tube Cryocooler",
        @"Outer Vacuum Chamber (OVC)",
        @"300K Top Flange & Feedthroughs",
        @"Quantum Sample Puck Stage",
        @"RF Coaxial Lines & SMA Attenuators"
    ];
    for (NSString *item in items) {
        [_componentPopUp addItemWithTitle:item];
    }
    [_contentView addSubview:_componentPopUp];

    // Spec Card
    _specCard = [DRTheme styledCard];
    _specCard.frame = NSMakeRect(12, 122, 316, 130);
    [_contentView addSubview:_specCard];

    _componentNameLabel = [DRTheme styledLabelWithText:@"Mixing Chamber" font:[DRTheme subtitleFont] color:[DRTheme cryoCyan]];
    _componentNameLabel.frame = NSMakeRect(14, 90, 276, 20);
    [self configureWrappedLabel:_componentNameLabel];
    [_specCard addSubview:_componentNameLabel];

    _tempRangeLabel = [DRTheme styledLabelWithText:@"Temp: 7 mK - 20 mK" font:[DRTheme boldMonoFontWithSize:10.5] color:[DRTheme phosphorGreen]];
    _tempRangeLabel.frame = NSMakeRect(14, 64, 276, 18);
    [self configureWrappedLabel:_tempRangeLabel];
    [_specCard addSubview:_tempRangeLabel];

    _materialLabel = [DRTheme styledLabelWithText:@"Material: OFHC Copper (Gold-Plated)" font:[DRTheme monoFontWithSize:9.5] color:[DRTheme textSecondary]];
    _materialLabel.frame = NSMakeRect(14, 40, 276, 18);
    [self configureWrappedLabel:_materialLabel];
    [_specCard addSubview:_materialLabel];

    _focusCameraBtn = [DRTheme styledButtonWithTitle:@"Focus in 3D View" iconName:@"scope" target:self action:@selector(focusCameraClicked:)];
    _focusCameraBtn.frame = NSMakeRect(14, 6, 276, 26);
    [_specCard addSubview:_focusCameraBtn];

    // Physics Function Card
    _physicsCard = [DRTheme styledCard];
    _physicsCard.frame = NSMakeRect(12, 266, 316, 240);
    [_contentView addSubview:_physicsCard];

    _physicsHeaderLabel = [DRTheme styledLabelWithText:@"CRYOGENIC PHYSICS & OPERATION" font:[DRTheme subtitleFont] color:[DRTheme textPrimary]];
    _physicsHeaderLabel.frame = NSMakeRect(14, 208, 276, 18);
    [_physicsCard addSubview:_physicsHeaderLabel];

    _physicsDescTextView = [self bodyTextViewWithFont:[DRTheme bodyFont]];
    [_physicsCard addSubview:_physicsDescTextView];

    // Engineering & Quantum Notes Card
    _engineeringCard = [DRTheme styledCard];
    _engineeringCard.frame = NSMakeRect(12, 520, 316, 200);
    [_contentView addSubview:_engineeringCard];

    _engineeringHeaderLabel = [DRTheme styledLabelWithText:@"ENGINEERING & QUANTUM DETAILS" font:[DRTheme subtitleFont] color:[DRTheme textPrimary]];
    _engineeringHeaderLabel.frame = NSMakeRect(14, 168, 276, 18);
    [_engineeringCard addSubview:_engineeringHeaderLabel];

    _engineeringTextView = [self bodyTextViewWithFont:[DRTheme smallFont]];
    [_engineeringCard addSubview:_engineeringTextView];
}

- (void)configureWrappedLabel:(NSTextField *)label {
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.cell.wraps = YES;
    label.cell.usesSingleLineMode = NO;
}

- (NSTextView *)bodyTextViewWithFont:(NSFont *)font {
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(14, 12, 276, 100)];
    textView.editable = NO;
    textView.selectable = YES;
    textView.drawsBackground = NO;
    textView.font = font;
    textView.textColor = [DRTheme textSecondary];
    textView.textContainerInset = NSZeroSize;
    textView.textContainer.lineFragmentPadding = 0.0;
    textView.textContainer.widthTracksTextView = YES;
    textView.horizontallyResizable = NO;
    textView.verticallyResizable = NO;
    return textView;
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

#pragma mark - Dynamic Dossier Layout

- (CGFloat)wrappedHeightForLabel:(NSTextField *)label width:(CGFloat)width {
    if (label.stringValue.length == 0) return 0.0;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    NSDictionary *attributes = @{
        NSFontAttributeName: label.font ?: [DRTheme bodyFont],
        NSParagraphStyleAttributeName: paragraph
    };
    NSRect bounds = [label.stringValue boundingRectWithSize:NSMakeSize(width, CGFLOAT_MAX)
                                                   options:(NSStringDrawingUsesLineFragmentOrigin |
                                                            NSStringDrawingUsesFontLeading)
                                                attributes:attributes];
    return MAX(18.0, ceil(bounds.size.height) + 2.0);
}

- (CGFloat)heightForTextView:(NSTextView *)textView width:(CGFloat)width {
    if (textView.string.length == 0) return 20.0;
    textView.textContainer.widthTracksTextView = YES;
    textView.textContainer.lineFragmentPadding = 0.0;
    textView.textContainerInset = NSZeroSize;
    [textView setFrameSize:NSMakeSize(width, 10000.0)];
    [textView.layoutManager ensureLayoutForTextContainer:textView.textContainer];
    NSRect used = [textView.layoutManager usedRectForTextContainer:textView.textContainer];
    return MAX(20.0, ceil(used.size.height) + 2.0);
}

- (void)layoutDossier {
    const CGFloat cardX = 12.0;
    const CGFloat cardW = 316.0;
    const CGFloat innerX = 14.0;
    const CGFloat innerW = 276.0;

    CGFloat nameH = [self wrappedHeightForLabel:_componentNameLabel width:innerW];
    CGFloat tempH = [self wrappedHeightForLabel:_tempRangeLabel width:innerW];
    CGFloat materialH = [self wrappedHeightForLabel:_materialLabel width:innerW];
    CGFloat physicsTextH = [self heightForTextView:_physicsDescTextView width:innerW];
    CGFloat engineeringTextH = [self heightForTextView:_engineeringTextView width:innerW];

    // Card content: 12 pt bottom inset, 26 pt button, then the three labels;
    // NSBox itself reserves another 12 pt vertically around its content view.
    CGFloat specContentH = 6.0 + 26.0 + 12.0 + materialH + 6.0 + tempH + 8.0 + nameH + 4.0;
    CGFloat specH = ceil(specContentH + 12.0);
    CGFloat physicsH = ceil(physicsTextH + 58.0);
    CGFloat engineeringH = ceil(engineeringTextH + 58.0);

    CGFloat requiredHeight = 122.0 + specH + 14.0 + physicsH + 14.0 + engineeringH + 20.0;
    CGFloat totalHeight = MAX(730.0, requiredHeight);

    _documentView.frame = NSMakeRect(0, 0, 340, totalHeight);
    _contentView.frame = NSMakeRect(0, 0, 340, totalHeight);

    _specCard.frame = NSMakeRect(cardX, 122.0, cardW, specH);
    _physicsCard.frame = NSMakeRect(cardX, 122.0 + specH + 14.0, cardW, physicsH);
    _engineeringCard.frame = NSMakeRect(cardX, 122.0 + specH + 14.0 + physicsH + 14.0,
                                        cardW, engineeringH);

    // Spec card uses bottom-left coordinates inside its NSBox content view.
    _focusCameraBtn.frame = NSMakeRect(innerX, 6.0, innerW, 26.0);
    _materialLabel.frame = NSMakeRect(innerX, 44.0, innerW, materialH);
    CGFloat tempY = 44.0 + materialH + 6.0;
    _tempRangeLabel.frame = NSMakeRect(innerX, tempY, innerW, tempH);
    CGFloat nameY = tempY + tempH + 8.0;
    _componentNameLabel.frame = NSMakeRect(innerX, nameY, innerW, nameH);

    _physicsDescTextView.frame = NSMakeRect(innerX, 12.0, innerW, physicsTextH);
    _physicsHeaderLabel.frame = NSMakeRect(innerX, physicsTextH + 20.0, innerW, 18.0);

    _engineeringTextView.frame = NSMakeRect(innerX, 12.0, innerW, engineeringTextH);
    _engineeringHeaderLabel.frame = NSMakeRect(innerX, engineeringTextH + 20.0, innerW, 18.0);

    [_contentView setNeedsLayout:YES];
    [_contentView setNeedsDisplay:YES];
}

#pragma mark - Component Selection

- (void)popUpSelectionChanged:(NSPopUpButton *)sender {
    NSInteger idx = sender.indexOfSelectedItem;
    DRCryoComponentID targetID = DRCryoComponentMixingChamber;
    switch (idx) {
        case 0: targetID = DRCryoComponentMixingChamber; break;
        case 1: targetID = DRCryoComponentStillStage; break;
        case 2: targetID = DRCryoComponentContinuousExchanger; break;
        case 3: targetID = DRCryoComponentStepExchangers; break;
        case 4: targetID = DRCryoComponentColdPlate; break;
        case 5: targetID = DRCryoComponent4KFlange; break;
        case 6: targetID = DRCryoComponent4KShield; break;
        case 7: targetID = DRCryoComponent50KFlange; break;
        case 8: targetID = DRCryoComponent50KShield; break;
        case 9: targetID = DRCryoComponentPulseTube; break;
        case 10: targetID = DRCryoComponentOVC; break;
        case 11: targetID = DRCryoComponentTopFlange300K; break;
        case 12: targetID = DRCryoComponentSamplePuck; break;
        case 13: targetID = DRCryoComponentRFCoaxLines; break;
    }
    [self inspectComponent:targetID];
}

- (void)focusCameraClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(inspectorViewDidRequestFocusOnComponent:)]) {
        [self.delegate inspectorViewDidRequestFocusOnComponent:_currentComponentID];
    }
}

- (void)inspectComponent:(DRCryoComponentID)componentID {
    _currentComponentID = componentID;
    
    NSString *name = @"";
    NSString *temp = @"";
    NSString *material = @"";
    NSString *physics = @"";
    NSString *engineering = @"";
    NSInteger popUpIndex = 0;
    
    switch (componentID) {
        case DRCryoComponentMixingChamber:
            popUpIndex = 0;
            name = @"Mixing Chamber (MC)";
            temp = @"Operating Temp: 7.0 mK – 20.0 mK (Base)";
            material = @"Material: High-Purity OFHC Copper (Gold Plated)";
            physics = @"The thermodynamic core of the dilution refrigerator. Liquid helium spontaneously separates into two phases below 0.87 K: an upper concentrated phase of almost pure He-3 and a lower dilute phase of He-4 with 6.6% dissolved He-3.\n\nCooling power is generated when He-3 atoms are pumped across the phase boundary into the dilute phase:\nQ_dot = n_dot * [84*T_mc^2 - 12*T_ex^2].\nEnergy is absorbed directly from the isolated mixing chamber.";
            engineering = @"• Equipped with calibrated Ruthenium Oxide (RuO2) and CMN mutual inductance thermometers.\n• Diagnostic heater enables heat-load characterization and closed-loop PID temperature sweeps from 10 mK to 1.0 K.\n• Gold plating prevents surface oxidation and preserves low contact thermal resistance.";
            break;
            
        case DRCryoComponentStillStage:
            popUpIndex = 1;
            name = @"Still Chamber & Still Flange";
            temp = @"Operating Temp: 0.70 K – 0.85 K";
            material = @"Material: OFHC Copper with RuO2 Thermometer";
            physics = @"The Still distills He-3 out of the dilute liquid mixture. At 0.75 K, the saturated vapor pressure of He-3 (~0.16 mbar) is roughly 80 times higher than that of He-4 (~0.002 mbar). The evaporated vapor is therefore ~90-95% pure He-3.\n\nThe Still Heater provides the latent heat of vaporization necessary to sustain a steady circulation rate (250-400 µmol/s). Without heating, vapor pressure drops and circulation halts.";
            engineering = @"• Features a wide central pumping throat tube ascending to the 300K top flange.\n• Suppresses superfluid He-4 film rollin creep using a razor-sharp orifice aperture.\n• Operates at high vacuum suction backed by dry scroll and turbomolecular pumps.";
            break;
            
        case DRCryoComponentContinuousExchanger:
            popUpIndex = 2;
            name = @"Continuous Counterflow Heat Exchanger";
            temp = @"Temperature Gradient: 0.8 K (top) → 0.12 K (bottom)";
            material = @"Material: Coiled Cupronickel / Copper Capillary";
            physics = @"Incoming concentrated He-3 returning from the 4K condenser must be pre-cooled before entering the mixing chamber. The outgoing dilute stream from the MC flows upward through this spiral counterflow heat exchanger, absorbing thermal energy from the incoming high-pressure stream.";
            engineering = @"• Coiled spiral geometry provides long effective thermal exchange length within a compact vertical envelope.\n• Flow impedance is calibrated to prevent premature vaporization and optimize heat transfer.";
            break;
            
        case DRCryoComponentStepExchangers:
            popUpIndex = 3;
            name = @"Step Heat Exchangers (Sintered Silver)";
            temp = @"Temperature Range: 15 mK – 120 mK";
            material = @"Material: Sub-micron Sintered Silver Powder in Copper Bodies";
            physics = @"At sub-100 mK temperatures, heat exchange between liquid helium and solid metal is severely limited by acoustic phonon mismatch known as Kapitza Boundary Resistance (R_K ∝ T⁻³).\n\nTo overcome this, step heat exchangers use sintered ultra-fine silver powder, expanding effective contact surface area by several orders of magnitude (hundreds of square meters).";
            engineering = @"• 4 to 6 discrete discrete cascading stages isolate thermal gradients.\n• Connects between the Cold Plate and Mixing Chamber.";
            break;
            
        case DRCryoComponentColdPlate:
            popUpIndex = 4;
            name = @"Cold Plate Flange";
            temp = @"Operating Temp: ~100 mK – 150 mK";
            material = @"Material: Gold-Plated OFHC Copper";
            physics = @"Intermediate thermal anchor plate located below the Still. Thermalizes cryogenic wiring, coaxial cable attenuators, and microwave filters to minimize conducted heat leaks into the millikelvin stages.";
            engineering = @"• Hosts microwave cryogenic attenuators (-10 dB / -20 dB).\n• Mechanically supported by high-stiffness, low-conductivity G10 struts.";
            break;
            
        case DRCryoComponent4KFlange:
            popUpIndex = 5;
            name = @"4K Flange & Mixture Condenser";
            temp = @"Operating Temp: 2.8 K – 4.2 K";
            material = @"Material: OFHC Copper anchored to Pulse Tube Stage 2";
            physics = @"Thermalizes at the 2nd stage of the Pulse Tube Cryocooler. Liquid helium-3 and helium-4 gas mixture enters here from the storage dump tanks and liquifies under pressure across a calibrated main flow impedance (~10¹¹ cm⁻³).";
            engineering = @"• Includes activated charcoal sorption cold traps to scrub residual nitrogen, oxygen, and hydrogen from circulating gas.\n• Primary thermal intercept for all incoming measurement lines.";
            break;
            
        case DRCryoComponent4KShield:
            popUpIndex = 6;
            name = @"4K Radiation Shield";
            temp = @"Operating Temp: ~3.0 K – 4.2 K";
            material = @"Material: Polished Gold-Plated Copper Shell";
            physics = @"Blocks blackbody thermal radiation emitted by the 50K stage. According to Stefan-Boltzmann radiation law (P = ε σ A T⁴), dropping shield temperature from 50K to 4K reduces thermal radiation power by a factor of (50/4)⁴ ≈ 24,000 times!";
            engineering = @"• Encloses Still, Cold Plate, and Mixing Chamber in an ultra-low radiative heat environment.";
            break;
            
        case DRCryoComponent50KFlange:
            popUpIndex = 7;
            name = @"50K Flange & Thermal Braids";
            temp = @"Operating Temp: 40 K – 55 K";
            material = @"Material: Gold-Plated Copper with Flexible Braids";
            physics = @"Cooled by the 1st stage of the Pulse Tube Cryocooler, which provides massive cooling power (~35 Watts at 50K) to extract the bulk of conduction and radiation heat originating at 300 K.";
            engineering = @"• Connected to pulse tube head via highly flexible high-purity copper braids to decouple mechanical vibrations from sensitive quantum samples.";
            break;
            
        case DRCryoComponent50KShield:
            popUpIndex = 8;
            name = @"50K Radiation Shield";
            temp = @"Operating Temp: ~45 K – 55 K";
            material = @"Material: Gold-Plated / Polished Copper Cylinder";
            physics = @"The outermost radiation shield intercepting blackbody radiation from the 300K vacuum jacket. Absorbs over 98% of room temperature radiation power before it can reach the 4K and mK stages.";
            engineering = @"• Dismantles easily in modular segments during sample exchange.";
            break;
            
        case DRCryoComponentPulseTube:
            popUpIndex = 9;
            name = @"Pulse Tube Cryocooler (PT)";
            temp = @"Stages: 50 K (Stage 1) & 3 K (Stage 2)";
            material = @"Material: Stainless Steel Regenerators & Helium Rotary Valve";
            physics = @"Enables cryogen-free ('dry') operation with zero liquid helium replenishment. Oscillating high-pressure helium gas driven by an external compressor expands periodically inside pulse tube tubes at ~1.4 Hz, transporting heat to external cooling water.";
            engineering = @"• Completely eliminates cryogen boil-off.\n• No cold moving parts in the cryostat, ensuring exceptional uptime (>20,000 continuous hours).";
            break;
            
        case DRCryoComponentOVC:
            popUpIndex = 10;
            name = @"Outer Vacuum Chamber (OVC)";
            temp = @"Temperature: 295 K (Room Ambient)";
            material = @"Material: Stainless Steel 316L / Aluminum";
            physics = @"Eliminates gas convection and conduction by sustaining high vacuum (< 10⁻⁶ mbar). Without this vacuum enclosure, atmospheric air would freeze on the cold plates, creating catastrophic thermal short circuits.";
            engineering = @"• Fitted with O-ring / ISO quick-release vacuum seals and optical viewports.\n• Can be evacuated with the turbomolecular pumping station.";
            break;
            
        case DRCryoComponentTopFlange300K:
            popUpIndex = 11;
            name = @"300K Top Flange & Feedthrough Collar";
            temp = @"Temperature: 295 K";
            material = @"Material: Precision Machined Stainless Steel";
            physics = @"Mechanical foundation of the cryostat, supporting the entire hanging mass on rigid low-vibration ceiling or tripod mounts.";
            engineering = @"• Houses vacuum pumping ports, gas handling manifold connections, multi-pin DC connectors, and microwave SMA hermetic feedthroughs.";
            break;
            
        case DRCryoComponentSamplePuck:
            popUpIndex = 12;
            name = @"Quantum Processor Sample Stage";
            temp = @"Operating Temp: ~10 mK (Ultra-Pure Ground State)";
            material = @"Material: Gold-Plated OFHC Copper with Mu-Metal Magnetic Shield";
            physics = @"At 10 mK, thermal energy k_B*T (~0.86 µeV) is far below superconducting qubit transition frequencies (h*f ~ 20 µeV for 5 GHz transmon qubits), keeping qubits safely in their quantum ground state with minimal thermal decoherence.";
            engineering = @"• Features quick-loading sample puck docking mechanism.\n• Protected by nested magnetic shields (cryogenic Mu-metal and superconducting niobium cylinder) against stray geomagnetic fields.";
            break;
            
        case DRCryoComponentRFCoaxLines:
            popUpIndex = 13;
            name = @"Cryogenic RF Coaxial Lines";
            temp = @"Gradient: 300 K → 50 K → 4 K → Still → CP → MC";
            material = @"Material: Semi-Rigid Copper / NbTi with Gold SMA Attenuators";
            physics = @"Delivers microwave control and readout pulses to quantum processors. Attenuators thermalize the inner coax conductors at each stage (e.g., -20 dB at 4K, -20 dB at MC) to suppress room-temperature blackbody photon noise.";
            engineering = @"• Uses low-loss superconducting NbTi cables below 4K to prevent ohmic heating.\n• Integrated with cryogenic low-noise HEMT and traveling-wave parametric amplifiers (TWPAs).";
            break;
            
        default: break;
    }
    
    [_componentPopUp selectItemAtIndex:popUpIndex];
    _componentNameLabel.stringValue = name;
    _tempRangeLabel.stringValue = temp;
    _materialLabel.stringValue = material;
    _physicsDescTextView.string = physics;
    _engineeringTextView.string = engineering;
    [self layoutDossier];

    if (self.window) {
        [self scrollToTop];
    }
}

@end













































