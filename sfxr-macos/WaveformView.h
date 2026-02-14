//
//  WaveformView.h
//  sfxr-macos
//
//  Created by sfxr-macos on 2026/02/14.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface WaveformView : NSView

@property(nonatomic, copy) void (^onPlay)(void);

- (void)updateWaveform:(float *)data length:(int)length;

@end

NS_ASSUME_NONNULL_END
