//
//  main.m
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BitPhoneAppDelegate.h"

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int retVal = UIApplicationMain(argc, argv, nil, NSStringFromClass([BitPhoneAppDelegate class]));
    [pool release];
    return retVal;
}
