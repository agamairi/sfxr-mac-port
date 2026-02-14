//
//  SoundGenerator.mm
//  sfxr-macos
//
//  Objective-C++ implementation of the audio synthesis engine
//  Based on the original sfxr by DrPetter
//

#import "SoundGenerator.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define rnd(n) (arc4random_uniform((n) + 1))
#define PI 3.14159265f

static float frnd(float range) {
  return ((float)arc4random() / 0x100000000) * range;
}

// Audio synthesis state
typedef struct {
  bool playing_sample;
  int phase;
  double fperiod;
  double fmaxperiod;
  double fslide;
  double fdslide;
  int period;
  float square_duty;
  float square_slide;
  int env_stage;
  int env_time;
  int env_length[3];
  float env_vol;
  float fphase;
  float fdphase;
  int iphase;
  float phaser_buffer[1024];
  int ipp;
  float noise_buffer[32];
  float fltp;
  float fltdp;
  float fltw;
  float fltw_d;
  float fltdmp;
  float fltphp;
  float flthp;
  float flthp_d;
  float vib_phase;
  float vib_speed;
  float vib_amp;
  int rep_time;
  int rep_limit;
  int arp_time;
  int arp_limit;
  double arp_mod;
} SynthState;

@interface SoundGenerator () {
  SynthState _synthState;
  AVAudioEngine *_audioEngine;
  AVAudioPlayerNode *_playerNode;
  BOOL _isPlaying;
}
@end

@implementation SoundGenerator

- (instancetype)init {
  self = [super init];
  if (self) {
    [self resetParameters];
    _audioEngine = [[AVAudioEngine alloc] init];
    _playerNode = [[AVAudioPlayerNode alloc] init];
    [_audioEngine attachNode:_playerNode];

    AVAudioFormat *format =
        [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100
                                                       channels:1];
    [_audioEngine connect:_playerNode
                       to:_audioEngine.mainMixerNode
                   format:format];

    NSError *error;
    [_audioEngine startAndReturnError:&error];
    if (error) {
      NSLog(@"Error starting audio engine: %@", error);
    }

    _isPlaying = NO;
  }
  return self;
}

- (void)dealloc {
  [_audioEngine stop];
}

- (void)resetParameters {
  _waveType = WaveTypeSquare;

  _startFrequency = 0.3f;
  _minFrequency = 0.0f;
  _slide = 0.0f;
  _deltaSlide = 0.0f;
  _squareDuty = 0.0f;
  _dutySweep = 0.0f;

  _vibratoDepth = 0.0f;
  _vibratoSpeed = 0.0f;
  _vibratoDelay = 0.0f;

  _attackTime = 0.0f;
  _sustainTime = 0.3f;
  _decayTime = 0.4f;
  _sustainPunch = 0.0f;

  _lpFilterCutoff = 1.0f;
  _lpFilterCutoffSweep = 0.0f;
  _lpFilterResonance = 0.0f;
  _hpFilterCutoff = 0.0f;
  _hpFilterCutoffSweep = 0.0f;

  _phaserOffset = 0.0f;
  _phaserSweep = 0.0f;

  _repeatSpeed = 0.0f;

  _changeSpeed = 0.0f;
  _changeAmount = 0.0f;

  _masterVolume = 0.05f;
  _soundVolume = 0.5f;
}

- (void)resetSample:(BOOL)restart {
  if (!restart)
    _synthState.phase = 0;

  _synthState.fperiod = 100.0 / (_startFrequency * _startFrequency + 0.001);
  _synthState.period = (int)_synthState.fperiod;
  _synthState.fmaxperiod = 100.0 / (_minFrequency * _minFrequency + 0.001);
  _synthState.fslide = 1.0 - pow((double)_slide, 3.0) * 0.01;
  _synthState.fdslide = -pow((double)_deltaSlide, 3.0) * 0.000001;
  _synthState.square_duty = 0.5f - _squareDuty * 0.5f;
  _synthState.square_slide = -_dutySweep * 0.00005f;

  if (_changeAmount >= 0.0f)
    _synthState.arp_mod = 1.0 - pow((double)_changeAmount, 2.0) * 0.9;
  else
    _synthState.arp_mod = 1.0 + pow((double)_changeAmount, 2.0) * 10.0;

  _synthState.arp_time = 0;
  _synthState.arp_limit = (int)(pow(1.0f - _changeSpeed, 2.0f) * 20000 + 32);
  if (_changeSpeed == 1.0f)
    _synthState.arp_limit = 0;

  if (!restart) {
    _synthState.fltp = 0.0f;
    _synthState.fltdp = 0.0f;
    _synthState.fltw = pow(_lpFilterCutoff, 3.0f) * 0.1f;
    _synthState.fltw_d = 1.0f + _lpFilterCutoffSweep * 0.0001f;
    _synthState.fltdmp = 5.0f / (1.0f + pow(_lpFilterResonance, 2.0f) * 20.0f) *
                         (0.01f + _synthState.fltw);
    if (_synthState.fltdmp > 0.8f)
      _synthState.fltdmp = 0.8f;
    _synthState.fltphp = 0.0f;
    _synthState.flthp = pow(_hpFilterCutoff, 2.0f) * 0.1f;
    _synthState.flthp_d = 1.0 + _hpFilterCutoffSweep * 0.0003f;

    _synthState.vib_phase = 0.0f;
    _synthState.vib_speed = pow(_vibratoSpeed, 2.0f) * 0.01f;
    _synthState.vib_amp = _vibratoDepth * 0.5f;

    _synthState.env_vol = 0.0f;
    _synthState.env_stage = 0;
    _synthState.env_time = 0;
    _synthState.env_length[0] = (int)(_attackTime * _attackTime * 100000.0f);
    _synthState.env_length[1] = (int)(_sustainTime * _sustainTime * 100000.0f);
    _synthState.env_length[2] = (int)(_decayTime * _decayTime * 100000.0f);

    _synthState.fphase = pow(_phaserOffset, 2.0f) * 1020.0f;
    if (_phaserOffset < 0.0f)
      _synthState.fphase = -_synthState.fphase;
    _synthState.fdphase = pow(_phaserSweep, 2.0f) * 1.0f;
    if (_phaserSweep < 0.0f)
      _synthState.fdphase = -_synthState.fdphase;
    _synthState.iphase = abs((int)_synthState.fphase);
    _synthState.ipp = 0;

    for (int i = 0; i < 1024; i++)
      _synthState.phaser_buffer[i] = 0.0f;

    for (int i = 0; i < 32; i++)
      _synthState.noise_buffer[i] = frnd(2.0f) - 1.0f;

    _synthState.rep_time = 0;
    _synthState.rep_limit = (int)(pow(1.0f - _repeatSpeed, 2.0f) * 20000 + 32);
    if (_repeatSpeed == 0.0f)
      _synthState.rep_limit = 0;
  }
}

- (void)synthSample:(int)length buffer:(float *)buffer {
  for (int i = 0; i < length; i++) {
    if (!_synthState.playing_sample)
      break;

    _synthState.rep_time++;
    if (_synthState.rep_limit != 0 &&
        _synthState.rep_time >= _synthState.rep_limit) {
      _synthState.rep_time = 0;
      [self resetSample:YES];
    }

    _synthState.arp_time++;
    if (_synthState.arp_limit != 0 &&
        _synthState.arp_time >= _synthState.arp_limit) {
      _synthState.arp_limit = 0;
      _synthState.fperiod *= _synthState.arp_mod;
    }

    _synthState.fslide += _synthState.fdslide;
    _synthState.fperiod *= _synthState.fslide;
    if (_synthState.fperiod > _synthState.fmaxperiod) {
      _synthState.fperiod = _synthState.fmaxperiod;
      if (_minFrequency > 0.0f)
        _synthState.playing_sample = false;
    }

    float rfperiod = _synthState.fperiod;
    if (_synthState.vib_amp > 0.0f) {
      _synthState.vib_phase += _synthState.vib_speed;
      rfperiod = _synthState.fperiod *
                 (1.0 + sin(_synthState.vib_phase) * _synthState.vib_amp);
    }
    _synthState.period = (int)rfperiod;
    if (_synthState.period < 8)
      _synthState.period = 8;

    _synthState.square_duty += _synthState.square_slide;
    if (_synthState.square_duty < 0.0f)
      _synthState.square_duty = 0.0f;
    if (_synthState.square_duty > 0.5f)
      _synthState.square_duty = 0.5f;

    _synthState.env_time++;
    if (_synthState.env_time > _synthState.env_length[_synthState.env_stage]) {
      _synthState.env_time = 0;
      _synthState.env_stage++;
      if (_synthState.env_stage == 3)
        _synthState.playing_sample = false;
    }
    if (_synthState.env_stage == 0)
      _synthState.env_vol =
          (float)_synthState.env_time / _synthState.env_length[0];
    if (_synthState.env_stage == 1)
      _synthState.env_vol = 1.0f + pow(1.0f - (float)_synthState.env_time /
                                                  _synthState.env_length[1],
                                       1.0f) *
                                       2.0f * _sustainPunch;
    if (_synthState.env_stage == 2)
      _synthState.env_vol =
          1.0f - (float)_synthState.env_time / _synthState.env_length[2];

    _synthState.fphase += _synthState.fdphase;
    _synthState.iphase = abs((int)_synthState.fphase);
    if (_synthState.iphase > 1023)
      _synthState.iphase = 1023;

    if (_synthState.flthp_d != 0.0f) {
      _synthState.flthp *= _synthState.flthp_d;
      if (_synthState.flthp < 0.00001f)
        _synthState.flthp = 0.00001f;
      if (_synthState.flthp > 0.1f)
        _synthState.flthp = 0.1f;
    }

    float ssample = 0.0f;
    for (int si = 0; si < 8; si++) {
      float sample = 0.0f;
      _synthState.phase++;
      if (_synthState.phase >= _synthState.period) {
        _synthState.phase %= _synthState.period;
        if (_waveType == WaveTypeNoise)
          for (int i = 0; i < 32; i++)
            _synthState.noise_buffer[i] = frnd(2.0f) - 1.0f;
      }

      float fp = (float)_synthState.phase / _synthState.period;
      switch (_waveType) {
      case WaveTypeSquare:
        if (fp < _synthState.square_duty)
          sample = 0.5f;
        else
          sample = -0.5f;
        break;
      case WaveTypeSawtooth:
        sample = 1.0f - fp * 2;
        break;
      case WaveTypeSine:
        sample = (float)sin(fp * 2 * PI);
        break;
      case WaveTypeNoise:
        sample = _synthState
                     .noise_buffer[_synthState.phase * 32 / _synthState.period];
        break;
      }

      float pp = _synthState.fltp;
      _synthState.fltw *= _synthState.fltw_d;
      if (_synthState.fltw < 0.0f)
        _synthState.fltw = 0.0f;
      if (_synthState.fltw > 0.1f)
        _synthState.fltw = 0.1f;
      if (_lpFilterCutoff != 1.0f) {
        _synthState.fltdp += (sample - _synthState.fltp) * _synthState.fltw;
        _synthState.fltdp -= _synthState.fltdp * _synthState.fltdmp;
      } else {
        _synthState.fltp = sample;
        _synthState.fltdp = 0.0f;
      }
      _synthState.fltp += _synthState.fltdp;

      _synthState.fltphp += _synthState.fltp - pp;
      _synthState.fltphp -= _synthState.fltphp * _synthState.flthp;
      sample = _synthState.fltphp;

      _synthState.phaser_buffer[_synthState.ipp & 1023] = sample;
      sample +=
          _synthState
              .phaser_buffer[(_synthState.ipp - _synthState.iphase + 1024) &
                             1023];
      _synthState.ipp = (_synthState.ipp + 1) & 1023;

      ssample += sample * _synthState.env_vol;
    }
    ssample = ssample / 8 * _masterVolume;
    ssample *= 2.0f * _soundVolume;

    if (ssample > 1.0f)
      ssample = 1.0f;
    if (ssample < -1.0f)
      ssample = -1.0f;
    buffer[i] = ssample;
  }
}

- (void)playSound {
  [self stopSound];

  _synthState.playing_sample = true;
  [self resetSample:NO];
  _isPlaying = YES;

  // Generate audio buffer
  const int bufferSize = 1024 * 64;
  float *audioData = (float *)malloc(bufferSize * sizeof(float));
  memset(audioData, 0, bufferSize * sizeof(float));

  [self synthSample:bufferSize buffer:audioData];

  // Create audio buffer and schedule playback
  AVAudioFormat *format =
      [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];
  AVAudioPCMBuffer *pcmBuffer =
      [[AVAudioPCMBuffer alloc] initWithPCMFormat:format
                                    frameCapacity:bufferSize];
  pcmBuffer.frameLength = bufferSize;

  float *channelData = pcmBuffer.floatChannelData[0];
  memcpy(channelData, audioData, bufferSize * sizeof(float));
  free(audioData);

  [_playerNode scheduleBuffer:pcmBuffer
                       atTime:nil
                      options:AVAudioPlayerNodeBufferInterrupts
            completionHandler:^{
              self->_isPlaying = NO;
            }];

  if (!_playerNode.isPlaying) {
    [_playerNode play];
  }
}

- (void)stopSound {
  [_playerNode stop];
  _synthState.playing_sample = false;
  _isPlaying = NO;
}

- (BOOL)isPlaying {
  return _isPlaying;
}

#pragma mark - Preset Generators

- (void)generatePickupCoin {
  [self resetParameters];
  _startFrequency = 0.4f + frnd(0.5f);
  _attackTime = 0.0f;
  _sustainTime = frnd(0.1f);
  _decayTime = 0.1f + frnd(0.4f);
  _sustainPunch = 0.3f + frnd(0.3f);
  if (rnd(1)) {
    _changeSpeed = 0.5f + frnd(0.2f);
    _changeAmount = 0.2f + frnd(0.4f);
  }
}

- (void)generateLaserShoot {
  [self resetParameters];
  _waveType = (WaveType)rnd(2);
  if (_waveType == WaveTypeSine && rnd(1))
    _waveType = (WaveType)rnd(1);
  _startFrequency = 0.5f + frnd(0.5f);
  _minFrequency = _startFrequency - 0.2f - frnd(0.6f);
  if (_minFrequency < 0.2f)
    _minFrequency = 0.2f;
  _slide = -0.15f - frnd(0.2f);
  if (rnd(2) == 0) {
    _startFrequency = 0.3f + frnd(0.6f);
    _minFrequency = frnd(0.1f);
    _slide = -0.35f - frnd(0.3f);
  }
  if (rnd(1)) {
    _squareDuty = frnd(0.5f);
    _dutySweep = frnd(0.2f);
  } else {
    _squareDuty = 0.4f + frnd(0.5f);
    _dutySweep = -frnd(0.7f);
  }
  _attackTime = 0.0f;
  _sustainTime = 0.1f + frnd(0.2f);
  _decayTime = frnd(0.4f);
  if (rnd(1))
    _sustainPunch = frnd(0.3f);
  if (rnd(2) == 0) {
    _phaserOffset = frnd(0.2f);
    _phaserSweep = -frnd(0.2f);
  }
  if (rnd(1))
    _hpFilterCutoff = frnd(0.3f);
}

- (void)generateExplosion {
  [self resetParameters];
  _waveType = WaveTypeNoise;
  if (rnd(1)) {
    _startFrequency = 0.1f + frnd(0.4f);
    _slide = -0.1f + frnd(0.4f);
  } else {
    _startFrequency = 0.2f + frnd(0.7f);
    _slide = -0.2f - frnd(0.2f);
  }
  _startFrequency *= _startFrequency;
  if (rnd(4) == 0)
    _slide = 0.0f;
  if (rnd(2) == 0)
    _repeatSpeed = 0.3f + frnd(0.5f);
  _attackTime = 0.0f;
  _sustainTime = 0.1f + frnd(0.3f);
  _decayTime = frnd(0.5f);
  if (rnd(1) == 0) {
    _phaserOffset = -0.3f + frnd(0.9f);
    _phaserSweep = -frnd(0.3f);
  }
  _sustainPunch = 0.2f + frnd(0.6f);
  if (rnd(1)) {
    _vibratoDepth = frnd(0.7f);
    _vibratoSpeed = frnd(0.6f);
  }
  if (rnd(2) == 0) {
    _changeSpeed = 0.6f + frnd(0.3f);
    _changeAmount = 0.8f - frnd(1.6f);
  }
}

- (void)generatePowerup {
  [self resetParameters];
  if (rnd(1))
    _waveType = WaveTypeSawtooth;
  else
    _squareDuty = frnd(0.6f);
  if (rnd(1)) {
    _startFrequency = 0.2f + frnd(0.3f);
    _slide = 0.1f + frnd(0.4f);
    _repeatSpeed = 0.4f + frnd(0.4f);
  } else {
    _startFrequency = 0.2f + frnd(0.3f);
    _slide = 0.05f + frnd(0.2f);
    if (rnd(1)) {
      _vibratoDepth = frnd(0.7f);
      _vibratoSpeed = frnd(0.6f);
    }
  }
  _attackTime = 0.0f;
  _sustainTime = frnd(0.4f);
  _decayTime = 0.1f + frnd(0.4f);
}

- (void)generateHitHurt {
  [self resetParameters];
  _waveType = (WaveType)rnd(2);
  if (_waveType == WaveTypeSine)
    _waveType = WaveTypeNoise;
  if (_waveType == WaveTypeSquare)
    _squareDuty = frnd(0.6f);
  _startFrequency = 0.2f + frnd(0.6f);
  _slide = -0.3f - frnd(0.4f);
  _attackTime = 0.0f;
  _sustainTime = frnd(0.1f);
  _decayTime = 0.1f + frnd(0.2f);
  if (rnd(1))
    _hpFilterCutoff = frnd(0.3f);
}

- (void)generateJump {
  [self resetParameters];
  _waveType = WaveTypeSquare;
  _squareDuty = frnd(0.6f);
  _startFrequency = 0.3f + frnd(0.3f);
  _slide = 0.1f + frnd(0.2f);
  _attackTime = 0.0f;
  _sustainTime = 0.1f + frnd(0.3f);
  _decayTime = 0.1f + frnd(0.2f);
  if (rnd(1))
    _hpFilterCutoff = frnd(0.3f);
  if (rnd(1))
    _lpFilterCutoff = 1.0f - frnd(0.6f);
}

- (void)generateBlipSelect {
  [self resetParameters];
  _waveType = (WaveType)rnd(1);
  if (_waveType == WaveTypeSquare)
    _squareDuty = frnd(0.6f);
  _startFrequency = 0.2f + frnd(0.4f);
  _attackTime = 0.0f;
  _sustainTime = 0.1f + frnd(0.1f);
  _decayTime = frnd(0.2f);
  _hpFilterCutoff = 0.1f;
}

- (void)randomize {
  _startFrequency = pow(frnd(2.0f) - 1.0f, 2.0f);
  if (rnd(1))
    _startFrequency = pow(frnd(2.0f) - 1.0f, 3.0f) + 0.5f;
  _minFrequency = 0.0f;
  _slide = pow(frnd(2.0f) - 1.0f, 5.0f);
  if (_startFrequency > 0.7f && _slide > 0.2f)
    _slide = -_slide;
  if (_startFrequency < 0.2f && _slide < -0.05f)
    _slide = -_slide;
  _deltaSlide = pow(frnd(2.0f) - 1.0f, 3.0f);
  _squareDuty = frnd(2.0f) - 1.0f;
  _dutySweep = pow(frnd(2.0f) - 1.0f, 3.0f);
  _vibratoDepth = pow(frnd(2.0f) - 1.0f, 3.0f);
  _vibratoSpeed = frnd(2.0f) - 1.0f;
  _vibratoDelay = frnd(2.0f) - 1.0f;
  _attackTime = pow(frnd(2.0f) - 1.0f, 3.0f);
  _sustainTime = pow(frnd(2.0f) - 1.0f, 2.0f);
  _decayTime = frnd(2.0f) - 1.0f;
  _sustainPunch = pow(frnd(0.8f), 2.0f);
  if (_attackTime + _sustainTime + _decayTime < 0.2f) {
    _sustainTime += 0.2f + frnd(0.3f);
    _decayTime += 0.2f + frnd(0.3f);
  }
  _lpFilterResonance = frnd(2.0f) - 1.0f;
  _lpFilterCutoff = 1.0f - pow(frnd(1.0f), 3.0f);
  _lpFilterCutoffSweep = pow(frnd(2.0f) - 1.0f, 3.0f);
  if (_lpFilterCutoff < 0.1f && _lpFilterCutoffSweep < -0.05f)
    _lpFilterCutoffSweep = -_lpFilterCutoffSweep;
  _hpFilterCutoff = pow(frnd(1.0f), 5.0f);
  _hpFilterCutoffSweep = pow(frnd(2.0f) - 1.0f, 5.0f);
  _phaserOffset = pow(frnd(2.0f) - 1.0f, 3.0f);
  _phaserSweep = pow(frnd(2.0f) - 1.0f, 3.0f);
  _repeatSpeed = frnd(2.0f) - 1.0f;
  _changeSpeed = frnd(2.0f) - 1.0f;
  _changeAmount = frnd(2.0f) - 1.0f;
}

- (void)mutate {
  if (rnd(1))
    _startFrequency += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _slide += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _deltaSlide += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _squareDuty += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _dutySweep += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _vibratoDepth += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _vibratoSpeed += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _vibratoDelay += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _attackTime += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _sustainTime += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _decayTime += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _sustainPunch += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _lpFilterResonance += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _lpFilterCutoff += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _lpFilterCutoffSweep += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _hpFilterCutoff += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _hpFilterCutoffSweep += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _phaserOffset += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _phaserSweep += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _repeatSpeed += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _changeSpeed += frnd(0.1f) - 0.05f;
  if (rnd(1))
    _changeAmount += frnd(0.1f) - 0.05f;
}

#pragma mark - File I/O

- (BOOL)loadSettingsFromFile:(NSString *)path {
  FILE *file = fopen([path UTF8String], "rb");
  if (!file)
    return NO;

  int version = 0;
  size_t n;
  n = fread(&version, 1, sizeof(int), file);
  if (version != 100 && version != 101 && version != 102) {
    fclose(file);
    return NO;
  }

  int wave_type;
  n = fread(&wave_type, 1, sizeof(int), file);
  _waveType = (WaveType)wave_type;

  float sound_vol = 0.5f;
  if (version == 102)
    n = fread(&sound_vol, 1, sizeof(float), file);
  _soundVolume = sound_vol;

  float p_base_freq, p_freq_limit, p_freq_ramp, p_freq_dramp;
  float p_duty, p_duty_ramp;
  float p_vib_strength, p_vib_speed, p_vib_delay;
  float p_env_attack, p_env_sustain, p_env_decay, p_env_punch;
  bool filter_on;
  float p_lpf_resonance, p_lpf_freq, p_lpf_ramp;
  float p_hpf_freq, p_hpf_ramp;
  float p_pha_offset, p_pha_ramp;
  float p_repeat_speed;
  float p_arp_speed, p_arp_mod;

  n = fread(&p_base_freq, 1, sizeof(float), file);
  n = fread(&p_freq_limit, 1, sizeof(float), file);
  n = fread(&p_freq_ramp, 1, sizeof(float), file);
  if (version >= 101)
    n = fread(&p_freq_dramp, 1, sizeof(float), file);
  else
    p_freq_dramp = 0.0f;
  n = fread(&p_duty, 1, sizeof(float), file);
  n = fread(&p_duty_ramp, 1, sizeof(float), file);

  n = fread(&p_vib_strength, 1, sizeof(float), file);
  n = fread(&p_vib_speed, 1, sizeof(float), file);
  n = fread(&p_vib_delay, 1, sizeof(float), file);

  n = fread(&p_env_attack, 1, sizeof(float), file);
  n = fread(&p_env_sustain, 1, sizeof(float), file);
  n = fread(&p_env_decay, 1, sizeof(float), file);
  n = fread(&p_env_punch, 1, sizeof(float), file);

  n = fread(&filter_on, 1, sizeof(bool), file);
  n = fread(&p_lpf_resonance, 1, sizeof(float), file);
  n = fread(&p_lpf_freq, 1, sizeof(float), file);
  n = fread(&p_lpf_ramp, 1, sizeof(float), file);
  n = fread(&p_hpf_freq, 1, sizeof(float), file);
  n = fread(&p_hpf_ramp, 1, sizeof(float), file);

  n = fread(&p_pha_offset, 1, sizeof(float), file);
  n = fread(&p_pha_ramp, 1, sizeof(float), file);

  n = fread(&p_repeat_speed, 1, sizeof(float), file);

  if (version >= 101) {
    n = fread(&p_arp_speed, 1, sizeof(float), file);
    n = fread(&p_arp_mod, 1, sizeof(float), file);
  } else {
    p_arp_speed = 0.0f;
    p_arp_mod = 0.0f;
  }

  fclose(file);

  _startFrequency = p_base_freq;
  _minFrequency = p_freq_limit;
  _slide = p_freq_ramp;
  _deltaSlide = p_freq_dramp;
  _squareDuty = p_duty;
  _dutySweep = p_duty_ramp;
  _vibratoDepth = p_vib_strength;
  _vibratoSpeed = p_vib_speed;
  _vibratoDelay = p_vib_delay;
  _attackTime = p_env_attack;
  _sustainTime = p_env_sustain;
  _decayTime = p_env_decay;
  _sustainPunch = p_env_punch;
  _lpFilterResonance = p_lpf_resonance;
  _lpFilterCutoff = p_lpf_freq;
  _lpFilterCutoffSweep = p_lpf_ramp;
  _hpFilterCutoff = p_hpf_freq;
  _hpFilterCutoffSweep = p_hpf_ramp;
  _phaserOffset = p_pha_offset;
  _phaserSweep = p_pha_ramp;
  _repeatSpeed = p_repeat_speed;
  _changeSpeed = p_arp_speed;
  _changeAmount = p_arp_mod;

  return YES;
}

- (BOOL)saveSettingsToFile:(NSString *)path {
  FILE *file = fopen([path UTF8String], "wb");
  if (!file)
    return NO;

  int version = 102;
  fwrite(&version, 1, sizeof(int), file);

  int wave_type = (int)_waveType;
  fwrite(&wave_type, 1, sizeof(int), file);
  fwrite(&_soundVolume, 1, sizeof(float), file);

  fwrite(&_startFrequency, 1, sizeof(float), file);
  fwrite(&_minFrequency, 1, sizeof(float), file);
  fwrite(&_slide, 1, sizeof(float), file);
  fwrite(&_deltaSlide, 1, sizeof(float), file);
  fwrite(&_squareDuty, 1, sizeof(float), file);
  fwrite(&_dutySweep, 1, sizeof(float), file);

  fwrite(&_vibratoDepth, 1, sizeof(float), file);
  fwrite(&_vibratoSpeed, 1, sizeof(float), file);
  fwrite(&_vibratoDelay, 1, sizeof(float), file);

  fwrite(&_attackTime, 1, sizeof(float), file);
  fwrite(&_sustainTime, 1, sizeof(float), file);
  fwrite(&_decayTime, 1, sizeof(float), file);
  fwrite(&_sustainPunch, 1, sizeof(float), file);

  bool filter_on = false;
  fwrite(&filter_on, 1, sizeof(bool), file);
  fwrite(&_lpFilterResonance, 1, sizeof(float), file);
  fwrite(&_lpFilterCutoff, 1, sizeof(float), file);
  fwrite(&_lpFilterCutoffSweep, 1, sizeof(float), file);
  fwrite(&_hpFilterCutoff, 1, sizeof(float), file);
  fwrite(&_hpFilterCutoffSweep, 1, sizeof(float), file);

  fwrite(&_phaserOffset, 1, sizeof(float), file);
  fwrite(&_phaserSweep, 1, sizeof(float), file);

  fwrite(&_repeatSpeed, 1, sizeof(float), file);

  fwrite(&_changeSpeed, 1, sizeof(float), file);
  fwrite(&_changeAmount, 1, sizeof(float), file);

  fclose(file);
  return YES;
}

- (BOOL)exportWAVToFile:(NSString *)path
           withBitDepth:(int)bits
             sampleRate:(int)rate {
  FILE *foutput = fopen([path UTF8String], "wb");
  if (!foutput)
    return NO;

  // Generate all samples first
  const int maxSamples = rate * 10; // Max 10 seconds
  float *samples = (float *)malloc(maxSamples * sizeof(float));
  memset(samples, 0, maxSamples * sizeof(float));

  _synthState.playing_sample = true;
  [self resetSample:NO];

  int samplesWritten = 0;
  while (_synthState.playing_sample && samplesWritten < maxSamples) {
    int chunkSize = 256;
    if (samplesWritten + chunkSize > maxSamples)
      chunkSize = maxSamples - samplesWritten;
    [self synthSample:chunkSize buffer:samples + samplesWritten];
    samplesWritten += chunkSize;
  }

  // Write WAV header
  unsigned int dword = 0;
  unsigned short word = 0;
  fwrite("RIFF", 4, 1, foutput);
  dword = 36 + samplesWritten * bits / 8;
  fwrite(&dword, 1, 4, foutput);
  fwrite("WAVE", 4, 1, foutput);

  fwrite("fmt ", 4, 1, foutput);
  dword = 16;
  fwrite(&dword, 1, 4, foutput);
  word = 1;
  fwrite(&word, 1, 2, foutput);
  word = 1;
  fwrite(&word, 1, 2, foutput);
  dword = rate;
  fwrite(&dword, 1, 4, foutput);
  dword = rate * bits / 8;
  fwrite(&dword, 1, 4, foutput);
  word = bits / 8;
  fwrite(&word, 1, 2, foutput);
  word = bits;
  fwrite(&word, 1, 2, foutput);

  fwrite("data", 4, 1, foutput);
  dword = samplesWritten * bits / 8;
  fwrite(&dword, 1, 4, foutput);

  // Write sample data
  for (int i = 0; i < samplesWritten; i++) {
    float sample = samples[i] * 4.0f; // Gain boost
    if (sample > 1.0f)
      sample = 1.0f;
    if (sample < -1.0f)
      sample = -1.0f;

    if (bits == 16) {
      short isample = (short)(sample * 32000);
      fwrite(&isample, 1, 2, foutput);
    } else {
      unsigned char isample = (unsigned char)(sample * 127 + 128);
      fwrite(&isample, 1, 1, foutput);
    }
  }

  free(samples);
  fclose(foutput);
  return YES;
}

@end
