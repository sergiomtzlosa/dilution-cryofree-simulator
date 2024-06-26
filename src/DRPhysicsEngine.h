#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DRCryoPhase) {
    DRCryoPhaseRoomTemp = 0,
    DRCryoPhaseEvacuatingOVC,
    DRCryoPhasePreCoolingPT,
    DRCryoPhaseCondensingMixture,
    DRCryoPhaseCirculatingDilution,
    DRCryoPhaseBaseTemperature,
    DRCryoPhaseRecoveringMixture
};

// Notification posted when physics state updates
extern NSNotificationName const DRPhysicsEngineDidUpdateNotification;

@interface DRPhysicsEngine : NSObject

// Singleton
+ (instancetype)sharedEngine;

// Current Phase
@property (nonatomic, readonly) DRCryoPhase currentPhase;
@property (nonatomic, readonly) NSString *currentPhaseName;
@property (nonatomic, readonly) NSString *currentPhaseStatusDescription;

// Temperatures (in Kelvin)
@property (nonatomic, assign) double temp50K;
@property (nonatomic, assign) double temp4K;
@property (nonatomic, assign) double tempStill;
@property (nonatomic, assign) double tempColdPlate;
@property (nonatomic, assign) double tempMixingChamber;

// Pressures
@property (nonatomic, assign) double pressOVC;         // mbar (1013 down to 1e-7)
@property (nonatomic, assign) double pressDump;        // mbar (1200 down to 350)
@property (nonatomic, assign) double pressCondense;    // bar (0 to 2.5)
@property (nonatomic, assign) double pressStill;       // mbar (0.01 to 2.0)

// 3He Flow Rate (µmol/s)
@property (nonatomic, assign) double flowRate_umol_s;

// Dilution State
@property (nonatomic, readonly) BOOL phaseSeparated;
@property (nonatomic, readonly) double phaseBoundaryFraction; // 0.0 - 1.0 position in MC
@property (nonatomic, readonly) double condensedLiquidVolume; // 0.0 = empty, 1.0 = fully charged

// Hardware Controls - Pumps & Compressors
@property (nonatomic, assign) BOOL ptCompressorOn;
@property (nonatomic, assign) BOOL turboPumpOn;
@property (nonatomic, assign) BOOL scrollPumpOn;

// Valves
@property (nonatomic, assign) BOOL valveOVC;           // OVC Turbo gate valve
@property (nonatomic, assign) BOOL valveDumpSupply;    // V1: Dump Tank -> Condense Line
@property (nonatomic, assign) BOOL valveDumpReturn;    // V2: GHS -> Dump Tank (Mixture recovery)
@property (nonatomic, assign) BOOL valveStillPumping;  // V3: Still -> Turbo/Scroll suction
@property (nonatomic, assign) BOOL valveCirculation;   // V4: Scroll discharge -> Condense Line
@property (nonatomic, assign) BOOL valveCondense;      // V5: Condense injection valve
@property (nonatomic, assign) BOOL valveBypass;        // V6: Still-Condense bypass

// Heaters
@property (nonatomic, assign) double stillHeaterPower_uW;  // 0 to 50,000 µW
@property (nonatomic, assign) double mcHeaterPower_uW;     // 0 to 1,000 µW

// Closed-loop PID for MC Temperature
@property (nonatomic, assign) BOOL pidEnabled;
@property (nonatomic, assign) double pidSetpoint_mK;       // Target mK (e.g. 20.0)
@property (nonatomic, assign) double pidKp;
@property (nonatomic, assign) double pidKi;
@property (nonatomic, assign) double pidKd;

// Simulation State
@property (nonatomic, assign) double timeMultiplier;      // 1.0 to 200.0
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, readonly) NSTimeInterval elapsedTime;

// Step-by-Step Interactive Workflow
@property (nonatomic, readonly) NSInteger currentWorkflowStep;
@property (nonatomic, readonly) NSInteger totalWorkflowSteps;
- (NSString *)workflowStepTitle:(NSInteger)stepIndex;
- (NSString *)workflowStepDescription:(NSInteger)stepIndex;
- (NSString *)workflowStepActionGuide:(NSInteger)stepIndex;
- (BOOL)isWorkflowStepCompleted:(NSInteger)stepIndex;
- (void)advanceWorkflowStep;
- (void)retreatWorkflowStep;
- (void)jumpToWorkflowStep:(NSInteger)stepIndex;
- (void)autoConfigureForStep:(NSInteger)stepIndex;

// Quick Action Presets
- (void)resetToRoomTemperature;
- (void)fastForwardToPhase:(DRCryoPhase)phase;
- (void)startAutoCooldownSequence;
- (void)startControlledWarmupSequence;

// Main simulation step called by display timer
- (void)tickWithDeltaTime:(NSTimeInterval)dt;

@end

NS_ASSUME_NONNULL_END





















































