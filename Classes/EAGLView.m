//
//  EAGLView.m
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

#import "EAGLView.h"

#import "ES1Renderer.h"

@implementation EAGLView

@synthesize animating;
@dynamic animationFrameInterval;

/* Globals... */
double timeMultiplier = 7;
bool yesAnimation = false;
bool noAnimation = false;

GLfloat rotationMatrix[16];
GLfloat rotationMomentum = 0.4;
void addRotationByDegree(GLfloat degree)
{
    glPushMatrix();
    glLoadIdentity();
    glRotatef(degree, rotationDeltaY, rotationDeltaX, 1);
    glMultMatrixf(rotationMatrix);
    glGetFloatv(GL_MODELVIEW_MATRIX, rotationMatrix);
    glPopMatrix();
}

// You must implement this method
+ (Class) layerClass
{
    return [CAEAGLLayer class];
}

//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id) initWithCoder:(NSCoder*)coder
{    
    if ((self = [super initWithCoder:coder]))
    {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = TRUE;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        renderer = [[ES1Renderer alloc] init];
        
        if (!renderer)
        {
            [self release];
            return nil;
        }
        
        animating = FALSE;
        displayLinkSupported = FALSE;
        animationFrameInterval = 1.5;
        displayLink = nil;
        animationTimer = nil;
        
        // A system version of 3.1 or greater is required to use CADisplayLink. The NSTimer
        // class is used as fallback when it isn't available.
        NSString *reqSysVer = @"3.1";
        NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
        if ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending)
            displayLinkSupported = TRUE;
        
        glLoadIdentity();
        glGetFloatv(GL_MODELVIEW_MATRIX, rotationMatrix);
        rotationDeltaX = 1;
        rotationDeltaY = 1;
    }
    
    return self;
}

- (void) drawView:(id)sender
{
    if (yesAnimation)
    {
        if (yesAngle < 90)
            yesAngle += (float)(22/timeMultiplier);
        else
            yesAngle += (float)(8/timeMultiplier);
        
        if (yesAngle >= 180)
        {
            yesAngle = 0;
            yesAnimation = false;
        }
    }
    
    if (noAnimation)
    {
        if (noAngle < 90)
            noAngle += (float)(22/timeMultiplier);
        else
            noAngle += (float)(8/timeMultiplier);
        
        if (noAngle >= 180)
        {
            noAngle = 0;
            noAnimation = false;
        }
    }
    
    [renderer render];
}

- (void) layoutSubviews
{
    float ver = [[[UIDevice currentDevice] systemVersion] floatValue];
    if (ver >= 3.2f)
    {
        UIScreen* mainscr = [UIScreen mainScreen];
        CAEAGLLayer* layer = (CAEAGLLayer*)self.layer;
        layer.contentsScale = mainscr.scale;
        layer.opaque = TRUE;
        self.contentScaleFactor = mainscr.scale;
    }
    [renderer resizeFromLayer:(CAEAGLLayer*)self.layer];
    [self drawView:nil];
}

- (NSInteger) animationFrameInterval
{
    return animationFrameInterval;
}

- (void) setAnimationFrameInterval:(NSInteger)frameInterval
{
    // Frame interval defines how many display frames must pass between each time the
    // display link fires. The display link will only fire 30 times a second when the
    // frame internal is two on a display that refreshes 60 times a second. The default
    // frame interval setting of one will fire 60 times a second when the display refreshes
    // at 60 times a second. A frame interval setting of less than one results in undefined
    // behavior.
    if (frameInterval >= 1)
    {
        animationFrameInterval = frameInterval;
        
        if (animating)
        {
            [self stopAnimation];
            [self startAnimation];
        }
    }
}

- (void) startAnimation
{
    if (!animating)
    {
        if (displayLinkSupported)
        {
            // CADisplayLink is API new to iPhone SDK 3.1. Compiling against earlier versions will result in a warning, but can be dismissed
            // if the system version runtime check for CADisplayLink exists in -initWithCoder:. The runtime check ensures this code will
            // not be called in system versions earlier than 3.1.

            displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView:)];
            [displayLink setFrameInterval:animationFrameInterval];
            [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        }
        else
            animationTimer = [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)((1.0 / 60.0) * animationFrameInterval) target:self selector:@selector(drawView:) userInfo:nil repeats:TRUE];
        
        animating = TRUE;
    }
}

- (void)stopAnimation
{
    if (animating)
    {
        if (displayLinkSupported)
        {
            [displayLink invalidate];
            displayLink = nil;
        }
        else
        {
            [animationTimer invalidate];
            animationTimer = nil;
        }
        
        animating = FALSE;
    }
}

- (void) dealloc
{
    [renderer release];
    
    [super dealloc];
}

- (IBAction) tap:(id)sender
{
    [renderer tap];
}

static BOOL horiz = YES;
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    horiz = !horiz;
}

- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    UITouch *aTouch = [touches anyObject];
    CGPoint loc = [aTouch locationInView:self];
    CGPoint prevloc = [aTouch previousLocationInView:self];
    
    rotationDeltaX = loc.x - prevloc.x;
    rotationDeltaY = loc.y - prevloc.y;
    
    GLfloat distance = sqrt(rotationDeltaX*rotationDeltaX+rotationDeltaY*rotationDeltaY)/4;
    rotationMomentum = distance;
    addRotationByDegree(distance);
        
    self->moved = TRUE;
}

- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    if (moved)
    {
    }
    else
    {
        [self tap:self];
    }
    moved = FALSE;
}

- (void)touchesCancelled:(NSSet*)touches withEvent:(UIEvent*)event
{
}

@end
