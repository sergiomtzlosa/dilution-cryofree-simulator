#import "DRPhysicsEngine.h"
#import "DRTheme.h"


NSNotificationName const DRPhysicsEngineDidUpdateNotification = @"DRPhysicsEngineDidUpdateNotification";

@interface DRPhysicsEngine ()

@property (nonatomic, assign) DRCryoPhase currentPhase;
@property (nonatomic, assign) NSTimeInterval elapsedTime;
@property (nonatomic, assign) NSInteger currentWorkflowStep;
@property (nonatomic, assign) double pidIntegral;
@property (nonatomic, assign) double pidLastError;
@property (nonatomic, assign) double condensedLiquidVolume; // 0 to 1.0 (fraction of charge condensed)

@end

@implementation DRPhysicsEngine

+ (instancetype)sharedEngine {
    static DRPhysicsEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DRPhysicsEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _timeMultiplier = 5.0; // Responsive default
        _isPaused = NO;
        _pidKp = 45.0;
        _pidKi = 2.5;
        _pidKd = 8.0;
        _pidSetpoint_mK = 20.0;
        _pidEnabled = NO;
        _currentWorkflowStep = 0;
        [self resetToRoomTemperature];
    }
    return self;
}

- (void)resetToRoomTemperature {
    _currentPhase = DRCryoPhaseRoomTemp;
    _elapsedTime = 0.0;
    _condensedLiquidVolume = 0.0;
    
    // Temperatures at room ambient
    _temp50K = 295.0;
    _temp4K = 295.0;
    _tempStill = 295.0;
    _tempColdPlate = 295.0;
    _tempMixingChamber = 295.0;
    
    // Pressures
    _pressOVC = 1013.25;    // Atmospheric
    _pressDump = 1250.0;    // Full 3He/4He charge stored in dump tank
    _pressCondense = 0.0;   // Inactive lines
    _pressStill = 0.0;
    
    _flowRate_umol_s = 0.0;
    _stillHeaterPower_uW = 0.0;
    _mcHeaterPower_uW = 0.0;
    
    _ptCompressorOn = NO;
    _turboPumpOn = NO;
    _scrollPumpOn = NO;
    
    _valveOVC = NO;
    _valveDumpSupply = NO;
    _valveDumpReturn = NO;
    _valveStillPumping = NO;
    _valveCirculation = NO;
    _valveCondense = NO;
    _valveBypass = NO;
    
    _pidIntegral = 0.0;
    _pidLastError = 0.0;
    _currentWorkflowStep = 0;
}

- (void)fastForwardToPhase:(DRCryoPhase)phase {
    switch (phase) {
        case DRCryoPhaseRoomTemp:
            [self resetToRoomTemperature];
            break;
            
        case DRCryoPhaseEvacuatingOVC:
            _currentPhase = DRCryoPhaseEvacuatingOVC;
            _currentWorkflowStep = 1;
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 4.5e-5;
            _temp50K = 293.0;
            _temp4K = 293.0;
            _tempStill = 293.0;
            _tempColdPlate = 293.0;
            _tempMixingChamber = 293.0;
            break;
            
        case DRCryoPhasePreCoolingPT:
            _currentPhase = DRCryoPhasePreCoolingPT;
            _currentWorkflowStep = 2;
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 1.2e-6;
            _ptCompressorOn = YES;
            _temp50K = 48.5;
            _temp4K = 3.4;
            _tempStill = 3.6;
            _tempColdPlate = 3.6;
            _tempMixingChamber = 3.6;
            break;
            
        case DRCryoPhaseCondensingMixture:
            _currentPhase = DRCryoPhaseCondensingMixture;
            _currentWorkflowStep = 4;
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 8.5e-7;
            _ptCompressorOn = YES;
            _temp50K = 45.0;
            _temp4K = 3.1;
            _valveDumpSupply = YES;
            _valveCondense = YES;
            _valveBypass = YES;
            _pressDump = 680.0;
            _pressCondense = 1.6;
            _pressStill = 0.8;
            _tempStill = 1.8;
            _tempColdPlate = 1.5;
            _tempMixingChamber = 1.2;
            _condensedLiquidVolume = 0.85;
            break;
            
        case DRCryoPhaseCirculatingDilution:
            _currentPhase = DRCryoPhaseCirculatingDilution;
            _currentWorkflowStep = 6;
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 5.0e-7;
            _ptCompressorOn = YES;
            _scrollPumpOn = YES;
            _valveDumpSupply = NO;
            _valveBypass = NO;
            _valveStillPumping = YES;
            _valveCirculation = YES;
            _valveCondense = YES;
            _condensedLiquidVolume = 1.0;
            _pressDump = 360.0;
            _pressCondense = 1.05;
            _pressStill = 0.055;
            _stillHeaterPower_uW = 9500.0; // 9.5 mW
            _flowRate_umol_s = 285.0;
            _temp50K = 44.2;
            _temp4K = 3.05;
            _tempStill = 0.82;
            _tempColdPlate = 0.145;
            _tempMixingChamber = 0.048; // 48 mK descending
            break;
            
        case DRCryoPhaseBaseTemperature:
            _currentPhase = DRCryoPhaseBaseTemperature;
            _currentWorkflowStep = 7;
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 2.1e-7;
            _ptCompressorOn = YES;
            _scrollPumpOn = YES;
            _valveDumpSupply = NO;
            _valveBypass = NO;
            _valveStillPumping = YES;
            _valveCirculation = YES;
            _valveCondense = YES;
            _condensedLiquidVolume = 1.0;
            _pressDump = 340.0;
            _pressCondense = 0.98;
            _pressStill = 0.042;
            _stillHeaterPower_uW = 10500.0; // 10.5 mW
            _flowRate_umol_s = 310.0;
            _temp50K = 43.8;
            _temp4K = 2.95;
            _tempStill = 0.78;
            _tempColdPlate = 0.115;
            _tempMixingChamber = 0.0108; // 10.8 mK stable base!
            break;
            
        case DRCryoPhaseRecoveringMixture:
            _currentPhase = DRCryoPhaseRecoveringMixture;
            _currentWorkflowStep = 8;
            _valveDumpSupply = NO;
            _valveCondense = NO;
            _valveStillPumping = YES;
            _valveDumpReturn = YES;
            _ptCompressorOn = NO;
            _scrollPumpOn = YES;
            _stillHeaterPower_uW = 25000.0;
            _mcHeaterPower_uW = 500.0;
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DRPhysicsEngineDidUpdateNotification object:self];
}

- (void)startAutoCooldownSequence {
    // Automatically perform actions from current state toward base temperature
    _valveOVC = YES;
    _turboPumpOn = YES;
    _ptCompressorOn = YES;
    if (_currentPhase == DRCryoPhaseRoomTemp) {
        _currentPhase = DRCryoPhaseEvacuatingOVC;
        _currentWorkflowStep = 1;
    }
}

- (void)startControlledWarmupSequence {
    [self fastForwardToPhase:DRCryoPhaseRecoveringMixture];
}

#pragma mark - Step-by-Step Workflow Guides

- (NSInteger)totalWorkflowSteps {
    return 9;
}

- (NSString *)workflowStepTitle:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0: return @"1. Pre-Run Room Temp Checks";
        case 1: return @"2. OVC High Vacuum Evacuation";
        case 2: return @"3. Pulse Tube Pre-Cooling to 50K & 4K";
        case 3: return @"4. GHS Line Purge & Mixture Prep";
        case 4: return @"5. Helium-3/Helium-4 Condensation";
        case 5: return @"6. Still Distillation & Circulation Startup";
        case 6: return @"7. Phase Separation & Base Cooling";
        case 7: return @"8. Base Temperature (10 mK) & PID Regulation";
        case 8: return @"9. Mixture Recovery & Controlled Warm-Up";
        default: return @"Workflow Step";
    }
}

- (NSString *)workflowStepDescription:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0:
            return @"Check cryostat seals, ensure dump tank holds full He-3/He-4 mixture (~1250 mbar), and verify all valves are closed at 300 K.";
        case 1:
            return @"Open OVC Turbo valve and engage turbomolecular vacuum pump to reach high vacuum (< 10⁻⁴ mbar), eliminating thermal convection.";
        case 2:
            return @"Engage Pulse Tube compressor. Dual-stage Gifford-McMahon / pulse tube cooler extracts heat, cooling 50K flange to ~45 K and 4K flange to ~3.2 K.";
        case 3:
            return @"Verify OVC pressure < 10⁻⁶ mbar and 4K plate < 10 K. Prepare Gas Handling System (GHS) manifolds for mixture condensation.";
        case 4:
            return @"Open V1 (Dump Supply) and V5 (Condense). Helium mixture condenses through 4K stage impedance, filling Still and Mixing Chamber.";
        case 5:
            return @"Engage scroll pump, open V3 (Still Backing) and V4 (Circulation). Apply Still heater (~10 mW) to distill 90% He-3 vapor from dilute liquid.";
        case 6:
            return @"Below 0.87 K, mixture undergoes spontaneous quantum phase separation in the Mixing Chamber into concentrated (upper) and dilute (lower) phases.";
        case 7:
            return @"He-3 crossing phase boundary absorbs enthalpy, pulling Mixing Chamber to base temperature (< 12 mK). Use MC heater PID for setpoints.";
        case 8:
            return @"Stop Pulse Tube, turn off condensation, open V2 (Dump Return), and pump mixture back to dump tanks using heaters for clean recovery.";
        default:
            return @"";
    }
}

- (NSString *)workflowStepActionGuide:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0: return @"Action: Verify the 1250 mbar mixture charge, seals, and closed valves at 300 K.";
        case 1: return @"Action: Click 'Auto-Execute This Step' to open V-OVC and start the turbo pump.";
        case 2: return @"Action: Click 'Auto-Execute This Step' to start the Pulse Tube compressor.";
        case 3: return @"Action: Confirm OVC < 10⁻⁶ mbar and 4K plate < 10 K; prepare the GHS manifold.";
        case 4: return @"Action: Click 'Auto-Execute This Step' to open V1 & V5 and condense the mixture.";
        case 5: return @"Action: Click 'Auto-Execute This Step' to start the scroll pump, V3/V4, and 10 mW Still heater.";
        case 6: return @"Action: Click 'Auto-Execute This Step' or wait for phase separation and base cooling.";
        case 7: return @"Action: Click 'Auto-Execute This Step' to establish base temperature, then set the PID.";
        case 8: return @"Action: Click 'Auto-Execute This Step' to stop the pulse tube and recover the mixture via V2.";
        default: return @"";
    }
}

- (BOOL)isWorkflowStepCompleted:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0:
            return _currentPhase == DRCryoPhaseRoomTemp &&
                   !_valveOVC && !_turboPumpOn && !_ptCompressorOn &&
                   _temp4K > 250.0;
        case 1: return _pressOVC < 1e-4; // OVC evacuated by the turbo pump
        case 2: return _temp4K < 15.0 && _temp50K < 80.0;
        case 3: return _pressOVC < 1e-5 && _temp4K < 10.0 && _temp50K < 60.0;
        case 4: return _valveDumpSupply && _valveCondense && _condensedLiquidVolume > 0.8;
        case 5: return _valveStillPumping && _valveCirculation && _scrollPumpOn && _stillHeaterPower_uW > 2000.0;
        case 6: return _tempMixingChamber < 0.100; // < 100 mK
        case 7: return _tempMixingChamber < 0.020; // < 20 mK
        case 8:
            // At room temperature the dump tank is already full and the pulse
            // tube is off, so those two conditions alone would wrongly mark the
            // recovery step complete before cooldown even begins.
            return _currentPhase == DRCryoPhaseRecoveringMixture &&
                   _pressDump > 1100.0 && !_ptCompressorOn;
        default: return NO;
    }
}

- (void)advanceWorkflowStep {
    if (_currentWorkflowStep < [self totalWorkflowSteps] - 1) {
        _currentWorkflowStep++;
        [self autoConfigureForStep:_currentWorkflowStep];
    }
}

- (void)retreatWorkflowStep {
    if (_currentWorkflowStep > 0) {
        _currentWorkflowStep--;
        [self autoConfigureForStep:_currentWorkflowStep];
    }
}

- (void)jumpToWorkflowStep:(NSInteger)stepIndex {
    NSInteger lastStep = [self totalWorkflowSteps] - 1;
    stepIndex = MAX(0, MIN(lastStep, stepIndex));
    _currentWorkflowStep = stepIndex;
    [self autoConfigureForStep:stepIndex];
    // Some phase presets also update the workflow index; the requested row
    // must remain the visible/selected step after the jump.
    _currentWorkflowStep = stepIndex;
    [[NSNotificationCenter defaultCenter] postNotificationName:DRPhysicsEngineDidUpdateNotification object:self];
}

- (void)autoConfigureForStep:(NSInteger)stepIndex {
    switch (stepIndex) {
        case 0:
            [self resetToRoomTemperature];
            break;
        case 1:
            _valveOVC = YES;
            _turboPumpOn = YES;
            _currentPhase = DRCryoPhaseEvacuatingOVC;
            break;
        case 2:
            _valveOVC = YES;
            _turboPumpOn = YES;
            _pressOVC = 1.0e-5;
            _ptCompressorOn = YES;
            _currentPhase = DRCryoPhasePreCoolingPT;
            break;
        case 3:
            _valveOVC = YES;
            _turboPumpOn = YES;
            _ptCompressorOn = YES;
            _pressOVC = 1.0e-6;
            _currentPhase = DRCryoPhasePreCoolingPT;
            if (_temp4K > 15.0) _temp4K = 4.2;
            if (_temp50K > 60.0) _temp50K = 50.0;
            break;
        case 4:
            [self fastForwardToPhase:DRCryoPhaseCondensingMixture];
            break;
        case 5:
            // Circulation only starts after the mixture has condensed. Jumping
            // directly to this step from room temperature must establish that
            // cold, charged state; otherwise the dilution loop never starts and
            // the guide appears to be stuck at 300 K.
            [self fastForwardToPhase:DRCryoPhaseCirculatingDilution];
            _stillHeaterPower_uW = 10000.0;
            break;
        case 6:
            [self fastForwardToPhase:DRCryoPhaseCirculatingDilution];
            break;
        case 7:
            [self fastForwardToPhase:DRCryoPhaseBaseTemperature];
            break;
        case 8:
            [self fastForwardToPhase:DRCryoPhaseRecoveringMixture];
            break;
    }
    // Fast-forward presets update the internal phase index as a side effect.
    // Keep the workflow cursor on the step the caller actually selected.
    _currentWorkflowStep = stepIndex;
    [[NSNotificationCenter defaultCenter] postNotificationName:DRPhysicsEngineDidUpdateNotification object:self];
}

#pragma mark - Thermodynamic Integration Loop

- (void)tickWithDeltaTime:(NSTimeInterval)dt {
    if (_isPaused) return;
    
    // Scale dt by simulation speed multiplier
    double simDt = dt * _timeMultiplier;
    _elapsedTime += simDt;
    
    // 1. OVC Vacuum Dynamics
    if (_turboPumpOn && _valveOVC) {
        double targetOVC = 1.5e-7;
        _pressOVC += (targetOVC - _pressOVC) * MIN(simDt * 0.05, 0.4);
    } else if (!_valveOVC || !_turboPumpOn) {
        // Slowly lose vacuum if sealed or pump off
        _pressOVC += (_pressOVC * 0.0001 + 1e-8) * simDt;
        if (_pressOVC > 1013.25) _pressOVC = 1013.25;
    }
    
    // 2. Pulse Tube Cooling Dynamics
    if (_ptCompressorOn) {
        // Use fixed thermal approach rates so the two pulse-tube stages settle
        // within a few seconds at the default 5x speed. Scaling the rate by
        // temperature made the last few kelvin take minutes, which looked like
        // the guide's pre-cool step had stalled.
        double target50K = 42.0;
        double target4K = 2.85;
        _temp50K += (target50K - _temp50K) * MIN(simDt * 0.20, 0.35);
        _temp4K += (target4K - _temp4K) * MIN(simDt * 0.30, 0.45);
        
        // Lower stages pre-cool thermally linked to 4K plate. A faster link is
        // intentional here: the guide's room-temperature start should visibly
        // bring the Still, Cold Plate, and Mixing Chamber down together.
        double lowerStageAlpha = MIN(simDt * 0.25, 0.40);
        if (_tempStill > _temp4K + 0.2) {
            _tempStill += (_temp4K - _tempStill) * lowerStageAlpha;
        }
        if (_tempColdPlate > _tempStill + 0.1) {
            _tempColdPlate += (_tempStill - _tempColdPlate) * lowerStageAlpha;
        }
        if (_tempMixingChamber > _tempColdPlate + 0.1) {
            _tempMixingChamber += (_tempColdPlate - _tempMixingChamber) * lowerStageAlpha;
        }
        
        if (_currentPhase == DRCryoPhaseRoomTemp ||
            _currentPhase == DRCryoPhaseEvacuatingOVC) {
            _currentPhase = DRCryoPhasePreCoolingPT;
        }
    } else {
        // PT off: warm up toward 295 K
        _temp50K += (295.0 - _temp50K) * MIN(simDt * 0.0005, 0.05);
        _temp4K += (295.0 - _temp4K) * MIN(simDt * 0.0006, 0.05);
        _tempStill += (295.0 - _tempStill) * MIN(simDt * 0.0006, 0.05);
        _tempColdPlate += (295.0 - _tempColdPlate) * MIN(simDt * 0.0006, 0.05);
        _tempMixingChamber += (295.0 - _tempMixingChamber) * MIN(simDt * 0.0006, 0.05);
    }
    
    // 3. Mixture Condensation Dynamics
    if (_valveDumpSupply && _valveCondense && _temp4K < 20.0) {
        _currentPhase = DRCryoPhaseCondensingMixture;
        // Gas leaves dump tank and condenses into cryostat
        double condensationSpeed = 0.005 * (1.0 / MAX(1.0, _temp4K * 0.3));
        if (_condensedLiquidVolume < 1.0) {
            _condensedLiquidVolume += condensationSpeed * simDt;
            if (_condensedLiquidVolume > 1.0) _condensedLiquidVolume = 1.0;
        }
        
        double targetDumpPress = 1250.0 - (_condensedLiquidVolume * 900.0); // drops to ~350 mbar
        _pressDump += (targetDumpPress - _pressDump) * MIN(simDt * 0.02, 0.2);
        _pressCondense = 1.2 + 0.6 * (1.0 - _condensedLiquidVolume);
        
        // Condensing heats 4K plate slightly
        _temp4K += 0.005 * simDt;
        
        // Liquid filling Still and MC cools them to ~1.2 - 1.5 K
        if (_condensedLiquidVolume > 0.5) {
            double targetLiquidTemp = 1.35;
            _tempStill += (targetLiquidTemp - _tempStill) * MIN(simDt * 0.01, 0.1);
            _tempColdPlate += (targetLiquidTemp - _tempColdPlate) * MIN(simDt * 0.01, 0.1);
            _tempMixingChamber += (targetLiquidTemp - _tempMixingChamber) * MIN(simDt * 0.01, 0.1);
        }
    }
    
    // 4. Still Distillation & Circulation Dynamics
    BOOL isCirculating = _scrollPumpOn && _valveStillPumping && _valveCirculation && _valveCondense && (_condensedLiquidVolume > 0.7);
    
    if (isCirculating) {
        _currentPhase = DRCryoPhaseCirculatingDilution;
        
        // Still heater effect: He3 vapor pressure ~ 0.16 mbar at 0.75K
        // P_still is governed by T_still and pump throughput
        double targetStillTemp = 0.65 + (_stillHeaterPower_uW / 50000.0) * 0.35; // 0.65K to 1.0K
        _tempStill += (targetStillTemp - _tempStill) * MIN(simDt * 0.02, 0.15);
        
        // 3He flow rate in µmol/s proportional to still vapor pressure and heater
        // Typical dilution-unit flow is ~250 - 350 µmol/s at 10 mW
        double targetFlow = 0.0;
        if (_tempStill >= 0.70) {
            targetFlow = 30.0 + (_stillHeaterPower_uW / 1000.0) * 28.0; // ~310 µmol/s at 10 mW
            if (targetFlow > 480.0) targetFlow = 480.0;
        } else {
            targetFlow = MAX(0.0, (_tempStill - 0.5) * 100.0);
        }
        _flowRate_umol_s += (targetFlow - _flowRate_umol_s) * MIN(simDt * 0.04, 0.2);
        
        _pressStill = 0.025 + (_flowRate_umol_s / 400.0) * 0.045; // mbar
        _pressCondense = 0.85 + (_flowRate_umol_s / 400.0) * 0.35; // bar
        
        // 5. Dilution Cooling in Mixing Chamber (Enthalpy of Mixing)
        // Q_dot = n_dot * (84 * T_mc^2 - 12 * T_ex^2) - Q_parasitic + Q_mc_heater
        if (_tempMixingChamber < 0.87) {
            // Phase boundary is established. The incoming concentrated phase
            // has already been pre-cooled by the continuous counterflow heat
            // exchanger; model an 80% approach to the mixing-chamber
            // temperature instead of feeding it in at the 100 mK cold plate.
            // Using the cold plate directly makes the 95*Tm^2 - 11*Ti^2
            // cooling term negative at base, so the MC would warm and leave
            // the base-temperature phase.
            double tEx = _tempMixingChamber + (_tempColdPlate - _tempMixingChamber) * 0.20;
            double nDot_mol_s = _flowRate_umol_s * 1e-6;
            
            // Cooling power in Watts (Wikipedia: Q_dot = n_dot * [95*Tm^2 - 11*Ti^2])
            double qCool = nDot_mol_s * (95.0 * pow(_tempMixingChamber, 2) - 11.0 * pow(tEx, 2));
            double qParasitic = 0.08e-6; // 80 nW parasitic heat leak
            double qHeater = _mcHeaterPower_uW * 1e-6;
            
            double qNet = qCool - qParasitic - qHeater; // Positive = cooling
            
            // Heat capacity of MC at mK is very small (Debye T^3 + nuclear hyperfine)
            double cMC = 0.0005 * pow(_tempMixingChamber / 0.05, 2) + 0.0001; // J/K
            double dTmc_dt = -(qNet / cMC);
            
            // Limit rate of change for numerical stability
            dTmc_dt = MAX(-0.015, MIN(0.015, dTmc_dt));
            _tempMixingChamber += dTmc_dt * simDt;
            
            // Lowest theoretical limit ~ 8.5 mK
            if (_tempMixingChamber < 0.0085) {
                _tempMixingChamber = 0.0085;
            }
            
            // Cold Plate cools via counterflow heat exchanger from MC outgoing dilute line
            double targetCP = 0.090 + _tempMixingChamber * 1.8;
            _tempColdPlate += (targetCP - _tempColdPlate) * MIN(simDt * 0.015, 0.1);
            
            if (_tempMixingChamber < 0.016) {
                _currentPhase = DRCryoPhaseBaseTemperature;
            }
        } else {
            // Pre-dilution: temperature dropping toward 0.87 K
            double targetPreDil = 0.80;
            _tempMixingChamber += (targetPreDil - _tempMixingChamber) * MIN(simDt * 0.01, 0.08);
            _tempColdPlate += (targetPreDil - _tempColdPlate) * MIN(simDt * 0.01, 0.08);
        }
    } else {
        // Not circulating: flow collapses, MC warms up slowly
        _flowRate_umol_s += (0.0 - _flowRate_umol_s) * MIN(simDt * 0.1, 0.3);
        if (_tempMixingChamber < 1.0) {
            _tempMixingChamber += 0.0002 * simDt;
        }
    }

    // 4b. Mixture recovery: the scroll pump returns the helium charge from the
    // cryostat to the room-temperature dump tanks through V2. Without this
    // branch the recovery step can never reach its >1100 mbar completion
    // condition after a base-temperature run.
    if (_currentPhase == DRCryoPhaseRecoveringMixture && _valveDumpReturn && _scrollPumpOn) {
        _pressDump += (1250.0 - _pressDump) * MIN(simDt * 0.02, 0.15);
        _condensedLiquidVolume = MAX(0.0, _condensedLiquidVolume - 0.015 * simDt);
        _pressCondense = MAX(0.0, _pressCondense - 0.010 * simDt);
    }
    
    // 6. Closed-Loop PID Temperature Control on Mixing Chamber
    if (_pidEnabled && _currentPhase >= DRCryoPhaseCirculatingDilution) {
        double currentTemp_mK = _tempMixingChamber * 1000.0;
        double error = _pidSetpoint_mK - currentTemp_mK;
        
        _pidIntegral += error * simDt;
        // Anti-windup
        if (_pidIntegral > 100.0) _pidIntegral = 100.0;
        if (_pidIntegral < -100.0) _pidIntegral = -100.0;
        
        double derivative = (error - _pidLastError) / MAX(0.001, simDt);
        _pidLastError = error;
        
        double pidOutput = (_pidKp * error) + (_pidKi * _pidIntegral) + (_pidKd * derivative);
        if (pidOutput < 0.0) pidOutput = 0.0;
        if (pidOutput > 1000.0) pidOutput = 1000.0; // Max 1000 µW
        
        _mcHeaterPower_uW = pidOutput;
    }
    
    // Post update notification
    [[NSNotificationCenter defaultCenter] postNotificationName:DRPhysicsEngineDidUpdateNotification object:self];
}

#pragma mark - Getters

- (NSString *)currentPhaseName {
    switch (_currentPhase) {
        case DRCryoPhaseRoomTemp: return @"300 K Room Temp";
        case DRCryoPhaseEvacuatingOVC: return @"Evacuating OVC";
        case DRCryoPhasePreCoolingPT: return @"Pulse Tube Pre-Cooling";
        case DRCryoPhaseCondensingMixture: return @"Condensing 3He/4He";
        case DRCryoPhaseCirculatingDilution: return @"Dilution Circulation";
        case DRCryoPhaseBaseTemperature: return @"Base Temp (< 12 mK)";
        case DRCryoPhaseRecoveringMixture: return @"Mixture Recovery";
    }
}

- (NSString *)currentPhaseStatusDescription {
    switch (_currentPhase) {
        case DRCryoPhaseRoomTemp:
            return @"System idle at 295 K. Chamber at atmospheric pressure. He-3/He-4 mixture safely stored in dump tanks.";
        case DRCryoPhaseEvacuatingOVC:
            return [NSString stringWithFormat:@"Turbo pump active. OVC vacuum: %@", [DRTheme formattedPressure:_pressOVC]];
        case DRCryoPhasePreCoolingPT:
            return [NSString stringWithFormat:@"Pulse Tube running. 50K plate: %@, 4K plate: %@", [DRTheme formattedTemperature:_temp50K], [DRTheme formattedTemperature:_temp4K]];
        case DRCryoPhaseCondensingMixture:
            return [NSString stringWithFormat:@"Condensing helium mixture: %.0f%% condensed. Condense line: %.2f bar", _condensedLiquidVolume * 100.0, _pressCondense];
        case DRCryoPhaseCirculatingDilution:
            return [NSString stringWithFormat:@"Circulating 3He at %@. Still heater: %@. Phase separation established in MC.", [DRTheme formattedFlowRate:_flowRate_umol_s], [DRTheme formattedPower:_stillHeaterPower_uW]];
        case DRCryoPhaseBaseTemperature:
            return [NSString stringWithFormat:@"Stable Base Temperature: %@! Quantum experiments operational.", [DRTheme formattedTemperature:_tempMixingChamber]];
        case DRCryoPhaseRecoveringMixture:
            return [NSString stringWithFormat:@"Recovering mixture into dump tanks. Dump pressure: %@", [DRTheme formattedPressure:_pressDump]];
    }
}

- (BOOL)phaseSeparated {
    return (_condensedLiquidVolume > 0.6) && (_tempMixingChamber < 0.87);
}

- (double)phaseBoundaryFraction {
    if (![self phaseSeparated]) return 0.0;
    // Concentrated phase (upper) vs dilute phase (lower) boundary
    return 0.55;
}

@end













































