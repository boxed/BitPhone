//
//  BitPhoneAppDelegate.m
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import "BitPhoneAppDelegate.h"
#import "EAGLView.h"
#import <time.h>

@implementation BitViewController
{
    EAGLView *glView;
}

- (void) loadView
{
    glView = [[EAGLView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    glView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = glView;
}

- (EAGLView *) glView
{
    return glView;
}

- (UIStatusBarStyle) preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void) dealloc
{
    [glView release];

    [super dealloc];
}

@end



@implementation BitPhoneAppDelegate

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    time_t t;
    time(&t);
    srand((unsigned int)t);
    return YES;
}

@end



@implementation BitPhoneSceneDelegate
{
    BitViewController *viewController;
}

@synthesize window = _window;

- (void) scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    if (![scene isKindOfClass:[UIWindowScene class]])
        return;

    viewController = [[BitViewController alloc] init];

    UIWindow *w = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    w.backgroundColor = UIColor.blackColor;
    w.rootViewController = viewController;
    self.window = w;
    [w release];

    [self.window makeKeyAndVisible];
}

- (void) sceneDidBecomeActive:(UIScene *)scene
{
    [viewController.glView startAnimation];
}

- (void) sceneWillResignActive:(UIScene *)scene
{
    [viewController.glView stopAnimation];
}

- (void) sceneDidDisconnect:(UIScene *)scene
{
    [viewController.glView stopAnimation];
}

- (void) dealloc
{
    [_window release];
    [viewController release];

    [super dealloc];
}

@end
