//
//  BitPhoneAppDelegate.m
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import "BitPhoneAppDelegate.h"
#import "EAGLView.h"
#import <time.h>

@implementation BitPhoneAppDelegate

@synthesize window;
@synthesize glView;

- (void) applicationDidFinishLaunching:(UIApplication *)application
{
    time_t t;
    time(&t);
    srand(t);
    [glView startAnimation];
}

- (void) applicationWillResignActive:(UIApplication *)application
{
    [glView stopAnimation];
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
    [glView startAnimation];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [glView stopAnimation];
}

- (void) dealloc
{
    [window release];
    [glView release];
    
    [super dealloc];
}

@end
