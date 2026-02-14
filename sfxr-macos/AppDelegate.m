//
//  AppDelegate.m
//  sfxr-macos
//
//  Application delegate for sfxr macOS port
//

#import "AppDelegate.h"
#import "MainViewController.h"

@interface AppDelegate ()
@property(strong, nonatomic) MainViewController *mainViewController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  // Create the main window
  NSRect windowRect = NSMakeRect(100, 100, 1100, 700);
  NSWindowStyleMask styleMask = NSWindowStyleMaskTitled |
                                NSWindowStyleMaskClosable |
                                NSWindowStyleMaskMiniaturizable;

  _window = [[NSWindow alloc] initWithContentRect:windowRect
                                        styleMask:styleMask
                                          backing:NSBackingStoreBuffered
                                            defer:NO];

  [_window setTitle:@"SFXR - macos"];
  [_window setMinSize:NSMakeSize(1100, 700)];

  // Create and set up the main view controller
  _mainViewController = [[MainViewController alloc] init];
  [_window setContentViewController:_mainViewController];

  // Show the window
  [_window center];
  [_window makeKeyAndOrderFront:nil];

  // Set up menu bar
  [self createMenuBar];
}

- (void)createMenuBar {
  NSMenu *mainMenu = [[NSMenu alloc] init];

  // App menu
  NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
  [mainMenu addItem:appMenuItem];

  NSMenu *appMenu = [[NSMenu alloc] init];
  [appMenuItem setSubmenu:appMenu];

  NSMenuItem *aboutItem =
      [[NSMenuItem alloc] initWithTitle:@"About sfxr"
                                 action:@selector(orderFrontStandardAboutPanel:)
                          keyEquivalent:@""];
  [appMenu addItem:aboutItem];

  [appMenu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit sfxr"
                                                    action:@selector(terminate:)
                                             keyEquivalent:@"q"];
  [appMenu addItem:quitItem];

  [NSApp setMainMenu:mainMenu];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  // Application is about to terminate
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender {
  return YES;
}

@end
