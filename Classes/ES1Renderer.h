//
//  ES1Renderer.h
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import "ESRenderer.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>

#define glColor3f(r,g,b) glColor4f(r,g,b,1.0)
#define glColor4fv(a) glColor4f(a[0], a[1], a[2], a[3])

#define dScale 1.0f
#define dYesScale 1.0f
#define dNoScale 1.0f

void displayListIcosahedron();
void displayListDodecahedron();
void displayListYes();
void displayListNo();
extern GLfloat wobbleAngle;
extern GLfloat yesAngle   ;
extern GLfloat noAngle    ;
extern GLfloat rotationDeltaX;
extern GLfloat rotationDeltaY;
extern int iFrameCount;
extern BOOL bResetFPS;
extern double timeMultiplier;
extern bool yesAnimation;
extern bool noAnimation;

extern GLfloat rotationMatrix[16];
extern GLfloat rotationMomentum;
void addRotationByDegree(GLfloat degree);
        
@interface ES1Renderer : NSObject <ESRenderer>
{
@private
    EAGLContext *context;
    
    // The pixel dimensions of the CAEAGLLayer
    GLint backingWidth;
    GLint backingHeight;
    GLint rawBackingWidth;
    GLint rawBackingHeight;
    
    // The OpenGL names for the framebuffer and renderbuffer used to render to this view
    GLuint defaultFramebuffer, colorRenderbuffer, depthRenderbuffer;
}

- (void) render;
- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer;

@end
