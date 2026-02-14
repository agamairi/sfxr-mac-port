//
//  WaveformView.m
//  sfxr-macos
//
//  Created by sfxr-macos on 2026/02/14.
//

#import "WaveformView.h"
#import <QuartzCore/QuartzCore.h>

@interface WaveformView ()
@property(nonatomic, strong) NSVisualEffectView *glassView;
@property(nonatomic, strong) CAShapeLayer *waveLayer;
@property(nonatomic, strong) CAShapeLayer *waveGlowLayer;
@end

@implementation WaveformView

- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.wantsLayer = YES;
  self.layer.masksToBounds = NO;
  self.layer.backgroundColor = [NSColor clearColor].CGColor;

  // Glass Morphism Background
  _glassView = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
  _glassView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  _glassView.material = NSVisualEffectMaterialHUDWindow;
  _glassView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  _glassView.state = NSVisualEffectStateActive;
  _glassView.wantsLayer = YES;
  _glassView.layer.cornerRadius = 16.0;
  _glassView.layer.masksToBounds = YES;
  _glassView.layer.borderWidth = 1.0;
  _glassView.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.2].CGColor;

  [self addSubview:_glassView];

  // Shadow for depth
  NSShadow *shadow = [[NSShadow alloc] init];
  shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.3];
  shadow.shadowOffset = NSMakeSize(0, -4);
  shadow.shadowBlurRadius = 10.0;
  self.shadow = shadow;

  // Wave Layers
  _waveLayer = [CAShapeLayer layer];
  _waveLayer.strokeColor =
      [NSColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.9].CGColor;
  _waveLayer.fillColor = [NSColor clearColor].CGColor;
  _waveLayer.lineWidth = 2.0;
  _waveLayer.lineCap = kCALineCapRound;
  _waveLayer.lineJoin = kCALineJoinRound;

  // Glow Layer
  _waveGlowLayer = [CAShapeLayer layer];
  _waveGlowLayer.strokeColor =
      [NSColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:0.5].CGColor;
  _waveGlowLayer.fillColor = [NSColor clearColor].CGColor;
  _waveGlowLayer.lineWidth = 6.0;
  _waveGlowLayer.lineCap = kCALineCapRound;
  _waveGlowLayer.lineJoin = kCALineJoinRound;
  _waveGlowLayer.shadowColor =
      [NSColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:1.0].CGColor;
  _waveGlowLayer.shadowOffset = CGSizeMake(0, 0);
  _waveGlowLayer.shadowOpacity = 0.8;
  _waveGlowLayer.shadowRadius = 8.0;

  [_glassView.layer addSublayer:_waveGlowLayer];
  [_glassView.layer addSublayer:_waveLayer];
}

- (void)layout {
  [super layout];
  _waveLayer.frame = self.bounds;
  _waveGlowLayer.frame = self.bounds;
}

- (void)updateWaveform:(float *)data length:(int)length {
  if (length <= 0)
    return;

  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat width = self.bounds.size.width;
  CGFloat height = self.bounds.size.height;
  CGFloat midY = height / 2.0;

  [path moveToPoint:NSMakePoint(0, midY)];

  // Simple decimation if data length > view width
  // Or just plotting. Let's plot.

  CGFloat stepX = width / (CGFloat)length;

  for (int i = 0; i < length; i++) {
    CGFloat x = i * stepX;
    CGFloat y = midY - (data[i] * (height * 0.4)); // Scale amplitude
    [path lineToPoint:NSMakePoint(x, y)];
  }

  CGPathRef cgPath = [self createCGPathFromBezierPath:path];
  _waveLayer.path = cgPath;
  _waveGlowLayer.path = cgPath;
  CGPathRelease(cgPath);
}

- (CGPathRef)createCGPathFromBezierPath:(NSBezierPath *)bezierPath {
  CGMutablePathRef path = CGPathCreateMutable();
  NSInteger numElements = [bezierPath elementCount];
  if (numElements > 0) {
    NSPoint points[3];
    for (NSInteger i = 0; i < numElements; i++) {
      switch ([bezierPath elementAtIndex:i associatedPoints:points]) {
      case NSBezierPathElementMoveTo:
        CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
        break;
      case NSBezierPathElementLineTo:
        CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
        break;
      case NSBezierPathElementCubicCurveTo:
        CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y, points[1].x,
                              points[1].y, points[2].x, points[2].y);
        break;
      case NSBezierPathElementQuadraticCurveTo:
        CGPathAddQuadCurveToPoint(path, NULL, points[0].x, points[0].y,
                                  points[1].x, points[1].y);
        break;
      case NSBezierPathElementClosePath:
        CGPathCloseSubpath(path);
        break;
      }
    }
  }
  return path;
}

- (void)mouseDown:(NSEvent *)event {
  // Interactive feedback
  [NSAnimationContext
      runAnimationGroup:^(NSAnimationContext *_Nonnull context) {
        context.duration = 0.1;
        self.animator.alphaValue = 0.7;
      }
      completionHandler:^{
        self.animator.alphaValue = 1.0;
      }];

  if (self.onPlay) {
    self.onPlay();
  }
}

@end
