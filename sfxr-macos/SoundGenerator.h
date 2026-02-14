//
//  SoundGenerator.h
//  sfxr-macos
//
//  Objective-C++ wrapper around the C++ audio synthesis engine
//  Manages sound parameters and Core Audio playback
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, WaveType) {
  WaveTypeSquare = 0,
  WaveTypeSawtooth = 1,
  WaveTypeSine = 2,
  WaveTypeNoise = 3
};

@interface SoundGenerator : NSObject

// Wave type
@property(nonatomic, assign) WaveType waveType;

// Envelope parameters
@property(nonatomic, assign) float attackTime;
@property(nonatomic, assign) float sustainTime;
@property(nonatomic, assign) float sustainPunch;
@property(nonatomic, assign) float decayTime;

// Frequency parameters
@property(nonatomic, assign) float startFrequency;
@property(nonatomic, assign) float minFrequency;
@property(nonatomic, assign) float slide;
@property(nonatomic, assign) float deltaSlide;

// Vibrato
@property(nonatomic, assign) float vibratoDepth;
@property(nonatomic, assign) float vibratoSpeed;
@property(nonatomic, assign) float vibratoDelay;

// Arpeggiation
@property(nonatomic, assign) float changeAmount;
@property(nonatomic, assign) float changeSpeed;

// Square wave duty (only applies to square wave)
@property(nonatomic, assign) float squareDuty;
@property(nonatomic, assign) float dutySweep;

// Repeat
@property(nonatomic, assign) float repeatSpeed;

// Phaser
@property(nonatomic, assign) float phaserOffset;
@property(nonatomic, assign) float phaserSweep;

// Filters
@property(nonatomic, assign) float lpFilterCutoff;
@property(nonatomic, assign) float lpFilterCutoffSweep;
@property(nonatomic, assign) float lpFilterResonance;
@property(nonatomic, assign) float hpFilterCutoff;
@property(nonatomic, assign) float hpFilterCutoffSweep;

// Master volume
@property(nonatomic, assign) float masterVolume;
@property(nonatomic, assign) float soundVolume;

// Playback control
- (void)playSound;
- (void)stopSound;
- (BOOL)isPlaying;

// Preset generators
- (void)generatePickupCoin;
- (void)generateLaserShoot;
- (void)generateExplosion;
- (void)generatePowerup;
- (void)generateHitHurt;
- (void)generateJump;
- (void)generateBlipSelect;

// Randomization
- (void)randomize;
- (void)mutate;

// Parameter control
- (void)resetParameters;

// File I/O
- (BOOL)loadSettingsFromFile:(NSString *)path;
- (BOOL)saveSettingsToFile:(NSString *)path;
- (BOOL)exportWAVToFile:(NSString *)path
           withBitDepth:(int)bits
             sampleRate:(int)rate;

@end
