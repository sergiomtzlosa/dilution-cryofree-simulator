#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        
        // ── Force dark appearance globally so all system controls render with
        //    white text (NSButton, NSSegmentedControl, etc.) on our dark background.
        app.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        
        // Setup Main Menu Bar
        NSMenu *menubar = [[NSMenu alloc] init];
        
        // App Menu
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        [menubar addItem:appMenuItem];
        
        NSMenu *appMenu = [[NSMenu alloc] init];
        [appMenu addItemWithTitle:@"About Dilution Cryofree Simulator" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Hide Dilution Simulator" action:@selector(hide:) keyEquivalent:@"h"];
        [appMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@"h"];
        [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
        [appMenu addItem:[NSMenuItem separatorItem]];
        [appMenu addItemWithTitle:@"Quit Dilution Simulator" action:@selector(terminate:) keyEquivalent:@"q"];
        appMenuItem.submenu = appMenu;
        
        // Window Menu
        NSMenuItem *windowMenuItem = [[NSMenuItem alloc] init];
        [menubar addItem:windowMenuItem];
        NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
        [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
        [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
        [windowMenu addItem:[NSMenuItem separatorItem]];
        [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
        windowMenuItem.submenu = windowMenu;
        
        [app setMainMenu:menubar];
        
        // Setup App Delegate and initialize UI directly
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [delegate setupApplicationUI];
        
        [app run];
    }
    return 0;
}
















































