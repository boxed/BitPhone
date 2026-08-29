//
//  BitPhoneAppDelegate.h
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EAGLView;

@interface BitViewController : UIViewController

@property (nonatomic, readonly) EAGLView *glView;

@end



@interface BitPhoneAppDelegate : NSObject <UIApplicationDelegate>

@end



@interface BitPhoneSceneDelegate : NSObject <UIWindowSceneDelegate>

@property (nonatomic, retain) UIWindow *window;

@end
