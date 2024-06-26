#import "DRCryostatScene.h"
#import "DRTheme.h"
#import <math.h>

@interface DRCryostatScene ()

@property (nonatomic, weak) DRPhysicsEngine *physicsEngine;

// Scene Hierarchy Nodes
@property (nonatomic, strong) SCNNode *cryostatRoot;
@property (nonatomic, strong) SCNNode *cameraPivotNode;
@property (nonatomic, strong) SCNNode *cameraNode;

// Component Nodes
@property (nonatomic, strong) SCNNode *topFlangeNode;
@property (nonatomic, strong) SCNNode *ovcNode;
@property (nonatomic, strong) SCNNode *pulseTubeNode;
@property (nonatomic, strong) SCNNode *flange50KNode;
@property (nonatomic, strong) SCNNode *shield50KNode;
@property (nonatomic, strong) SCNNode *flange4KNode;
@property (nonatomic, strong) SCNNode *shield4KNode;
@property (nonatomic, strong) SCNNode *stillNode;
@property (nonatomic, strong) SCNNode *stillHeaterNode;
@property (nonatomic, strong) SCNNode *continuousExchangerNode;
@property (nonatomic, strong) SCNNode *coldPlateNode;
@property (nonatomic, strong) SCNNode *stepExchangersNode;
@property (nonatomic, strong) SCNNode *mixingChamberNode;
@property (nonatomic, strong) SCNNode *samplePuckNode;
@property (nonatomic, strong) SCNNode *rfCoaxNode;
@property (nonatomic, strong) SCNNode *pipingNode;
@property (nonatomic, strong) SCNNode *particlesNode;
@property (nonatomic, strong) SCNNode *labelsRootNode;

// Liquid Helium in MC & Still
@property (nonatomic, strong) SCNNode *mcConcentratedPhaseNode;
@property (nonatomic, strong) SCNNode *mcDilutePhaseNode;
@property (nonatomic, strong) SCNNode *mcPhaseBoundaryNode;
@property (nonatomic, strong) SCNNode *stillLiquidNode;

// Label nodes for live temperature updates
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, SCNNode *> *labelNodes;
@property (nonatomic, assign) DRCryoComponentID selectedComponentID;

// Particle systems (need dynamic birth rate control)
@property (nonatomic, strong) SCNParticleSystem *condenseFlowPS;
@property (nonatomic, strong) SCNParticleSystem *pumpingFlowPS;

- (void)updateExposureForShieldState;

@end

@implementation DRCryostatScene

- (instancetype)initWithPhysicsEngine:(DRPhysicsEngine *)engine {
    self = [super init];
    if (self) {
        _physicsEngine = engine;
        _explodeProgress = 0.0;
        _showOVC = YES;
        _show50KShield = YES;
        _show4KShield = YES;
        _show3DLabels = YES;
        _showFlowParticles = YES;
        _labelNodes = [NSMutableDictionary dictionary];
        
        [self setupEnvironment];
        [self setupCamera];
        [self buildCryostatModel];
        [self setupParticleSystems];
        [self create3DLabels];
        [self updateExposureForShieldState];
    }
    return self;
}

#pragma mark - Environment & Lighting

- (void)setupEnvironment {
    self.background.contents = [NSColor colorWithCalibratedRed:0.03 green:0.04 blue:0.06 alpha:1.0];
    
    // No ground plane and no shadow-casting lights: the cryostat is a
    // see-through technical model, so contact shadows only clutter the view.
    // Every light below is explicitly shadow-free for a clean "CAD" look.

    // Ambient Light — lifts the dark side of the model without shadows
    SCNNode *ambientLight = [SCNNode node];
    ambientLight.light = [SCNLight light];
    ambientLight.light.type = SCNLightTypeAmbient;
    ambientLight.light.castsShadow = NO;
    ambientLight.light.color = [NSColor colorWithCalibratedRed:0.55 green:0.60 blue:0.68 alpha:1.0];
    ambientLight.light.intensity = 600.0;
    [self.rootNode addChildNode:ambientLight];
    
    // Main Studio Key Light
    SCNNode *keyLight = [SCNNode node];
    keyLight.light = [SCNLight light];
    keyLight.light.type = SCNLightTypeDirectional;
    keyLight.light.castsShadow = NO;
    keyLight.light.color = [NSColor colorWithCalibratedRed:0.95 green:0.97 blue:1.0 alpha:1.0];
    keyLight.light.intensity = 800.0;
    keyLight.eulerAngles = SCNVector3Make(-M_PI_4, M_PI_4, 0);
    [self.rootNode addChildNode:keyLight];
    
    // Warm Metallic Fill Light — softly fills the opposite side
    SCNNode *fillLight = [SCNNode node];
    fillLight.light = [SCNLight light];
    fillLight.light.type = SCNLightTypeDirectional;
    fillLight.light.castsShadow = NO;
    fillLight.light.color = [NSColor colorWithCalibratedRed:0.95 green:0.82 blue:0.68 alpha:1.0];
    fillLight.light.intensity = 500.0;
    fillLight.eulerAngles = SCNVector3Make(-M_PI_4 * 0.7, -3.0 * M_PI_4, 0);
    [self.rootNode addChildNode:fillLight];
    
    // Cool rim light — neutral enough to preserve material colours
    SCNNode *rimLight = [SCNNode node];
    rimLight.light = [SCNLight light];
    rimLight.light.type = SCNLightTypeDirectional;
    rimLight.light.castsShadow = NO;
    rimLight.light.color = [NSColor colorWithCalibratedRed:0.55 green:0.65 blue:0.85 alpha:1.0];
    rimLight.light.intensity = 300.0;
    rimLight.eulerAngles = SCNVector3Make(M_PI_4, -M_PI_2, 0);
    [self.rootNode addChildNode:rimLight];
}

- (void)setupCamera {
    _cameraPivotNode = [SCNNode node];
    _cameraPivotNode.position = SCNVector3Make(0, 0.0, 0);
    [self.rootNode addChildNode:_cameraPivotNode];
    
    _cameraNode = [SCNNode node];
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.zNear = 0.1;
    _cameraNode.camera.zFar = 100.0;
    _cameraNode.camera.fieldOfView = 45.0;
    _cameraNode.camera.wantsHDR = YES;
    // Keep the HDR exposure fixed while orbiting. SceneKit's automatic
    // eye-adaptation otherwise brightens the whole cryostat as reflective
    // surfaces swing through the frame, making repeated spins look washed out.
    _cameraNode.camera.wantsExposureAdaptation = NO;
    _cameraNode.camera.exposureOffset = 2.20;
    _cameraNode.position = SCNVector3Make(0, 0.9, 12.6);
    _cameraNode.eulerAngles = SCNVector3Make(-0.07, 0, 0);
    [_cameraPivotNode addChildNode:_cameraNode];
}

#pragma mark - PBR Physically Based Materials

- (SCNMaterial *)goldMaterial {
    SCNMaterial *mat = [SCNMaterial material];
    mat.lightingModelName = SCNLightingModelPhysicallyBased;
    mat.diffuse.contents = [NSColor colorWithCalibratedRed:0.98 green:0.74 blue:0.15 alpha:1.0];
    mat.metalness.contents = @0.45;
    mat.roughness.contents = @0.42;
    return mat;
}

- (SCNMaterial *)copperMaterial {
    SCNMaterial *mat = [SCNMaterial material];
    mat.lightingModelName = SCNLightingModelPhysicallyBased;
    mat.diffuse.contents = [NSColor colorWithCalibratedRed:0.82 green:0.42 blue:0.24 alpha:1.0];
    mat.metalness.contents = @0.42;
    mat.roughness.contents = @0.48;
    return mat;
}

- (SCNMaterial *)stainlessMaterial {
    SCNMaterial *mat = [SCNMaterial material];
    mat.lightingModelName = SCNLightingModelPhysicallyBased;
    mat.diffuse.contents = [NSColor colorWithCalibratedRed:0.58 green:0.64 blue:0.72 alpha:1.0];
    mat.metalness.contents = @0.45;
    mat.roughness.contents = @0.42;
    return mat;
}

- (SCNMaterial *)sinteredSilverMaterial {
    SCNMaterial *mat = [SCNMaterial material];
    mat.lightingModelName = SCNLightingModelPhysicallyBased;
    mat.diffuse.contents = [NSColor colorWithCalibratedRed:0.92 green:0.94 blue:0.96 alpha:1.0];
    mat.metalness.contents = @0.82;
    mat.roughness.contents = @0.50; // Porous sintered texture
    return mat;
}

- (SCNMaterial *)g10CompositeMaterial {
    SCNMaterial *mat = [SCNMaterial material];
    mat.lightingModelName = SCNLightingModelPhysicallyBased;
    mat.diffuse.contents = [NSColor colorWithCalibratedRed:0.58 green:0.62 blue:0.48 alpha:0.95];
    mat.roughness.contents = @0.70;
    mat.metalness.contents = @0.05;
    return mat;
}

#pragma mark - Procedural Geometry Construction

- (void)buildCryostatModel {
    _cryostatRoot = [SCNNode node];
    _cryostatRoot.position = SCNVector3Make(0, 0, 0);
    [self.rootNode addChildNode:_cryostatRoot];
    
    [self buildTopFlange];
    [self buildPulseTube];
    [self buildOVC];
    [self build50KStage];
    [self build4KStage];
    [self buildSupportTrusses];
    [self buildStillStage];
    [self buildContinuousExchanger];
    [self buildColdPlate];
    [self buildStepExchangers];
    [self buildMixingChamber];
    [self buildSamplePuck];
    [self buildPipingNetwork];
    [self buildRFCoaxLines];
}

- (void)buildTopFlange {
    _topFlangeNode = [SCNNode node];
    _topFlangeNode.name = @"TopFlange300K";
    
    // Main circular 300K top flange plate
    SCNCylinder *plateGeom = [SCNCylinder cylinderWithRadius:2.2 height:0.25];
    plateGeom.radialSegmentCount = 128;
    plateGeom.firstMaterial = [self stainlessMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plateGeom];
    plateNode.position = SCNVector3Make(0, 3.8, 0);
    [_topFlangeNode addChildNode:plateNode];
    
    // Flange collar ring with perimeter bolt pattern
    SCNTorus *ringGeom = [SCNTorus torusWithRingRadius:2.2 pipeRadius:0.06];
    ringGeom.firstMaterial = [self stainlessMaterial];
    SCNNode *ringNode = [SCNNode nodeWithGeometry:ringGeom];
    ringNode.position = SCNVector3Make(0, 3.9, 0);
    [_topFlangeNode addChildNode:ringNode];
    
    // Bolts
    for (int i = 0; i < 16; i++) {
        CGFloat angle = (CGFloat)i * (2.0 * M_PI / 16.0);
        SCNCylinder *bolt = [SCNCylinder cylinderWithRadius:0.04 height:0.1];
        bolt.firstMaterial = [self stainlessMaterial];
        SCNNode *boltNode = [SCNNode nodeWithGeometry:bolt];
        boltNode.position = SCNVector3Make(2.08 * cos(angle), 3.95, 2.08 * sin(angle));
        [_topFlangeNode addChildNode:boltNode];
    }
    
    // Pumping port neck (ISO/KF flange)
    SCNCylinder *portGeom = [SCNCylinder cylinderWithRadius:0.28 height:0.55];
    portGeom.firstMaterial = [self stainlessMaterial];
    SCNNode *portNode = [SCNNode nodeWithGeometry:portGeom];
    portNode.position = SCNVector3Make(1.2, 4.15, 0.4);
    [_topFlangeNode addChildNode:portNode];
    
    // Sight Glass Viewport
    SCNCylinder *viewGeom = [SCNCylinder cylinderWithRadius:0.24 height:0.1];
    SCNMaterial *glassMat = [SCNMaterial material];
    glassMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.95 alpha:0.4];
    glassMat.transparency = 0.55;
    viewGeom.firstMaterial = glassMat;
    SCNNode *viewNode = [SCNNode nodeWithGeometry:viewGeom];
    viewNode.position = SCNVector3Make(-1.1, 3.95, 0.7);
    [_topFlangeNode addChildNode:viewNode];
    
    [_cryostatRoot addChildNode:_topFlangeNode];
}

- (void)buildPulseTube {
    _pulseTubeNode = [SCNNode node];
    _pulseTubeNode.name = @"PulseTube";
    
    // PT Motor housing mounted on top flange
    SCNCylinder *motorGeom = [SCNCylinder cylinderWithRadius:0.36 height:0.75];
    SCNMaterial *motorMat = [SCNMaterial material];
    motorMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.15 green:0.18 blue:0.22 alpha:1.0];
    motorMat.metalness.contents = @0.85;
    motorGeom.firstMaterial = motorMat;
    SCNNode *motorNode = [SCNNode nodeWithGeometry:motorGeom];
    motorNode.position = SCNVector3Make(-0.85, 4.35, -0.65);
    [_pulseTubeNode addChildNode:motorNode];
    
    // PT Stage 1 Tube extending down to 50K plate (y: 3.8 to 2.2)
    SCNCylinder *pt1Tube = [SCNCylinder cylinderWithRadius:0.12 height:1.6];
    pt1Tube.firstMaterial = [self stainlessMaterial];
    SCNNode *pt1Node = [SCNNode nodeWithGeometry:pt1Tube];
    pt1Node.position = SCNVector3Make(-0.85, 3.0, -0.65);
    [_pulseTubeNode addChildNode:pt1Node];
    
    // Stage 1 Cold Head block at 50K
    SCNBox *pt1Block = [SCNBox boxWithWidth:0.38 height:0.22 length:0.38 chamferRadius:0.02];
    pt1Block.firstMaterial = [self copperMaterial];
    SCNNode *pt1BlockNode = [SCNNode nodeWithGeometry:pt1Block];
    pt1BlockNode.position = SCNVector3Make(-0.85, 2.2, -0.65);
    [_pulseTubeNode addChildNode:pt1BlockNode];
    
    // Flexible copper thermal braids to 50K plate
    for (int b = -1; b <= 1; b++) {
        SCNCylinder *braid = [SCNCylinder cylinderWithRadius:0.035 height:0.55];
        braid.firstMaterial = [self copperMaterial];
        SCNNode *bNode = [SCNNode nodeWithGeometry:braid];
        bNode.position = SCNVector3Make(-0.55, 2.2, -0.65 + (b * 0.08));
        bNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2);
        [_pulseTubeNode addChildNode:bNode];
    }
    
    // PT Stage 2 Tube extending down to 4K plate (y: 2.2 to 0.8)
    SCNCylinder *pt2Tube = [SCNCylinder cylinderWithRadius:0.09 height:1.4];
    pt2Tube.firstMaterial = [self stainlessMaterial];
    SCNNode *pt2Node = [SCNNode nodeWithGeometry:pt2Tube];
    pt2Node.position = SCNVector3Make(-0.85, 1.5, -0.65);
    [_pulseTubeNode addChildNode:pt2Node];
    
    // Stage 2 Cold Head block at 4K
    SCNBox *pt2Block = [SCNBox boxWithWidth:0.28 height:0.20 length:0.28 chamferRadius:0.02];
    pt2Block.firstMaterial = [self goldMaterial];
    SCNNode *pt2BlockNode = [SCNNode nodeWithGeometry:pt2Block];
    pt2BlockNode.position = SCNVector3Make(-0.85, 0.8, -0.65);
    [_pulseTubeNode addChildNode:pt2BlockNode];
    
    // Copper thermal braids to 4K plate
    SCNCylinder *braid4K = [SCNCylinder cylinderWithRadius:0.04 height:0.55];
    braid4K.firstMaterial = [self copperMaterial];
    SCNNode *b4Node = [SCNNode nodeWithGeometry:braid4K];
    b4Node.position = SCNVector3Make(-0.55, 0.8, -0.65);
    b4Node.eulerAngles = SCNVector3Make(0, 0, M_PI_2);
    [_pulseTubeNode addChildNode:b4Node];
    
    [_cryostatRoot addChildNode:_pulseTubeNode];
}

- (void)buildOVC {
    _ovcNode = [SCNNode node];
    _ovcNode.name = @"OVC";
    
    // Cylindrical outer vacuum jacket
    SCNCylinder *cylGeom = [SCNCylinder cylinderWithRadius:2.05 height:7.6];
    cylGeom.radialSegmentCount = 128;
    SCNMaterial *ovcMat = [SCNMaterial material];
    ovcMat.lightingModelName = SCNLightingModelPhysicallyBased;
    ovcMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.65 green:0.72 blue:0.85 alpha:0.35];
    ovcMat.metalness.contents = @0.85;
    ovcMat.roughness.contents = @0.15;
    ovcMat.transparency = 0.28;
    ovcMat.cullMode = SCNCullModeBack;
    cylGeom.firstMaterial = ovcMat;
    
    SCNNode *cylNode = [SCNNode nodeWithGeometry:cylGeom];
    cylNode.position = SCNVector3Make(0, -0.1, 0);
    [_ovcNode addChildNode:cylNode];
    
    // Bottom dome cap of OVC
    SCNSphere *capGeom = [SCNSphere sphereWithRadius:2.05];
    capGeom.firstMaterial = ovcMat;
    SCNNode *capNode = [SCNNode nodeWithGeometry:capGeom];
    capNode.position = SCNVector3Make(0, -3.9, 0);
    capNode.scale = SCNVector3Make(1.0, 0.25, 1.0);
    [_ovcNode addChildNode:capNode];
    
    [_cryostatRoot addChildNode:_ovcNode];
}

- (void)build50KStage {
    _flange50KNode = [SCNNode node];
    _flange50KNode.name = @"50KFlange";
    
    // Wide 50K flange plate (full-width gold plate, reference layout)
    SCNCylinder *plate50K = [SCNCylinder cylinderWithRadius:1.82 height:0.14];
    plate50K.radialSegmentCount = 128;
    plate50K.firstMaterial = [self goldMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plate50K];
    plateNode.position = SCNVector3Make(0, 2.2, 0);
    [_flange50KNode addChildNode:plateNode];
    
    // Flange collar ring
    SCNTorus *ring50K = [SCNTorus torusWithRingRadius:1.82 pipeRadius:0.055];
    ring50K.firstMaterial = [self goldMaterial];
    SCNNode *ringNode = [SCNNode nodeWithGeometry:ring50K];
    ringNode.position = SCNVector3Make(0, 2.27, 0);
    [_flange50KNode addChildNode:ringNode];
    
    // Bolts around flange perimeter
    for (int i = 0; i < 20; i++) {
        CGFloat angle = (CGFloat)i * (2.0 * M_PI / 20.0);
        SCNCylinder *bolt = [SCNCylinder cylinderWithRadius:0.035 height:0.09];
        bolt.firstMaterial = [self stainlessMaterial];
        SCNNode *boltNode = [SCNNode nodeWithGeometry:bolt];
        boltNode.position = SCNVector3Make(1.72 * cos(angle), 2.31, 1.72 * sin(angle));
        [_flange50KNode addChildNode:boltNode];
    }
    
    [_cryostatRoot addChildNode:_flange50KNode];
    
    // 50K Radiation Shield Cylinder (transparent gold)
    _shield50KNode = [SCNNode node];
    _shield50KNode.name = @"50KShield";
    
    SCNCylinder *shield50KCyl = [SCNCylinder cylinderWithRadius:1.79 height:5.9];
    shield50KCyl.radialSegmentCount = 128;
    SCNMaterial *shield50KMat = [SCNMaterial material];
    shield50KMat.lightingModelName = SCNLightingModelPhysicallyBased;
    shield50KMat.diffuse.contents = [NSColor colorWithCalibratedRed:1.0 green:0.85 blue:0.35 alpha:0.50];
    shield50KMat.metalness.contents = @0.90;
    shield50KMat.roughness.contents = @0.20;
    shield50KMat.transparency = 0.34;
    shield50KMat.cullMode = SCNCullModeBack;
    shield50KMat.writesToDepthBuffer = NO;
    shield50KCyl.firstMaterial = shield50KMat;
    
    SCNNode *shieldNode = [SCNNode nodeWithGeometry:shield50KCyl];
    shieldNode.position = SCNVector3Make(0, -0.75, 0);
    [_shield50KNode addChildNode:shieldNode];
    [_cryostatRoot addChildNode:_shield50KNode];
}


- (void)build4KStage {
    _flange4KNode = [SCNNode node];
    _flange4KNode.name = @"4KFlange";
    
    // Wide 4K Flange plate (copper, distinct from the 50 K gold plate)
    SCNCylinder *plate4K = [SCNCylinder cylinderWithRadius:1.52 height:0.12];
    plate4K.radialSegmentCount = 128;
    plate4K.firstMaterial = [self copperMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plate4K];
    plateNode.position = SCNVector3Make(0, 0.8, 0);
    [_flange4KNode addChildNode:plateNode];
    
    // Flange ring
    SCNTorus *ring4K = [SCNTorus torusWithRingRadius:1.52 pipeRadius:0.048];
    ring4K.firstMaterial = [self copperMaterial];
    SCNNode *ringNode4K = [SCNNode nodeWithGeometry:ring4K];
    ringNode4K.position = SCNVector3Make(0, 0.86, 0);
    [_flange4KNode addChildNode:ringNode4K];
    
    // Mixture condenser coil on 4K plate (prominent in reference image)
    SCNTorus *condenserCoil = [SCNTorus torusWithRingRadius:0.68 pipeRadius:0.050];
    condenserCoil.firstMaterial = [self copperMaterial];
    SCNNode *coilNode = [SCNNode nodeWithGeometry:condenserCoil];
    coilNode.position = SCNVector3Make(0, 0.88, 0);
    [_flange4KNode addChildNode:coilNode];
    
    // Secondary condenser coil (inner)
    SCNTorus *condenserCoil2 = [SCNTorus torusWithRingRadius:0.42 pipeRadius:0.032];
    condenserCoil2.firstMaterial = [self copperMaterial];
    SCNNode *coilNode2 = [SCNNode nodeWithGeometry:condenserCoil2];
    coilNode2.position = SCNVector3Make(0, 0.88, 0);
    [_flange4KNode addChildNode:coilNode2];
    
    // Main Flow Impedance (Z1) coiled capillary
    SCNTorus *z1Coil = [SCNTorus torusWithRingRadius:0.30 pipeRadius:0.020];
    z1Coil.firstMaterial = [self copperMaterial];
    SCNNode *z1Node = [SCNNode nodeWithGeometry:z1Coil];
    z1Node.position = SCNVector3Make(0.45, 0.90, 0.45);
    [_flange4KNode addChildNode:z1Node];
    
    // Dual Charcoal Sorption Cold Traps (vertical cylinders visible in image)
    for (int t = 0; t < 2; t++) {
        SCNCylinder *trapGeom = [SCNCylinder cylinderWithRadius:0.14 height:0.44];
        trapGeom.firstMaterial = [self stainlessMaterial];
        SCNNode *trapNode = [SCNNode nodeWithGeometry:trapGeom];
        CGFloat tx = (t == 0) ? 0.80 : 0.50;
        CGFloat tz = (t == 0) ? -0.50 : -0.80;
        trapNode.position = SCNVector3Make(tx, 1.05, tz);
        [_flange4KNode addChildNode:trapNode];
        
        // Cold trap cap
        SCNCylinder *trapCap = [SCNCylinder cylinderWithRadius:0.16 height:0.04];
        trapCap.firstMaterial = [self copperMaterial];
        SCNNode *capNode = [SCNNode nodeWithGeometry:trapCap];
        capNode.position = SCNVector3Make(tx, 1.30, tz);
        [_flange4KNode addChildNode:capNode];
    }
    
    [_cryostatRoot addChildNode:_flange4KNode];
    
    // 4K Radiation Shield Cylinder
    _shield4KNode = [SCNNode node];
    _shield4KNode.name = @"4KShield";
    
    SCNCylinder *shield4KCyl = [SCNCylinder cylinderWithRadius:1.48 height:4.3];
    shield4KCyl.radialSegmentCount = 128;
    SCNMaterial *shield4KMat = [SCNMaterial material];
    shield4KMat.lightingModelName = SCNLightingModelPhysicallyBased;
    shield4KMat.diffuse.contents = [NSColor colorWithCalibratedRed:1.0 green:0.82 blue:0.25 alpha:0.48];
    shield4KMat.metalness.contents = @0.88;
    shield4KMat.transparency = 0.32;
    shield4KMat.cullMode = SCNCullModeBack;
    shield4KMat.writesToDepthBuffer = NO;
    shield4KCyl.firstMaterial = shield4KMat;
    
    SCNNode *shieldNode = [SCNNode nodeWithGeometry:shield4KCyl];
    shieldNode.position = SCNVector3Make(0, -1.35, 0);
    [_shield4KNode addChildNode:shieldNode];
    [_cryostatRoot addChildNode:_shield4KNode];
}


- (void)buildSupportTrusses {
    // 4 G10 composite tubular posts (matching reference image: 4 visible columns)
    for (int i = 0; i < 4; i++) {
        CGFloat angle = (CGFloat)i * (M_PI_2) + M_PI_4 * 0.5; // 45-degree offset for visibility
        CGFloat r = 1.22;
        CGFloat x = r * cos(angle);
        CGFloat z = r * sin(angle);
        
        // Upper truss (300K to 4K plate) — larger diameter
        SCNCylinder *truss1 = [SCNCylinder cylinderWithRadius:0.055 height:3.05];
        truss1.firstMaterial = [self g10CompositeMaterial];
        SCNNode *t1Node = [SCNNode nodeWithGeometry:truss1];
        t1Node.position = SCNVector3Make(x, 2.28, z);
        [_cryostatRoot addChildNode:t1Node];
        
        // Lower truss (4K to MC) — slightly inward
        CGFloat rLower = 0.88;
        CGFloat xL = rLower * cos(angle + 0.4);
        CGFloat zL = rLower * sin(angle + 0.4);
        SCNCylinder *truss2 = [SCNCylinder cylinderWithRadius:0.042 height:3.35];
        truss2.firstMaterial = [self g10CompositeMaterial];
        SCNNode *t2Node = [SCNNode nodeWithGeometry:truss2];
        t2Node.position = SCNVector3Make(xL, -1.05, zL);
        [_cryostatRoot addChildNode:t2Node];
    }
    
    // Central support rod (stainless, runs down pumping axis)
    SCNCylinder *centralRod = [SCNCylinder cylinderWithRadius:0.025 height:7.5];
    centralRod.firstMaterial = [self stainlessMaterial];
    SCNNode *centralNode = [SCNNode nodeWithGeometry:centralRod];
    centralNode.position = SCNVector3Make(0, 0.0, 0);
    [_cryostatRoot addChildNode:centralNode];
}


- (void)buildStillStage {
    _stillNode = [SCNNode node];
    _stillNode.name = @"StillStage";
    
    // Still Flange plate at y = -0.3 (wide gold plate, visible in reference)
    SCNCylinder *plateGeom = [SCNCylinder cylinderWithRadius:1.20 height:0.10];
    plateGeom.radialSegmentCount = 128;
    plateGeom.firstMaterial = [self goldMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plateGeom];
    plateNode.position = SCNVector3Make(0, -0.3, 0);
    [_stillNode addChildNode:plateNode];
    
    // Flange ring
    SCNTorus *stillRing = [SCNTorus torusWithRingRadius:1.20 pipeRadius:0.045];
    stillRing.firstMaterial = [self goldMaterial];
    SCNNode *sRingNode = [SCNNode nodeWithGeometry:stillRing];
    sRingNode.position = SCNVector3Make(0, -0.25, 0);
    [_stillNode addChildNode:sRingNode];
    
    // Still Chamber cylinder (gold-plated OFHC copper)
    SCNCylinder *chamberGeom = [SCNCylinder cylinderWithRadius:0.46 height:0.52];
    chamberGeom.radialSegmentCount = 128;
    chamberGeom.firstMaterial = [self goldMaterial];
    SCNNode *chamberNode = [SCNNode nodeWithGeometry:chamberGeom];
    chamberNode.position = SCNVector3Make(0, -0.58, 0);
    [_stillNode addChildNode:chamberNode];
    
    // Liquid helium inside Still (dilute He-3/He-4 at ~0.7K)
    SCNCylinder *liquidGeom = [SCNCylinder cylinderWithRadius:0.44 height:0.22];
    SCNMaterial *lMat = [SCNMaterial material];
    lMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.10 green:0.38 blue:0.60 alpha:0.6];
    lMat.emission.contents = [NSColor colorWithCalibratedRed:0.0 green:0.30 blue:0.52 alpha:1.0];
    lMat.emission.intensity = 0.18;
    lMat.transparency = 0.50;
    liquidGeom.firstMaterial = lMat;
    _stillLiquidNode = [SCNNode nodeWithGeometry:liquidGeom];
    _stillLiquidNode.position = SCNVector3Make(0, -0.67, 0);
    _stillLiquidNode.opacity = 0.0;
    [_stillNode addChildNode:_stillLiquidNode];
    
    // Still Pumping Port Tube (large diameter, runs up to 300K — prominent in reference)
    SCNCylinder *pumpLine = [SCNCylinder cylinderWithRadius:0.18 height:4.2];
    pumpLine.firstMaterial = [self stainlessMaterial];
    SCNNode *pumpNode = [SCNNode nodeWithGeometry:pumpLine];
    pumpNode.position = SCNVector3Make(0, 1.80, 0);
    [_stillNode addChildNode:pumpNode];
    
    // Still Heater coil (wrapped around chamber exterior)
    SCNTorus *heaterCoil = [SCNTorus torusWithRingRadius:0.48 pipeRadius:0.024];
    SCNMaterial *heaterMat = [SCNMaterial material];
    heaterMat.diffuse.contents = [NSColor colorWithCalibratedRed:1.0 green:0.5 blue:0.1 alpha:1.0];
    heaterMat.emission.contents = [NSColor colorWithCalibratedRed:0.9 green:0.3 blue:0.0 alpha:1.0];
    heaterMat.emission.intensity = 0.0;
    heaterCoil.firstMaterial = heaterMat;
    SCNNode *heaterNode = [SCNNode nodeWithGeometry:heaterCoil];
    heaterNode.position = SCNVector3Make(0, -0.58, 0);
    _stillHeaterNode = heaterNode;
    [_stillNode addChildNode:heaterNode];
    
    // RuO2 Thermometer block
    SCNBox *thermBox = [SCNBox boxWithWidth:0.10 height:0.07 length:0.06 chamferRadius:0.005];
    SCNMaterial *thermMat = [SCNMaterial material];
    thermMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.55 green:0.28 blue:1.0 alpha:1.0];
    thermMat.emission.contents = [NSColor colorWithCalibratedRed:0.45 green:0.18 blue:0.90 alpha:1.0];
    thermMat.emission.intensity = 0.35;
    thermBox.firstMaterial = thermMat;
    SCNNode *thermNode = [SCNNode nodeWithGeometry:thermBox];
    thermNode.position = SCNVector3Make(0.50, -0.35, 0.20);
    [_stillNode addChildNode:thermNode];
    
    [_cryostatRoot addChildNode:_stillNode];
}


- (void)buildContinuousExchanger {
    _continuousExchangerNode = [SCNNode node];
    _continuousExchangerNode.name = @"ContinuousExchanger";
    
    // Spiral counterflow tube-in-tube heat exchanger (y: -0.85 to -1.38)
    // Visible in reference image as coil between Still and Cold Plate
    NSUInteger coilTurns = 12;
    for (NSUInteger i = 0; i < coilTurns; i++) {
        CGFloat yPos = -0.85 - ((CGFloat)i * 0.048);
        CGFloat radius = 0.32 + 0.028 * sin((CGFloat)i * 0.8);
        
        // Outer dilute return sheath
        SCNTorus *coilOuter = [SCNTorus torusWithRingRadius:radius pipeRadius:0.030];
        coilOuter.firstMaterial = [self copperMaterial];
        SCNNode *turnNode = [SCNNode nodeWithGeometry:coilOuter];
        turnNode.position = SCNVector3Make(0, yPos, 0);
        turnNode.eulerAngles = SCNVector3Make(0.05 * sin(i), (CGFloat)i * 0.3, 0.05 * cos(i));
        [_continuousExchangerNode addChildNode:turnNode];
        
        // Inner concentrated supply capillary
        if (i % 3 == 0) {
            SCNTorus *coilInner = [SCNTorus torusWithRingRadius:radius * 0.72 pipeRadius:0.016];
            coilInner.firstMaterial = [self stainlessMaterial];
            SCNNode *innerNode = [SCNNode nodeWithGeometry:coilInner];
            innerNode.position = SCNVector3Make(0, yPos - 0.01, 0);
            [_continuousExchangerNode addChildNode:innerNode];
        }
    }
    
    [_cryostatRoot addChildNode:_continuousExchangerNode];
}


- (void)buildColdPlate {
    _coldPlateNode = [SCNNode node];
    _coldPlateNode.name = @"ColdPlate";
    
    // Cold plate wide circular disk at y = -1.48 (100 mK, stainless with copper trim)
    SCNCylinder *plateGeom = [SCNCylinder cylinderWithRadius:1.10 height:0.09];
    plateGeom.radialSegmentCount = 128;
    plateGeom.firstMaterial = [self stainlessMaterial];
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plateGeom];
    plateNode.position = SCNVector3Make(0, -1.48, 0);
    [_coldPlateNode addChildNode:plateNode];
    
    // Flange ring
    SCNTorus *cpRing = [SCNTorus torusWithRingRadius:1.10 pipeRadius:0.040];
    cpRing.firstMaterial = [self copperMaterial];
    SCNNode *cpRingNode = [SCNNode nodeWithGeometry:cpRing];
    cpRingNode.position = SCNVector3Make(0, -1.44, 0);
    [_coldPlateNode addChildNode:cpRingNode];
    
    // Secondary Flow Impedance (Z2) coil on Cold Plate
    SCNTorus *z2Coil = [SCNTorus torusWithRingRadius:0.24 pipeRadius:0.018];
    z2Coil.firstMaterial = [self copperMaterial];
    SCNNode *z2Node = [SCNNode nodeWithGeometry:z2Coil];
    z2Node.position = SCNVector3Make(0.28, -1.44, 0.28);
    [_coldPlateNode addChildNode:z2Node];
    
    // Magnetic shielding can at cold plate level
    SCNCylinder *magShield = [SCNCylinder cylinderWithRadius:0.32 height:0.22];
    SCNMaterial *shieldMat = [SCNMaterial material];
    shieldMat.lightingModelName = SCNLightingModelPhysicallyBased;
    shieldMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.65 green:0.70 blue:0.78 alpha:0.55];
    shieldMat.metalness.contents = @0.90;
    shieldMat.transparency = 0.42;
    magShield.firstMaterial = shieldMat;
    SCNNode *magNode = [SCNNode nodeWithGeometry:magShield];
    magNode.position = SCNVector3Make(-0.30, -1.48, -0.30);
    [_coldPlateNode addChildNode:magNode];
    
    [_cryostatRoot addChildNode:_coldPlateNode];
}


- (void)buildStepExchangers {
    _stepExchangersNode = [SCNNode node];
    _stepExchangersNode.name = @"StepExchangers";
    
    // Sintered silver powder heat exchanger blocks (4 blocks in series around perimeter)
    for (int i = 0; i < 4; i++) {
        CGFloat angle = (CGFloat)i * (M_PI_2) + 0.35;
        CGFloat r = 0.56;
        CGFloat x = r * cos(angle);
        CGFloat z = r * sin(angle);
        
        SCNBox *boxGeom = [SCNBox boxWithWidth:0.24 height:0.32 length:0.20 chamferRadius:0.025];
        boxGeom.firstMaterial = [self sinteredSilverMaterial];
        
        SCNNode *blockNode = [SCNNode nodeWithGeometry:boxGeom];
        blockNode.position = SCNVector3Make(x, -1.82, z);
        blockNode.eulerAngles = SCNVector3Make(0, -angle, 0);
        [_stepExchangersNode addChildNode:blockNode];
        
        // Copper interconnect capillary
        SCNCylinder *tubeGeom = [SCNCylinder cylinderWithRadius:0.016 height:0.32];
        tubeGeom.firstMaterial = [self copperMaterial];
        SCNNode *tubeNode = [SCNNode nodeWithGeometry:tubeGeom];
        tubeNode.position = SCNVector3Make(x, -2.06, z);
        [_stepExchangersNode addChildNode:tubeNode];
    }
    
    [_cryostatRoot addChildNode:_stepExchangersNode];
}

- (void)buildMixingChamber {
    _mixingChamberNode = [SCNNode node];
    _mixingChamberNode.name = @"MixingChamber";
    
    // Mixing chamber gold flange disk at y = -2.3
    SCNCylinder *flangeGeom = [SCNCylinder cylinderWithRadius:0.95 height:0.06];
    flangeGeom.radialSegmentCount = 128;
    flangeGeom.firstMaterial = [self goldMaterial];
    SCNNode *flangeNode = [SCNNode nodeWithGeometry:flangeGeom];
    flangeNode.position = SCNVector3Make(0, -2.3, 0);
    [_mixingChamberNode addChildNode:flangeNode];
    
    // Transparent cutaway cylinder housing the He-3 / He-4 phase separation
    SCNCylinder *chamberCyl = [SCNCylinder cylinderWithRadius:0.50 height:0.58];
    chamberCyl.radialSegmentCount = 128;
    SCNMaterial *glassMat = [SCNMaterial material];
    glassMat.lightingModelName = SCNLightingModelPhysicallyBased;
    glassMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.9 green:0.95 blue:1.0 alpha:0.32];
    glassMat.transparency = 0.45;
    glassMat.metalness.contents = @0.1;
    glassMat.roughness.contents = @0.05;
    chamberCyl.firstMaterial = glassMat;
    
    SCNNode *chamberNode = [SCNNode nodeWithGeometry:chamberCyl];
    chamberNode.position = SCNVector3Make(0, -2.62, 0);
    [_mixingChamberNode addChildNode:chamberNode];
    
    // Concentrated Phase (Upper 3He rich fluid - Luminous Cyan)
    SCNCylinder *concGeom = [SCNCylinder cylinderWithRadius:0.47 height:0.26];
    concGeom.radialSegmentCount = 128;
    SCNMaterial *concMat = [SCNMaterial material];
    concMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.0 green:0.68 blue:0.78 alpha:0.60];
    concMat.emission.contents = [NSColor colorWithCalibratedRed:0.0 green:0.40 blue:0.65 alpha:1.0];
    concMat.emission.intensity = 0.18;
    concMat.transparency = 0.70;
    concGeom.firstMaterial = concMat;
    
    _mcConcentratedPhaseNode = [SCNNode nodeWithGeometry:concGeom];
    _mcConcentratedPhaseNode.position = SCNVector3Make(0, -2.48, 0);
    [_mixingChamberNode addChildNode:_mcConcentratedPhaseNode];
    
    // Dilute Phase (Lower 4He rich fluid with 6.6% dissolved 3He - Luminous Quantum Violet)
    SCNCylinder *dilGeom = [SCNCylinder cylinderWithRadius:0.47 height:0.26];
    dilGeom.radialSegmentCount = 128;
    SCNMaterial *dilMat = [SCNMaterial material];
    dilMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.50 green:0.32 blue:0.75 alpha:0.70];
    dilMat.emission.contents = [NSColor colorWithCalibratedRed:0.25 green:0.12 blue:0.60 alpha:1.0];
    dilMat.emission.intensity = 0.18;
    dilMat.transparency = 0.75;
    dilGeom.firstMaterial = dilMat;
    
    _mcDilutePhaseNode = [SCNNode nodeWithGeometry:dilGeom];
    _mcDilutePhaseNode.position = SCNVector3Make(0, -2.75, 0);
    [_mixingChamberNode addChildNode:_mcDilutePhaseNode];
    
    // Phase Boundary Horizontal Disk (Meniscus interface)
    SCNTorus *boundaryRing = [SCNTorus torusWithRingRadius:0.47 pipeRadius:0.016];
    SCNMaterial *boundaryMat = [SCNMaterial material];
    boundaryMat.diffuse.contents = [NSColor whiteColor];
    boundaryMat.emission.contents = [NSColor colorWithCalibratedRed:0.0 green:1.0 blue:0.85 alpha:1.0];
    boundaryMat.emission.intensity = 0.55;
    boundaryRing.firstMaterial = boundaryMat;
    
    _mcPhaseBoundaryNode = [SCNNode nodeWithGeometry:boundaryRing];
    _mcPhaseBoundaryNode.position = SCNVector3Make(0, -2.61, 0);
    [_mixingChamberNode addChildNode:_mcPhaseBoundaryNode];
    
    // MC Diagnostic Heater & RuO2 sensor block
    SCNBox *sensorBox = [SCNBox boxWithWidth:0.14 height:0.09 length:0.14 chamferRadius:0.01];
    sensorBox.firstMaterial = [self copperMaterial];
    SCNNode *sensorNode = [SCNNode nodeWithGeometry:sensorBox];
    sensorNode.position = SCNVector3Make(0.36, -2.3, 0.26);
    [_mixingChamberNode addChildNode:sensorNode];
    
    [_cryostatRoot addChildNode:_mixingChamberNode];
}

- (void)buildSamplePuck {
    _samplePuckNode = [SCNNode node];
    _samplePuckNode.name = @"SamplePuck";
    
    // Gold-plated sample puck mounting socket beneath MC at y = -3.05
    SCNCylinder *puckGeom = [SCNCylinder cylinderWithRadius:0.44 height:0.14];
    puckGeom.radialSegmentCount = 128;
    puckGeom.firstMaterial = [self goldMaterial];
    SCNNode *puckNode = [SCNNode nodeWithGeometry:puckGeom];
    puckNode.position = SCNVector3Make(0, -3.05, 0);
    [_samplePuckNode addChildNode:puckNode];
    
    // Superconducting quantum processor chip package
    SCNBox *chipBox = [SCNBox boxWithWidth:0.28 height:0.04 length:0.28 chamferRadius:0.008];
    SCNMaterial *chipMat = [SCNMaterial material];
    chipMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.08 green:0.10 blue:0.14 alpha:1.0];
    chipMat.metalness.contents = @0.92;
    chipBox.firstMaterial = chipMat;
    SCNNode *chipNode = [SCNNode nodeWithGeometry:chipBox];
    chipNode.position = SCNVector3Make(0, -3.14, 0);
    [_samplePuckNode addChildNode:chipNode];
    
    // Qubit gold die at center
    SCNBox *dieBox = [SCNBox boxWithWidth:0.12 height:0.015 length:0.12 chamferRadius:0.0];
    dieBox.firstMaterial = [self goldMaterial];
    SCNNode *dieNode = [SCNNode nodeWithGeometry:dieBox];
    dieNode.position = SCNVector3Make(0, -3.165, 0);
    [_samplePuckNode addChildNode:dieNode];
    
    // Mu-metal / Superconducting Nb magnetic shield can
    SCNCylinder *shieldGeom = [SCNCylinder cylinderWithRadius:0.56 height:0.42];
    shieldGeom.radialSegmentCount = 128;
    SCNMaterial *muMat = [SCNMaterial material];
    muMat.lightingModelName = SCNLightingModelPhysicallyBased;
    muMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.7 green:0.75 blue:0.8 alpha:0.45];
    muMat.transparency = 0.5;
    shieldGeom.firstMaterial = muMat;
    SCNNode *shieldNode = [SCNNode nodeWithGeometry:shieldGeom];
    shieldNode.position = SCNVector3Make(0, -3.22, 0);
    [_samplePuckNode addChildNode:shieldNode];
    
    [_cryostatRoot addChildNode:_samplePuckNode];
}

- (void)buildPipingNetwork {
    _pipingNode = [SCNNode node];
    _pipingNode.name = @"PipingNetwork";
    
    // 1. High-pressure 3He condensing line running down from 300K to 4K condenser
    SCNCylinder *condLine = [SCNCylinder cylinderWithRadius:0.022 height:3.0];
    condLine.firstMaterial = [self copperMaterial];
    SCNNode *cNode = [SCNNode nodeWithGeometry:condLine];
    cNode.position = SCNVector3Make(-0.35, 2.3, 0.4);
    [_pipingNode addChildNode:cNode];
    
    // 2. Capillary line connecting 4K Condenser -> Still
    SCNCylinder *c4ToStill = [SCNCylinder cylinderWithRadius:0.016 height:1.1];
    c4ToStill.firstMaterial = [self copperMaterial];
    SCNNode *csNode = [SCNNode nodeWithGeometry:c4ToStill];
    csNode.position = SCNVector3Make(-0.35, 0.25, 0.4);
    [_pipingNode addChildNode:csNode];
    
    // 3. Dilute phase return line (Wikipedia: carries dilute fluid from bottom of MC back to Still)
    SCNCylinder *diluteReturn = [SCNCylinder cylinderWithRadius:0.022 height:2.2];
    diluteReturn.firstMaterial = [self stainlessMaterial];
    SCNNode *drNode = [SCNNode nodeWithGeometry:diluteReturn];
    drNode.position = SCNVector3Make(0.38, -1.7, -0.2);
    [_pipingNode addChildNode:drNode];
    
    [_cryostatRoot addChildNode:_pipingNode];
}

- (void)buildRFCoaxLines {
    _rfCoaxNode = [SCNNode node];
    _rfCoaxNode.name = @"RFCoaxLines";
    
    // 4 semi-rigid microwave coaxial lines with SMA attenuators
    CGFloat positions[4][2] = {
        {0.78, 0.78},
        {-0.78, 0.78},
        {-0.78, -0.78},
        {0.78, -0.78}
    };
    
    CGFloat stageY[4] = {0.8, -0.3, -1.45, -2.3};
    
    for (int line = 0; line < 4; line++) {
        CGFloat x = positions[line][0];
        CGFloat z = positions[line][1];
        
        // Coax line cylinder
        SCNCylinder *coaxGeom = [SCNCylinder cylinderWithRadius:0.018 height:6.2];
        coaxGeom.firstMaterial = [self copperMaterial];
        SCNNode *coaxNode = [SCNNode nodeWithGeometry:coaxGeom];
        coaxNode.position = SCNVector3Make(x, 0.7, z);
        [_rfCoaxNode addChildNode:coaxNode];
        
        // SMA Attenuators at each plate
        for (int s = 0; s < 4; s++) {
            SCNCylinder *attGeom = [SCNCylinder cylinderWithRadius:0.048 height:0.13];
            attGeom.firstMaterial = [self goldMaterial];
            SCNNode *attNode = [SCNNode nodeWithGeometry:attGeom];
            attNode.position = SCNVector3Make(x, stageY[s] + 0.08, z);
            [_rfCoaxNode addChildNode:attNode];
        }
    }
    
    [_cryostatRoot addChildNode:_rfCoaxNode];
}

#pragma mark - Particle Systems (He-3 Circulation Flow)

- (void)setupParticleSystems {
    _particlesNode = [SCNNode node];
    
    // Condensing Flow Particles (falling from 4K condenser into Still & MC)
    _condenseFlowPS = [SCNParticleSystem particleSystem];
    _condenseFlowPS.birthRate = 0; // Start off, enabled when circulating
    _condenseFlowPS.particleLifeSpan = 1.6;
    _condenseFlowPS.particleSize = 0.038;
    _condenseFlowPS.particleColor = [NSColor colorWithCalibratedRed:0.0 green:0.95 blue:1.0 alpha:0.85];
    _condenseFlowPS.emissionDuration = 0;
    _condenseFlowPS.loops = YES;
    _condenseFlowPS.emitterShape = [SCNSphere sphereWithRadius:0.15];
    _condenseFlowPS.spreadingAngle = 5;
    _condenseFlowPS.speedFactor = 1.0;
    _condenseFlowPS.particleVelocity = 0.85;
    _condenseFlowPS.acceleration = SCNVector3Make(0, -0.65, 0);
    
    SCNNode *flowNode1 = [SCNNode node];
    flowNode1.position = SCNVector3Make(0, 0.7, 0);
    [flowNode1 addParticleSystem:_condenseFlowPS];
    [_particlesNode addChildNode:flowNode1];
    
    // Still Pumping Extraction Particles (ascending through central still pumping line)
    _pumpingFlowPS = [SCNParticleSystem particleSystem];
    _pumpingFlowPS.birthRate = 0;
    _pumpingFlowPS.particleLifeSpan = 2.2;
    _pumpingFlowPS.particleSize = 0.032;
    _pumpingFlowPS.particleColor = [NSColor colorWithCalibratedRed:0.75 green:0.55 blue:1.0 alpha:0.75];
    _pumpingFlowPS.emitterShape = [SCNSphere sphereWithRadius:0.14];
    _pumpingFlowPS.spreadingAngle = 8;
    _pumpingFlowPS.particleVelocity = 1.25;
    _pumpingFlowPS.acceleration = SCNVector3Make(0, 0.85, 0);
    
    SCNNode *flowNode2 = [SCNNode node];
    flowNode2.position = SCNVector3Make(0, -0.3, 0);
    [flowNode2 addParticleSystem:_pumpingFlowPS];
    [_particlesNode addChildNode:flowNode2];
    
    [_cryostatRoot addChildNode:_particlesNode];
}

#pragma mark - 3D Billboard Labels

- (void)create3DLabels {
    _labelsRootNode = [SCNNode node];
    
    // Only the 5 thermometry stages get live-updating labels.
    // A single fixed column to the right of the OVC keeps them readable.
    NSArray *stages = @[
        @{@"id": @(DRCryoComponent50KFlange),     @"name": @"50K: --",  @"y": @(2.20)},
        @{@"id": @(DRCryoComponent4KFlange),      @"name": @"4K: --",   @"y": @(0.80)},
        @{@"id": @(DRCryoComponentStillStage),    @"name": @"Still: --", @"y": @(-0.30)},
        @{@"id": @(DRCryoComponentColdPlate),     @"name": @"CP: --",   @"y": @(-1.48)},
        @{@"id": @(DRCryoComponentMixingChamber), @"name": @"MC: --",   @"y": @(-2.56)}
    ];
    
    for (NSDictionary *dict in stages) {
        NSNumber *stageID = dict[@"id"];
        NSString *name = dict[@"name"];
        CGFloat y = [dict[@"y"] doubleValue];
        
        SCNNode *labelNode = [self createBillboardNodeWithText:name tag:stageID.integerValue];
        labelNode.position = SCNVector3Make(2.75, y, 0);
        [_labelsRootNode addChildNode:labelNode];
        _labelNodes[stageID] = labelNode;
    }
    
    [_cryostatRoot addChildNode:_labelsRootNode];
}


- (SCNNode *)createBillboardNodeWithText:(NSString *)text tag:(NSInteger)tag {
    SCNNode *billboard = [SCNNode node];
    
    SCNBillboardConstraint *constraint = [SCNBillboardConstraint billboardConstraint];
    constraint.freeAxes = SCNBillboardAxisAll;
    billboard.constraints = @[constraint];
    
    // Dark frosted-glass pill behind the live reading
    SCNPlane *plate = [SCNPlane planeWithWidth:1.45 height:0.34];
    plate.cornerRadius = 0.10;
    SCNMaterial *plateMat = [SCNMaterial material];
    plateMat.lightingModelName = SCNLightingModelConstant;
    plateMat.diffuse.contents  = [NSColor colorWithCalibratedRed:0.02 green:0.05 blue:0.09 alpha:0.94];
    plateMat.emission.contents = [NSColor blackColor];
    plateMat.doubleSided = YES;
    plateMat.writesToDepthBuffer = NO;
    plate.firstMaterial = plateMat;
    SCNNode *plateNode = [SCNNode nodeWithGeometry:plate];
    plateNode.renderingOrder = 10;
    [billboard addChildNode:plateNode];
    
    // Live temperature text — centred on the pill via its bounding box
    SCNText *textGeom = [SCNText textWithString:text extrusionDepth:0.001];
    textGeom.font = [NSFont monospacedSystemFontOfSize:0.13 weight:NSFontWeightSemibold];
    textGeom.alignmentMode = kCAAlignmentLeft;
    textGeom.flatness = 0.1;
    SCNMaterial *textMat = [SCNMaterial material];
    textMat.lightingModelName = SCNLightingModelConstant;
    textMat.diffuse.contents  = [NSColor colorWithCalibratedRed:0.0 green:0.94 blue:1.0 alpha:1.0];
    textMat.emission.contents = [NSColor colorWithCalibratedRed:0.0 green:0.75 blue:0.9 alpha:1.0];
    textMat.emission.intensity = 0.18;
    textMat.writesToDepthBuffer = NO;
    textGeom.firstMaterial = textMat;
    
    SCNNode *textNode = [SCNNode nodeWithGeometry:textGeom];
    textNode.name = @"LabelText";
    textNode.renderingOrder = 11;
    [billboard addChildNode:textNode];
    [self centerLabelTextNode:textNode inWidth:1.40];
    
    // Subtle connector stub toward the cryostat
    SCNBox *lineStub = [SCNBox boxWithWidth:0.28 height:0.008 length:0.008 chamferRadius:0];
    SCNMaterial *lineMat = [SCNMaterial material];
    lineMat.lightingModelName = SCNLightingModelConstant;
    lineMat.diffuse.contents = [NSColor colorWithCalibratedRed:0.0 green:0.85 blue:1.0 alpha:0.45];
    lineStub.firstMaterial = lineMat;
    SCNNode *lineNode = [SCNNode nodeWithGeometry:lineStub];
    lineNode.position = SCNVector3Make(-0.86, 0, 0);
    [billboard addChildNode:lineNode];
    
    billboard.name = [NSString stringWithFormat:@"Label_%ld", (long)tag];
    return billboard;
}

- (void)centerLabelTextNode:(SCNNode *)textNode inWidth:(CGFloat)maxWidth {
    SCNText *textGeom = (SCNText *)textNode.geometry;
    if (![textGeom isKindOfClass:[SCNText class]]) return;

    textGeom.font = [NSFont monospacedSystemFontOfSize:0.13 weight:NSFontWeightSemibold];

    // Keep longer temperature strings inside the pill
    SCNVector3 min, max;
    [textGeom getBoundingBoxMin:&min max:&max];
    CGFloat width = max.x - min.x;
    if (width > maxWidth && width > 0.0) {
        CGFloat scale = maxWidth / width;
        textGeom.font = [NSFont monospacedSystemFontOfSize:0.13 * scale
                                                    weight:NSFontWeightSemibold];
        [textGeom getBoundingBoxMin:&min max:&max];
    }

    textNode.position = SCNVector3Make(-(min.x + max.x) / 2.0,
                                       -(min.y + max.y) / 2.0,
                                       0.021);
}


#pragma mark - Exploded View & Disassembly

- (void)setExplodeProgress:(CGFloat)progress {
    _explodeProgress = progress;
    
    // Smooth kinematic displacement. The translucent shells fade out before
    // they have travelled far enough to become a dark slab across the core.
    _ovcNode.position = SCNVector3Make(0, -progress * 6.0, 0);
    _ovcNode.opacity = MAX(0.0, 1.0 - progress * 1.8);
    
    _shield50KNode.position = SCNVector3Make(0, -progress * 4.5, 0);
    _shield50KNode.opacity = MAX(0.0, 1.0 - progress * 2.2);
    
    _shield4KNode.position = SCNVector3Make(0, -progress * 3.2, 0);
    _shield4KNode.opacity = MAX(0.0, 1.0 - progress * 2.0);

    [self updateExposureForShieldState];
}

// The camera uses a fixed HDR exposure so orbiting cannot trigger SceneKit's
// automatic eye adaptation (which made the model grow brighter on every spin).
// The manual exposure is calibrated to the previous, fully adapted overview
// brightness, then reduced smoothly for close-ups where reflective metal fills
// the frame and would otherwise clip.
- (void)updateExposureForShieldState {
    SCNVector3 offset = _cameraNode.position;
    CGFloat distance = sqrt(offset.x * offset.x + offset.y * offset.y + offset.z * offset.z);
    CGFloat closeup = MAX(0.0, MIN(1.0, (12.6 - distance) / 8.4));

    // Treat individually hidden shells like a partially opened model. The
    // normal disassembly slider uses explodeProgress; this also keeps the
    // exposure coherent if a shell is hidden directly.
    CGFloat hiddenFraction = ((!_showOVC ? 1.0 : 0.0) +
                              (!_show50KShield ? 1.0 : 0.0) +
                              (!_show4KShield ? 1.0 : 0.0)) / 3.0;
    CGFloat openness = MAX(0.0, MIN(1.0, MAX(_explodeProgress, hiddenFraction)));

    CGFloat exposure = 2.20 - 0.80 * closeup;

    // With the shells intact, a close-up is dominated by a large polished
    // radiation shield. Trim the exposure so the gold/copper keeps its colour
    // instead of turning into a flat white highlight. This trim fades away as
    // the shields open and stop filling the frame.
    exposure -= 0.60 * closeup * (1.0 - openness);

    // Without the three large shells, the comparatively small bare core sits
    // against the dark background but carries very bright specular highlights.
    // Pull the overview exposure down as the model opens so Reset View and the
    // exploded presets do not leave the exposed core washed out.
    exposure -= 0.75 * (1.0 - closeup) * openness;

    // Reassert this here as well as during setup. If the built-in camera
    // controller or a preset transaction ever touches the camera, no automatic
    // exposure state is allowed to survive and brighten the model over time.
    _cameraNode.camera.wantsExposureAdaptation = NO;
    _cameraNode.camera.exposureOffset = exposure;
}

- (void)setShowOVC:(BOOL)showOVC {
    _showOVC = showOVC;
    _ovcNode.hidden = !showOVC;
    [self updateExposureForShieldState];
}

- (void)setShow50KShield:(BOOL)show50KShield {
    _show50KShield = show50KShield;
    _shield50KNode.hidden = !show50KShield;
    [self updateExposureForShieldState];
}

- (void)setShow4KShield:(BOOL)show4KShield {
    _show4KShield = show4KShield;
    _shield4KNode.hidden = !show4KShield;
    [self updateExposureForShieldState];
}

- (void)setShow3DLabels:(BOOL)show3DLabels {
    _show3DLabels = show3DLabels;
    _labelsRootNode.hidden = !show3DLabels;
}

- (void)setShowFlowParticles:(BOOL)showFlowParticles {
    _showFlowParticles = showFlowParticles;
    _particlesNode.hidden = !showFlowParticles;
}

#pragma mark - Selection & Highlighting

- (void)handleHitTestAtPoint:(CGPoint)point inView:(SCNView *)view {
    NSDictionary *hitOptions = @{
        SCNHitTestOptionSearchMode: @(SCNHitTestSearchModeClosest),
        SCNHitTestOptionIgnoreHiddenNodes: @YES
    };
    
    NSArray<SCNHitTestResult *> *results = [view hitTest:point options:hitOptions];
    if (results.count == 0) return;
    
    SCNHitTestResult *hit = results.firstObject;
    SCNNode *node = hit.node;
    
    DRCryoComponentID compID = DRCryoComponentNone;
    while (node && node != self.rootNode && node != _cryostatRoot) {
        if ([node.name isEqualToString:@"TopFlange300K"]) { compID = DRCryoComponentTopFlange300K; break; }
        if ([node.name isEqualToString:@"PulseTube"])     { compID = DRCryoComponentPulseTube; break; }
        if ([node.name isEqualToString:@"OVC"])           { compID = DRCryoComponentOVC; break; }
        if ([node.name isEqualToString:@"50KShield"])     { compID = DRCryoComponent50KShield; break; }
        if ([node.name isEqualToString:@"50KFlange"])     { compID = DRCryoComponent50KFlange; break; }
        if ([node.name isEqualToString:@"4KShield"])      { compID = DRCryoComponent4KShield; break; }
        if ([node.name isEqualToString:@"4KFlange"])      { compID = DRCryoComponent4KFlange; break; }
        if ([node.name isEqualToString:@"StillStage"])    { compID = DRCryoComponentStillStage; break; }
        if ([node.name isEqualToString:@"ContinuousExchanger"]) { compID = DRCryoComponentContinuousExchanger; break; }
        if ([node.name isEqualToString:@"ColdPlate"])     { compID = DRCryoComponentColdPlate; break; }
        if ([node.name isEqualToString:@"StepExchangers"]) { compID = DRCryoComponentStepExchangers; break; }
        if ([node.name isEqualToString:@"MixingChamber"]) { compID = DRCryoComponentMixingChamber; break; }
        if ([node.name isEqualToString:@"SamplePuck"])    { compID = DRCryoComponentSamplePuck; break; }
        if ([node.name isEqualToString:@"RFCoaxLines"])   { compID = DRCryoComponentRFCoaxLines; break; }
        
        if ([node.name hasPrefix:@"Label_"]) {
            compID = (DRCryoComponentID)[[node.name substringFromIndex:6] integerValue];
            break;
        }
        node = node.parentNode;
    }
    
    if (compID != DRCryoComponentNone) {
        [self selectComponent:compID];
    }
}

- (void)selectComponent:(DRCryoComponentID)componentID {
    _selectedComponentID = componentID;

    // Selection is communicated through the HUD status line and the Dossier
    // tab. Do not pulse the node or alter its materials here: scaling a
    // translucent shell (or flashing an emissive highlight) briefly changes
    // the scene exposure and makes the whole cryostat look brighter.
    NSString *name = @"";
    switch (componentID) {
        case DRCryoComponentTopFlange300K: name = @"300 K Top Flange"; break;
        case DRCryoComponentPulseTube: name = @"Pulse Tube Cryocooler"; break;
        case DRCryoComponentOVC: name = @"Outer Vacuum Chamber (OVC)"; break;
        case DRCryoComponent50KShield: name = @"50 K Radiation Shield"; break;
        case DRCryoComponent50KFlange: name = @"50 K Flange"; break;
        case DRCryoComponent4KShield: name = @"4 K Radiation Shield"; break;
        case DRCryoComponent4KFlange: name = @"4 K Condenser & Traps"; break;
        case DRCryoComponentStillStage: name = @"Still Stage (~0.8 K)"; break;
        case DRCryoComponentContinuousExchanger: name = @"Continuous Counterflow Coil"; break;
        case DRCryoComponentColdPlate: name = @"100 mK Cold Plate"; break;
        case DRCryoComponentStepExchangers: name = @"Step Heat Exchangers"; break;
        case DRCryoComponentMixingChamber: name = @"Mixing Chamber (~10 mK)"; break;
        case DRCryoComponentSamplePuck: name = @"Quantum Sample Stage"; break;
        case DRCryoComponentRFCoaxLines: name = @"RF Coax & SMA Attenuators"; break;
        default: break;
    }

    if ([self.cryoDelegate respondsToSelector:@selector(cryostatSceneDidSelectComponent:name:)]) {
        [self.cryoDelegate cryostatSceneDidSelectComponent:componentID name:name];
    }
}

- (void)focusCameraOnStage:(DRCryoComponentID)stageID {
    CGFloat targetY = 0.0;
    CGFloat distance = 7.5;
    switch (stageID) {
        case DRCryoComponentTopFlange300K: targetY = 3.6; distance = 6.0; break;
        case DRCryoComponentPulseTube: targetY = 2.5; distance = 7.0; break;
        case DRCryoComponent50KFlange:
        case DRCryoComponent50KShield: targetY = 2.0; distance = 6.5; break;
        case DRCryoComponent4KFlange:
        case DRCryoComponent4KShield: targetY = 0.8; distance = 5.8; break;
        case DRCryoComponentStillStage: targetY = -0.3; distance = 5.2; break;
        case DRCryoComponentContinuousExchanger: targetY = -0.9; distance = 4.8; break;
        case DRCryoComponentColdPlate: targetY = -1.45; distance = 4.5; break;
        case DRCryoComponentStepExchangers: targetY = -1.85; distance = 4.4; break;
        case DRCryoComponentMixingChamber: targetY = -2.5; distance = 4.2; break;
        case DRCryoComponentSamplePuck: targetY = -3.1; distance = 3.9; break;
        case DRCryoComponentRFCoaxLines: targetY = -2.3; distance = 5.0; break;
        default: targetY = 0.0; distance = 11.2; break;
    }
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.8];
    [SCNTransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    _cameraPivotNode.position = SCNVector3Make(0, targetY, 0);
    _cameraPivotNode.eulerAngles = SCNVector3Zero;
    _cameraNode.position = SCNVector3Make(0, 0.4, distance);
    // The built-in SCNView camera controller rotates the camera node during
    // orbit gestures. Every preset must restore this pitch, otherwise the
    // camera can remain aimed off in space after a preset is selected.
    _cameraNode.eulerAngles = SCNVector3Make(-0.07, 0, 0);
    [SCNTransaction commit];
    [self updateExposureForShieldState];
}

- (void)resetCamera {
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.6];
    _cameraPivotNode.position = SCNVector3Make(0, 0.0, 0);
    _cameraPivotNode.eulerAngles = SCNVector3Zero;
    _cameraNode.position = SCNVector3Make(0, 0.9, 12.6);
    _cameraNode.eulerAngles = SCNVector3Make(-0.07, 0, 0);
    [SCNTransaction commit];
    [self updateExposureForShieldState];
}

#pragma mark - State Update

// Returns a temperature-mapped color: 300K=red/orange, 4K=gold, 1K=cyan, 10mK=quantum violet
- (NSColor *)thermalColorForKelvin:(double)kelvin {
    if (kelvin > 100.0) {
        // Hot: red-orange tones
        double t = MIN(1.0, (kelvin - 100.0) / 200.0);
        return [NSColor colorWithCalibratedRed:1.0 green:0.25 + t*0.25 blue:0.0 alpha:1.0];
    } else if (kelvin > 10.0) {
        // Warm: orange to gold
        double t = (kelvin - 10.0) / 90.0;
        return [NSColor colorWithCalibratedRed:1.0 green:0.55 + t*0.3 blue:0.0 + t*0.1 alpha:1.0];
    } else if (kelvin > 1.0) {
        // Cooling: gold to cyan
        double t = (kelvin - 1.0) / 9.0;
        return [NSColor colorWithCalibratedRed:t*1.0 green:0.85 blue:t*0.4 + (1.0-t)*1.0 alpha:1.0];
    } else if (kelvin > 0.1) {
        // Cold: cyan to blue
        double t = (kelvin - 0.1) / 0.9;
        return [NSColor colorWithCalibratedRed:0.0 green:0.5 + t*0.4 blue:1.0 alpha:1.0];
    } else {
        // Ultra-cold: quantum violet / deep blue
        double t = MIN(1.0, kelvin / 0.1);
        return [NSColor colorWithCalibratedRed:0.5*(1.0-t) green:0.2*t blue:1.0 alpha:1.0];
    }
}

- (void)applyThermalEmissionToNode:(SCNNode *)node kelvin:(double)kelvin baseOpacity:(CGFloat)alpha {
    NSColor *color = [self thermalColorForKelvin:kelvin];
    // Keep the thermal tint subtle: the live labels and panel already carry the
    // precise readings, while the 3D surfaces must retain their material
    // colours so stages stay distinguishable when the shields are removed.
    CGFloat intensity = (kelvin > 50.0) ? 0.05 : (kelvin > 1.0) ? 0.025 : 0.04;

    void (^tintMaterial)(SCNMaterial *) = ^(SCNMaterial *mat) {
        if (!mat) return;
        id metalness = mat.metalness.contents;
        if (![metalness isKindOfClass:[NSNumber class]] || [metalness doubleValue] < 0.2) {
            return;
        }
        mat.emission.contents = color;
        mat.emission.intensity = intensity;
    };

    [node enumerateChildNodesUsingBlock:^(SCNNode *child, BOOL *stop) {
        if (child.geometry) {
            for (SCNMaterial *mat in child.geometry.materials) {
                tintMaterial(mat);
            }
        }
    }];
    if (node.geometry) {
        for (SCNMaterial *mat in node.geometry.materials) {
            tintMaterial(mat);
        }
    }
    (void)alpha;
}

- (void)updateWithPhysicsState {
    if (!_physicsEngine) return;
    
    double t = _physicsEngine.elapsedTime;
    double flowRate = _physicsEngine.flowRate_umol_s;
    
    // --- Dynamic particle birth rates tied to 3He flow ---
    if (_showFlowParticles) {
        double circulationBirthRate = MIN(180.0, flowRate * 0.5);
        _condenseFlowPS.birthRate = circulationBirthRate;
        _pumpingFlowPS.birthRate = circulationBirthRate * 1.2;
    } else {
        _condenseFlowPS.birthRate = 0;
        _pumpingFlowPS.birthRate = 0;
    }
    
    // --- Thermal emission color-coding on stage flanges ---
    [self applyThermalEmissionToNode:_flange50KNode kelvin:_physicsEngine.temp50K baseOpacity:0.7];
    [self applyThermalEmissionToNode:_flange4KNode kelvin:_physicsEngine.temp4K baseOpacity:0.7];
    [self applyThermalEmissionToNode:_stillNode kelvin:_physicsEngine.tempStill baseOpacity:0.8];
    [self applyThermalEmissionToNode:_coldPlateNode kelvin:_physicsEngine.tempColdPlate baseOpacity:0.7];
    [self applyThermalEmissionToNode:_mixingChamberNode kelvin:_physicsEngine.tempMixingChamber baseOpacity:0.9];
    
    // --- Pulse Tube compressor visual activity ---
    if (_physicsEngine.ptCompressorOn) {
        CGFloat ptPulse = 0.15 + 0.08 * fabs(sin(t * 1.8));
        if (_pulseTubeNode.geometry && _pulseTubeNode.geometry.firstMaterial) {
            _pulseTubeNode.geometry.firstMaterial.emission.contents = [NSColor colorWithCalibratedRed:0.0 green:0.6 blue:1.0 alpha:1.0];
            _pulseTubeNode.geometry.firstMaterial.emission.intensity = ptPulse;
        }
    }
    
    // --- Still heater glow (only the heater coil, never the gold flange) ---
    CGFloat heaterGlow = (CGFloat)(_physicsEngine.stillHeaterPower_uW / 30000.0);
    SCNMaterial *stillHeaterMat = _stillHeaterNode.geometry.firstMaterial;
    stillHeaterMat.emission.contents = [NSColor colorWithCalibratedRed:0.9 green:0.3 blue:0.0 alpha:1.0];
    stillHeaterMat.emission.intensity = MIN(0.9, heaterGlow * 1.2);
    
    // --- Phase separation in Mixing Chamber ---
    if (_physicsEngine.phaseSeparated) {
        _mcConcentratedPhaseNode.hidden = NO;
        _mcDilutePhaseNode.hidden = NO;
        _mcPhaseBoundaryNode.hidden = NO;
        
        // Dynamic phase boundary shimmer
        CGFloat shimmer = 0.5 + 0.22 * sin(t * 3.5);
        _mcPhaseBoundaryNode.opacity = shimmer;
        
        // Dynamic phase boundary position based on fraction
        CGFloat phaseFrac = (CGFloat)_physicsEngine.phaseBoundaryFraction;
        CGFloat boundaryY = -2.48 + (phaseFrac - 0.5) * 0.3;
        _mcPhaseBoundaryNode.position = SCNVector3Make(0, -2.61 + (phaseFrac - 0.55) * 0.2, 0);
        (void)boundaryY;
        
        // Ultra-cold quantum violet glow on MC below 30 mK
        if (_physicsEngine.tempMixingChamber < 0.030) {
            CGFloat pulse = 0.35 + 0.20 * sin(t * 4.2);
            _mcDilutePhaseNode.opacity = pulse;
            _mcConcentratedPhaseNode.opacity = pulse * 0.85;
            
            // Sample puck quantum glow
            CGFloat quantumGlow = 0.10 + 0.06 * sin(t * 5.0);
            SCNNode *puckChild = _samplePuckNode.childNodes.firstObject;
            SCNMaterial *puckMat = puckChild.geometry.firstMaterial;
            if (puckMat) {
                puckMat.emission.contents = [NSColor colorWithCalibratedRed:0.55 green:0.28 blue:1.0 alpha:1.0];
                puckMat.emission.intensity = quantumGlow;
            }
        } else {
            _mcDilutePhaseNode.opacity = 0.8;
            _mcConcentratedPhaseNode.opacity = 0.75;
            SCNNode *puckChild = _samplePuckNode.childNodes.firstObject;
            puckChild.geometry.firstMaterial.emission.intensity = 0.0;
        }
    } else {
        _mcConcentratedPhaseNode.hidden = YES;
        _mcPhaseBoundaryNode.hidden = YES;
        // Still liquid visible when condensed
        _mcDilutePhaseNode.hidden = (_physicsEngine.condensedLiquidVolume < 0.3);
        _mcDilutePhaseNode.opacity = (CGFloat)MIN(0.7, _physicsEngine.condensedLiquidVolume * 0.9);
    }
    
    // --- Still liquid level animation ---
    double liquidFrac = MIN(1.0, _physicsEngine.condensedLiquidVolume);
    _stillLiquidNode.opacity = (CGFloat)(liquidFrac * 0.7);
    
    // --- Update labels with live temperature readings ---
    [self updateLabelForStage:DRCryoComponent50KFlange text:[NSString stringWithFormat:@"50K: %@", [DRTheme formattedTemperature:_physicsEngine.temp50K]]];
    [self updateLabelForStage:DRCryoComponent4KFlange text:[NSString stringWithFormat:@"4K: %@", [DRTheme formattedTemperature:_physicsEngine.temp4K]]];
    [self updateLabelForStage:DRCryoComponentStillStage text:[NSString stringWithFormat:@"Still: %@", [DRTheme formattedTemperature:_physicsEngine.tempStill]]];
    [self updateLabelForStage:DRCryoComponentColdPlate text:[NSString stringWithFormat:@"CP: %@", [DRTheme formattedTemperature:_physicsEngine.tempColdPlate]]];
    [self updateLabelForStage:DRCryoComponentMixingChamber text:[NSString stringWithFormat:@"MC: %@", [DRTheme formattedTemperature:_physicsEngine.tempMixingChamber]]];

    // Keep the manually calibrated exposure authoritative for every rendered
    // state. This prevents repeated Exploded / Reset View clicks or camera
    // controller updates from accumulating any HDR exposure lift.
    [self updateExposureForShieldState];
}

- (void)updateLabelForStage:(DRCryoComponentID)stageID text:(NSString *)text {
    SCNNode *node = _labelNodes[@(stageID)];
    if (!node) return;
    
    for (SCNNode *sub in node.childNodes) {
        if ([sub.geometry isKindOfClass:[SCNText class]]) {
            SCNText *scText = (SCNText *)sub.geometry;
            scText.string = text;
            [self centerLabelTextNode:sub inWidth:1.40];
            break;
        }
    }
}

@end













































