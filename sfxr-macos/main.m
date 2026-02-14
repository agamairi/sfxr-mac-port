//
//  main.m
//  sfxr-macos
//
//  macOS port of sfxr sound effect generator
//  Original by DrPetter (Tomas Pettersson)
//

#import "AppDelegate.h"
#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    [app setDelegate:delegate];
    [app run];
  }
  return 0;
}
