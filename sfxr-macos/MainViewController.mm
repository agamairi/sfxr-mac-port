//
//  MainViewController.mm
//  sfxr-macos
//
//  Dark/Light Mode UI Implementation
//

#import "MainViewController.h"
#import "SoundGenerator.h"
#import "WaveformView.h"
#import <QuartzCore/QuartzCore.h>

@interface MainViewController ()
@property(nonatomic, strong) SoundGenerator *soundGenerator;
@property(nonatomic, strong) WaveformView *waveformView;
@property(nonatomic, strong) NSSegmentedControl *waveTypeControl;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSSlider *> *sliders;
@property(nonatomic, strong) NSButton *playButton;
@property(nonatomic, strong) NSButton *themeToggle;
@property(nonatomic, assign) BOOL isDarkMode;

// Views that need color updates
@property(nonatomic, strong) NSView *leftPanel;
@property(nonatomic, strong) NSView *rightPanel;
@property(nonatomic, strong) NSView *centerPanel;
@property(nonatomic, strong) NSMutableArray<NSTextField *> *labels;
@property(nonatomic, strong) NSMutableArray<NSTextField *> *headers;
@property(nonatomic, strong) NSMutableArray<NSTextField *>
    *valueLabels; // For future use if we show values
@end

@implementation MainViewController

- (void)loadView {
  NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1100, 700)];
  view.wantsLayer = YES;
  self.view = view;

  _soundGenerator = [[SoundGenerator alloc] init];
  _sliders = [NSMutableDictionary dictionary];
  _labels = [NSMutableArray array];
  _headers = [NSMutableArray array];

  _isDarkMode = YES; // Default to dark

  [self createUI];
  [self updateUIFromGenerator];
}

- (void)viewWillAppear {
  [super viewWillAppear];
  [self updateThemeColors];
}

- (void)createUI {
  CGFloat width = self.view.bounds.size.width;
  CGFloat height = self.view.bounds.size.height;

  CGFloat leftWidth = 220;
  CGFloat rightWidth = 280;
  CGFloat centerWidth = width - leftWidth - rightWidth;

  // ==========================================
  // LEFT PANEL (Presets)
  // ==========================================
  _leftPanel =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, leftWidth, height)];
  _leftPanel.wantsLayer = YES;
  _leftPanel.layer.borderWidth = 1.0;
  [self.view addSubview:_leftPanel];

  CGFloat yPos = height - 40;

  // Header
  [self addLabel:@"PRESETS"
           frame:NSMakeRect(20, yPos, leftWidth - 40, 20)
          parent:_leftPanel
        isHeader:NO];
  yPos -= 40;

  NSArray *gens = @[
    @"Pickup/Coin", @"Laser/Shoot", @"Explosion", @"Powerup", @"Hit/Hurt",
    @"Jump", @"Blip/Select"
  ];
  NSArray *sels = @[
    @"generatePickupCoin:", @"generateLaserShoot:", @"generateExplosion:",
    @"generatePowerup:", @"generateHitHurt:", @"generateJump:",
    @"generateBlipSelect:"
  ];

  for (int i = 0; i < gens.count; i++) {
    NSButton *btn = [self createFlatButton:gens[i]
                                    action:NSSelectorFromString(sels[i])];
    btn.frame = NSMakeRect(20, yPos, leftWidth - 40, 36);
    [_leftPanel addSubview:btn];
    yPos -= 44;
  }

  // Bottom Buttons (Mutate/Randomize)
  yPos = 20;
  NSButton *randBtn = [self createOutlineButton:@"RANDOMIZE"
                                         action:@selector(randomize:)];
  randBtn.frame = NSMakeRect(20, yPos, leftWidth - 40, 36);
  [_leftPanel addSubview:randBtn];

  yPos += 44;
  NSButton *mutBtn = [self createOutlineButton:@"MUTATE"
                                        action:@selector(mutate:)];
  mutBtn.frame = NSMakeRect(20, yPos, leftWidth - 40, 36);
  [_leftPanel addSubview:mutBtn];

  // ==========================================
  // RIGHT PANEL (Global/Output)
  // ==========================================
  _rightPanel = [[NSView alloc]
      initWithFrame:NSMakeRect(width - rightWidth, 0, rightWidth, height)];
  _rightPanel.wantsLayer = YES;
  _rightPanel.layer.borderWidth = 1.0;
  [self.view addSubview:_rightPanel];

  yPos = height - 30;

  // Theme Toggle
  _themeToggle = [[NSButton alloc]
      initWithFrame:NSMakeRect(rightWidth - 100, yPos, 80, 24)];
  _themeToggle.bezelStyle = NSBezelStyleRounded;
  _themeToggle.title = @"Light Mode";
  _themeToggle.target = self;
  _themeToggle.action = @selector(toggleTheme:);
  [_rightPanel addSubview:_themeToggle];

  yPos -= 40;

  // Header
  [self addLabel:@"WAVEFORM"
           frame:NSMakeRect(20, yPos, rightWidth - 40, 20)
          parent:_rightPanel
        isHeader:NO];
  yPos -= 35;

  // Waveform View
  _waveformView = [[WaveformView alloc]
      initWithFrame:NSMakeRect(20, yPos - 60, rightWidth - 40, 60)];
  __unsafe_unretained MainViewController *weakSelf = self;
  _waveformView.onPlay = ^{
    [weakSelf playSound:nil];
  };
  [_rightPanel addSubview:_waveformView];
  yPos -= 100;

  // Waveform Selector
  _waveTypeControl = [[NSSegmentedControl alloc]
      initWithFrame:NSMakeRect(20, yPos, rightWidth - 40, 30)];
  _waveTypeControl.segmentCount = 4;
  [_waveTypeControl setLabel:@"SQR" forSegment:0];
  [_waveTypeControl setLabel:@"SAW" forSegment:1];
  [_waveTypeControl setLabel:@"SIN" forSegment:2];
  [_waveTypeControl setLabel:@"NOI" forSegment:3];
  [_waveTypeControl setTarget:self];
  [_waveTypeControl setAction:@selector(waveTypeChanged:)];
  [_waveTypeControl setSelectedSegment:0];
  [_waveTypeControl setSegmentStyle:NSSegmentStyleTexturedRounded];
  [_rightPanel addSubview:_waveTypeControl];
  yPos -= 50;

  // Master Volume
  [self addLabel:@"MASTER VOLUME"
           frame:NSMakeRect(20, yPos, 150, 20)
          parent:_rightPanel
        isHeader:NO];

  // Value label
  NSTextField *volValue = [self createLabel:@"100%" size:11]; // simplified
  volValue.alignment = NSTextAlignmentRight;
  volValue.frame = NSMakeRect(rightWidth - 70, yPos, 50, 20);
  // Keep reference if we want to change color, but simplified for now
  [_rightPanel addSubview:volValue];

  yPos -= 25;
  NSSlider *volSlider = [[NSSlider alloc]
      initWithFrame:NSMakeRect(20, yPos, rightWidth - 40, 20)];
  volSlider.minValue = 0.0;
  volSlider.maxValue = 1.0;
  volSlider.target = self;
  volSlider.action = @selector(sliderChanged:);
  self.sliders[@"soundVolume"] = volSlider;
  [_rightPanel addSubview:volSlider];
  yPos -= 60;

  // Play Button
  _playButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(20, yPos, rightWidth - 40, 50)];
  _playButton.title = @"▶ Play Sound";
  _playButton.bezelStyle = NSBezelStyleRegularSquare;
  _playButton.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
  _playButton.keyEquivalent = @" ";
  _playButton.target = self;
  _playButton.action = @selector(playSound:);
  _playButton.wantsLayer = YES;
  [_rightPanel addSubview:_playButton];
  yPos -= 60;

  // Export Button
  NSButton *expBtn = [self createOutlineButton:@"Export .WAV"
                                        action:@selector(exportWAV:)];
  expBtn.frame = NSMakeRect(20, yPos, rightWidth - 40, 40);
  [_rightPanel addSubview:expBtn];
  yPos -= 60;

  // Load / Save
  NSButton *loadBtn = [self createOutlineButton:@"Load"
                                         action:@selector(loadSound:)];
  loadBtn.frame = NSMakeRect(20, yPos, (rightWidth - 50) / 2, 32);
  [_rightPanel addSubview:loadBtn];

  NSButton *saveBtn = [self createOutlineButton:@"Save"
                                         action:@selector(saveSound:)];
  saveBtn.frame = NSMakeRect(20 + (rightWidth - 50) / 2 + 10, yPos,
                             (rightWidth - 50) / 2, 32);
  [_rightPanel addSubview:saveBtn];
  yPos -= 50;

  // Info Stats
  [self addLabel:@"44100 Hz            16-BIT"
           frame:NSMakeRect(20, yPos, rightWidth - 40, 20)
          parent:_rightPanel
        isHeader:NO];

  // Footer
  NSTextField *footer = [self createLabel:@"SFXR - macos" size:10];
  footer.alignment = NSTextAlignmentCenter;
  footer.frame = NSMakeRect(20, 20, rightWidth - 40, 20);
  // footer color is static usually, or handled in updateTheme
  [_rightPanel addSubview:footer];
  [_labels addObject:footer]; // Add to labels to auto-update color

  // ==========================================
  // CENTER PANEL (Parameters) - Wrapped in ScrollView
  // ==========================================

  // Calculate required height based on content
  // We have:
  // - 50px margin top
  // - ENVELOPE (Header + 4 sliders) -> 20 + 4*32 + 20 gap = 168
  // - FREQUENCY (Header + 4 sliders) -> 20 + 4*32 + 20 gap = 168
  // - VIBRATO (Header + 2 sliders) -> 20 + 2*32 + 20 gap = 104
  // - FILTERS (Header + 2 sliders) -> 20 + 2*32 + 10 gap = 94
  // - ADDITIONAL (Header + 3 sliders) -> 20 + 3*32 = 116
  // Total approx: 50 + 168 + 168 + 104 + 94 + 116 = 700 + margins -> safe
  // estimate 850-900

  CGFloat contentHeight = 900;

  NSScrollView *scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(leftWidth, 0, centerWidth, height)];
  scrollView.hasVerticalScroller = YES;
  scrollView.hasHorizontalScroller = NO;
  scrollView.autohidesScrollers = YES;
  scrollView.drawsBackground = NO; // Handle background in document view
  scrollView.wantsLayer = YES;

  _centerPanel = [[NSView alloc]
      initWithFrame:NSMakeRect(0, 0, centerWidth, contentHeight)];
  _centerPanel.wantsLayer = YES;

  scrollView.documentView = _centerPanel;

  // Scroll to top (in non-flipped coordinates, visible rect should be at top of
  // document)
  [scrollView.contentView scrollToPoint:NSMakePoint(0, contentHeight - height)];

  [self.view addSubview:scrollView];

  // Start yPos at top of the document view
  yPos = contentHeight - 50;

  CGFloat colMargin = 40;
  CGFloat contentWidth = centerWidth - 2 * colMargin;

  // Sections
  yPos = [self addSectionHeader:@"ENVELOPE"
                              y:yPos
                         parent:_centerPanel
                         margin:colMargin];
  yPos = [self addParamSlider:@"ATTACK TIME"
                          key:@"attackTime"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"SUSTAIN TIME"
                          key:@"sustainTime"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"SUSTAIN PUNCH"
                          key:@"sustainPunch"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"DECAY TIME"
                          key:@"decayTime"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];

  yPos -= 20;
  yPos = [self addSectionHeader:@"FREQUENCY"
                              y:yPos
                         parent:_centerPanel
                         margin:colMargin];
  yPos = [self addParamSlider:@"START FREQUENCY"
                          key:@"startFrequency"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"MIN FREQUENCY"
                          key:@"minFrequency"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"SLIDE"
                          key:@"slide"
                          min:-1.0
                          max:1.0
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"DELTA SLIDE"
                          key:@"deltaSlide"
                          min:-1.0
                          max:1.0
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];

  yPos -= 20;
  yPos = [self addSectionHeader:@"VIBRATO"
                              y:yPos
                         parent:_centerPanel
                         margin:colMargin];
  yPos = [self addParamSlider:@"VIBRATO DEPTH"
                          key:@"vibratoDepth"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"VIBRATO SPEED"
                          key:@"vibratoSpeed"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];

  yPos -= 20;
  yPos = [self addSectionHeader:@"FILTERS"
                              y:yPos
                         parent:_centerPanel
                         margin:colMargin];
  yPos = [self addParamSlider:@"LP CUTOFF"
                          key:@"lpFilterCutoff"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"HP CUTOFF"
                          key:@"hpFilterCutoff"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];

  yPos -= 10;
  [self addLabel:@"ADDITIONAL"
           frame:NSMakeRect(colMargin, yPos, 200, 20)
          parent:_centerPanel
        isHeader:YES];
  yPos -= 30;

  yPos = [self addParamSlider:@"CHANGE AMT"
                          key:@"changeAmount"
                          min:-1.0
                          max:1.0
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"SQR DUTY"
                          key:@"squareDuty"
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
  yPos = [self addParamSlider:@"PHASER OFF"
                          key:@"phaserOffset"
                          min:-1.0
                          max:1.0
                            y:yPos
                            w:contentWidth
                            p:_centerPanel
                            m:colMargin];
}

#pragma mark - Theme Management

- (void)updateThemeColors {
  // Define Colors
  NSColor *bg, *panelBg, *border, *textMain, *textSec, *accent;

  if (_isDarkMode) {
    bg = [NSColor colorWithCalibratedRed:0.08 green:0.08 blue:0.09 alpha:1.0];
    panelBg = [NSColor colorWithCalibratedRed:0.11
                                        green:0.11
                                         blue:0.12
                                        alpha:1.0];
    border = [NSColor colorWithCalibratedRed:0.05
                                       green:0.05
                                        blue:0.05
                                       alpha:1.0];
    textMain = [NSColor colorWithCalibratedWhite:0.9 alpha:1.0];
    textSec = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    accent = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    self.view.window.appearance =
        [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    _themeToggle.title = @"Light Mode";
  } else {
    bg = [NSColor whiteColor];
    panelBg = [NSColor colorWithCalibratedWhite:0.96 alpha:1.0];
    border = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    textMain = [NSColor blackColor];
    textSec = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];
    accent = [NSColor colorWithCalibratedRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    self.view.window.appearance =
        [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    _themeToggle.title = @"Dark Mode";
  }

  // Logic to update views
  self.view.layer.backgroundColor = bg.CGColor;
  _rightPanel.layer.backgroundColor = panelBg.CGColor;
  _rightPanel.layer.borderColor = border.CGColor;

  // Center panel (document view)
  _centerPanel.layer.backgroundColor = bg.CGColor;
  // Scroll view needs to match background or be transparent
  if (_centerPanel.superview
          .superview) { // _centerPanel -> NSClipView -> NSScrollView
    NSScrollView *sv = (NSScrollView *)_centerPanel.superview.superview;
    if ([sv isKindOfClass:[NSScrollView class]]) {
      sv.layer.backgroundColor = bg.CGColor;
    }
  }

  // Update Text Colors
  for (NSTextField *lbl in _labels) {
    lbl.textColor = textSec;
  }
  for (NSTextField *hdr in _headers) {
    hdr.textColor = accent;
  }

  // Update Play Button
  _playButton.contentTintColor = [NSColor whiteColor];
  if (@available(macOS 11.0, *)) {
    _playButton.bezelColor = accent;
  }
}

- (IBAction)toggleTheme:(id)sender {
  _isDarkMode = !_isDarkMode;
  [self updateThemeColors];
}

#pragma mark - UI Factories

- (NSTextField *)createLabel:(NSString *)text size:(CGFloat)size {
  NSTextField *l = [[NSTextField alloc] init];
  l.stringValue = text;
  l.font = [NSFont systemFontOfSize:size weight:NSFontWeightSemibold];
  l.drawsBackground = NO;
  l.bezeled = NO;
  l.editable = NO;
  l.selectable = NO;
  return l;
}

- (void)addLabel:(NSString *)text
           frame:(NSRect)rect
          parent:(NSView *)p
        isHeader:(BOOL)isHeader {
  NSTextField *l = [self createLabel:text size:isHeader ? 12 : 11];
  l.frame = rect;
  [p addSubview:l];
  if (isHeader) {
    [_headers addObject:l];
  } else {
    [_labels addObject:l];
  }
}

- (NSButton *)createFlatButton:(NSString *)title action:(SEL)action {
  NSButton *b = [[NSButton alloc] init];
  b.title = title;
  b.bezelStyle = NSBezelStyleRegularSquare;
  b.target = self;
  b.action = action;
  return b;
}

- (NSButton *)createOutlineButton:(NSString *)title action:(SEL)action {
  NSButton *b = [[NSButton alloc] init];
  b.title = title;
  b.bezelStyle = NSBezelStyleRounded;
  b.target = self;
  b.action = action;
  return b;
}

- (CGFloat)addSectionHeader:(NSString *)text
                          y:(CGFloat)y
                     parent:(NSView *)p
                     margin:(CGFloat)m {
  [self addLabel:text frame:NSMakeRect(m, y, 200, 20) parent:p isHeader:YES];
  return y - 35;
}

- (CGFloat)addParamSlider:(NSString *)label
                      key:(NSString *)key
                        y:(CGFloat)y
                        w:(CGFloat)w
                        p:(NSView *)parent
                        m:(CGFloat)margin {
  return [self addParamSlider:label
                          key:key
                          min:0.0
                          max:1.0
                            y:y
                            w:w
                            p:parent
                            m:margin];
}

- (CGFloat)addParamSlider:(NSString *)label
                      key:(NSString *)key
                      min:(float)min
                      max:(float)max
                        y:(CGFloat)y
                        w:(CGFloat)w
                        p:(NSView *)parent
                        m:(CGFloat)margin {
  // Label on left
  [self addLabel:label
           frame:NSMakeRect(margin, y, 120, 20)
          parent:parent
        isHeader:NO];

  // Slider on right
  NSSlider *slider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(margin + 130, y, w - 130, 20)];
  slider.minValue = min;
  slider.maxValue = max;
  slider.target = self;
  slider.action = @selector(sliderChanged:);
  self.sliders[key] = slider;
  [parent addSubview:slider];

  return y - 32;
}

#pragma mark - Actions

- (void)updateUIFromGenerator {
  [_waveTypeControl setSelectedSegment:_soundGenerator.waveType];
  for (NSString *key in self.sliders) {
    if ([_soundGenerator respondsToSelector:NSSelectorFromString(key)]) {
      float val = [[_soundGenerator valueForKey:key] floatValue];
      self.sliders[key].floatValue = val;
    }
  }
  [self updateWaveformView];
}

- (void)updateWaveformView {
  if (!_waveformView)
    return;
  int len = (int)_waveformView.bounds.size.width; // 1 pixel per sample
  if (len <= 0)
    len = 200;
  len *= 2; // Higher resolution
  float *buffer = (float *)malloc(len * sizeof(float));
  [_soundGenerator generatePreview:buffer length:len];
  [_waveformView updateWaveform:buffer length:len];
  free(buffer);
}

- (void)sliderChanged:(NSSlider *)sender {
  for (NSString *key in self.sliders) {
    if (self.sliders[key] == sender) {
      [_soundGenerator setValue:@(sender.floatValue) forKey:key];
      break;
    }
  }
  [self updateWaveformView];
}

- (IBAction)waveTypeChanged:(NSSegmentedControl *)sender {
  _soundGenerator.waveType = (WaveType)sender.selectedSegment;
  [self updateWaveformView];
}

- (void)runAndSync:(SEL)action {
  if ([_soundGenerator respondsToSelector:action]) {
    [_soundGenerator performSelector:action];
    [self updateUIFromGenerator];
    [_soundGenerator playSound];
  }
}

- (IBAction)generatePickupCoin:(id)sender {
  [self runAndSync:@selector(generatePickupCoin)];
}
- (IBAction)generateLaserShoot:(id)sender {
  [self runAndSync:@selector(generateLaserShoot)];
}
- (IBAction)generateExplosion:(id)sender {
  [self runAndSync:@selector(generateExplosion)];
}
- (IBAction)generatePowerup:(id)sender {
  [self runAndSync:@selector(generatePowerup)];
}
- (IBAction)generateHitHurt:(id)sender {
  [self runAndSync:@selector(generateHitHurt)];
}
- (IBAction)generateJump:(id)sender {
  [self runAndSync:@selector(generateJump)];
}
- (IBAction)generateBlipSelect:(id)sender {
  [self runAndSync:@selector(generateBlipSelect)];
}
- (IBAction)randomize:(id)sender {
  [self runAndSync:@selector(randomize)];
}
- (IBAction)mutate:(id)sender {
  [self runAndSync:@selector(mutate)];
}

- (IBAction)playSound:(id)sender {
  [_soundGenerator playSound];
}

- (IBAction)loadSound:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  [panel
      beginSheetModalForWindow:self.view.window
             completionHandler:^(NSModalResponse r) {
               if (r == NSModalResponseOK) {
                 if ([self.soundGenerator loadSettingsFromFile:panel.URL.path])
                   [self updateUIFromGenerator];
               }
             }];
}

- (IBAction)saveSound:(id)sender {
  NSSavePanel *panel = [NSSavePanel savePanel];
  panel.nameFieldStringValue = @"sound.sfs";
  [panel beginSheetModalForWindow:self.view.window
                completionHandler:^(NSModalResponse r) {
                  if (r == NSModalResponseOK)
                    [self.soundGenerator saveSettingsToFile:panel.URL.path];
                }];
}

- (IBAction)exportWAV:(id)sender {
  NSSavePanel *panel = [NSSavePanel savePanel];
  panel.nameFieldStringValue = @"sound.wav";
  [panel beginSheetModalForWindow:self.view.window
                completionHandler:^(NSModalResponse r) {
                  if (r == NSModalResponseOK)
                    [self.soundGenerator exportWAVToFile:panel.URL.path
                                            withBitDepth:16
                                              sampleRate:44100];
                }];
}

@end
