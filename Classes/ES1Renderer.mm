//
//  ES1Renderer.m
//  BitPhone
//
//  Created by Anders Hovmöller on 2010-04-04.
//  Copyright Calidris 2010. All rights reserved.
//

extern "C" 
{
    #import "ES1Renderer.h"
}

GLfloat wobbleAngle     = 0.0f;
GLfloat fAngleX         = 0.0f;
GLfloat fAngleY         = 0.0f;
GLfloat fAngleZ         = 0.0f;
GLfloat yesAngle        = 0.0f;
GLfloat noAngle         = 0.0f;
GLfloat rotationDeltaX  = 0.0f;
GLfloat rotationDeltaY  = 0.0f;
int iFrameCount;
BOOL bResetFPS;

// geography definition
void normalize(GLfloat v[3])
{
    GLfloat d = sqrt(v[0]*v[0] + v[1]*v[1] + v[2]*v[2]);
    
    if (d == 0.0)
    {
        return;
    }
    
    v[0] /= d;
    v[1] /= d;
    v[2] /= d;
}

void normcrossprod(GLfloat v1[3], GLfloat v2[3], GLfloat out[3])
{
    out[0] = v1[1]*v2[2] - v1[2]*v2[1];
    out[1] = v1[2]*v2[0] - v1[0]*v2[2];
    out[2] = v1[0]*v2[1] - v1[1]*v2[0];
    
    normalize(out);
}

void AutoNormalPolygon(GLfloat vd0[3], GLfloat vd1[3], GLfloat vd2[3])
{
    GLfloat d1[3], d2[3], norm[3];
    
    for (int j = 0; j < 3; j++)
    {
        d1[j] = vd0[j] - vd1[j];
        d2[j] = vd1[j] - vd2[j];
    }
    
    normcrossprod(d1, d2, norm);
    
    /*glBegin(GL_TRIANGLES);    
     glNormal3f(norm[0], norm[1], norm[2]);
     glVertex3dv(vd0);
     glVertex3dv(vd1);
     glVertex3dv(vd2);
     glEnd();*/
    
    GLfloat vertices[3*3] = {
        vd0[0], vd0[1], vd0[2],
        vd1[0], vd1[1], vd1[2],
        vd2[0], vd2[1], vd2[2]
    };
    
    glEnableClientState(GL_VERTEX_ARRAY);
    //glEnableClientState(GL_NORMAL_ARRAY);
    glNormal3f(norm[0], norm[1], norm[2]);
    glVertexPointer(3, GL_FLOAT, 0, vertices);
    
    glDrawArrays(GL_TRIANGLES, 0, 3);
}


#define X .525731112119133606
#define Z .850650808352039932

static GLfloat vdata[12][3] =
{
    {-X, 0.0, Z}, {X, 0.0, Z}, {-X, 0.0, -Z}, {X, 0.0, -Z},
    {0.0, Z, X}, {0.0, Z, -X}, {0.0, -Z, X}, {0.0, -Z, -X},
    {Z, X, 0.0}, {-Z, X, 0.0}, {Z, -X, 0.0}, {-Z, -X, 0.0}
};

static GLuint tindices[20][3] =
{
    {1, 4, 0}, {4, 9, 0}, {4, 5, 9}, {8, 5, 4}, {1, 8, 4},
    {1, 10, 8}, {10, 3, 8}, {8, 3, 5}, {3, 2, 5}, {3, 7, 2},
    {3, 10, 7}, {10, 6, 7}, {6, 11, 7}, {6, 0, 11}, {6, 1, 0},
    {10, 1, 6}, {11, 0, 9}, {2, 11, 9}, {5, 2, 9}, {11, 2, 7}
};


void displayListIcosahedron()
{
    for (int i = 0; i < 20; i++)
    {
        AutoNormalPolygon(vdata[tindices[i][0]], vdata[tindices[i][1]], vdata[tindices[i][2]]);
    }
}


class Point2
{
public:
    GLfloat d[3];
    
    Point2()
    {
        d[0] = 0;
        d[1] = 0;
        d[2] = 0;
    }
    
    Point2(GLfloat a, GLfloat b, GLfloat c)
    {
        d[0] = a;
        d[1] = b;
        d[2] = c;
    }
    
    Point2(GLfloat in[3])
    {
        d[0] = in[0];
        d[1] = in[1];
        d[2] = in[2];
    }
    
    Point2(const Point2& in)
    {
        d[0] = in.d[0];
        d[1] = in.d[1];
        d[2] = in.d[2];
    }
    
    const Point2& operator=(const Point2& in)
    {
        d[0] = in.d[0];
        d[1] = in.d[1];
        d[2] = in.d[2];
        
        return *this;
    }
    
    void operator+=(const Point2& in)
    {
        d[0] += in.d[0];
        d[1] += in.d[1];
        d[2] += in.d[2];
    }
    
    void operator-=(const Point2& in)
    {
        d[0] -= in.d[0];
        d[1] -= in.d[1];
        d[2] -= in.d[2];
    }
    
    void operator*=(double in)
    {
        d[0] *= in;
        d[1] *= in;
        d[2] *= in;
    }
    
    Point2 operator*(const Point2& in) const
    {
        return Point2(
                      d[0] * in.d[0],
                      d[1] * in.d[1],
                      d[2] * in.d[2]);
    }
    
    Point2 operator*(double in) const
    {
        return Point2(
                      d[0] * in,
                      d[1] * in,
                      d[2] * in);
    }
    
    Point2 operator+(const Point2& in) const
    {
        return Point2(
                      d[0] + in.d[0],
                      d[1] + in.d[1],
                      d[2] + in.d[2]);
    }
    
    Point2 operator-(const Point2& in) const
    {
        return Point2(
                      d[0] - in.d[0],
                      d[1] - in.d[1],
                      d[2] - in.d[2]);
    }
    
    operator GLfloat*()
    {
        return d;
    }
};

void StarSegment(Point2 a, Point2 b, Point2 c)
{
    Point2 v1, v2;
    
    Point2 center((a[0]+b[0]+c[0])/3, (a[1]+b[1]+c[1])/3, (a[2]+b[2]+c[2])/3);
    center *= 0.3;
    
    v1 = center+(c-b)*0.1;
    v2 = center+(b-c)*0.1;
    
    AutoNormalPolygon(a, v2, v1);
}

void StarSegment2(Point2 a, Point2 b, Point2 c)
{
    Point2 v1, v2;
    
    Point2 center((a[0]+b[0]+c[0])/3, (a[1]+b[1]+c[1])/3, (a[2]+b[2]+c[2])/3);
    a *= 0.3;
    b *= 0.3;
    c *= 0.3;
    
    AutoNormalPolygon(center, a, b);
    AutoNormalPolygon(center, b, c);
    AutoNormalPolygon(center, c, a);
}


void displayListNo() 
{
    glPushMatrix();
    for (int i = 0; i < 20; i++)
    {
        StarSegment(vdata[tindices[i][0]], vdata[tindices[i][1]], vdata[tindices[i][2]]);
        StarSegment(vdata[tindices[i][1]], vdata[tindices[i][2]], vdata[tindices[i][0]]);
        StarSegment(vdata[tindices[i][2]], vdata[tindices[i][0]], vdata[tindices[i][1]]);
    }
    glPopMatrix();
    
    glScalef(0.7, 0.7, 0.7);
    for (int i = 0; i < 20; i++)
    {
        StarSegment2(vdata[tindices[i][0]], vdata[tindices[i][1]], vdata[tindices[i][2]]);
    }
}

void drawPentagon(
                  GLfloat a, GLfloat b, GLfloat c,
                  GLfloat d, GLfloat e, GLfloat f,
                  GLfloat g, GLfloat h, GLfloat i,
                  GLfloat j, GLfloat k, GLfloat l,
                  GLfloat m, GLfloat n, GLfloat o
                  )
{
    const GLfloat vertices[] = {
        a, b, c, // a
        d, e, f, // b
        m, n, o, // e
        g, h, i, // c
        j, k, l, // d
    };
    
    glVertexPointer(3, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 5);
}

void displayListDodecahedron() 
{
    glEnableClientState(GL_VERTEX_ARRAY);
    
    double dsize = 0.85;
    GLfloat t = ((sqrt(5) - 1.0) / 2.0); 
    GLfloat tt = t*t;
    t *= dsize;
    tt *= dsize;
    
    // Dodecahedron 
    glNormal3f(0, dsize, t);
    drawPentagon( // Face 0
                 t,    t,    t, // Vertex  0
                 tt,dsize,    0, // Vertex  7
                 -tt,dsize,    0, // Vertex  8
                 -t,    t,    t, // Vertex 15
                 0,   tt,dsize // Vertex  4
                 );
    
    glNormal3f(0, dsize, -t);
    drawPentagon( // Face 1
                 0,   tt,-dsize, // Vertex 10
                 -t,    t,    -t, // Vertex  9
                 -tt,dsize,     0, // Vertex  8
                 tt,dsize,     0, // Vertex  7
                 t,    t,    -t // Vertex  6
                 );
    
    glNormal3f(dsize, t, 0);
    drawPentagon( // Face 2
                 t,    t,   t, // Vertex  0
                 dsize,    0,  tt, // Vertex  1
                 dsize,    0, -tt, // Vertex  5
                 t,    t,  -t, // Vertex  6
                 tt,dsize,   0 // Vertex  7
                 );
    
    glNormal3f(dsize, -t, 0);
    drawPentagon( // Face 3
                 dsize,     0,  tt, // Vertex  1
                 t,    -t,   t, // Vertex  2
                 tt,-dsize,   0, // Vertex 12
                 t,    -t,  -t, // Vertex 11
                 dsize,     0, -tt // Vertex  5
                 );
    
    glNormal3f(0, -dsize, -t);
    drawPentagon( // Face 4
                 t,    -t,    -t, // Vertex 11
                 tt,-dsize,     0, // Vertex 12
                 -tt,-dsize,     0, // Vertex 13
                 -t,    -t,    -t, // Vertex 16
                 0,   -tt,-dsize // Vertex 17
                 );
    
    glNormal3f(0, -dsize, t);
    drawPentagon( // Face 5
                 -t,    -t,    t, // Vertex 18
                 -tt,-dsize,    0, // Vertex 13
                 tt,-dsize,    0, // Vertex 12
                 t,    -t,    t, // Vertex  2
                 0,   -tt,dsize // Vertex  3
                 );
    
    glNormal3f(t, 0, dsize);
    drawPentagon( // Face 6
                 0,  tt,dsize, // Vertex  4
                 0, -tt,dsize, // Vertex  3
                 t,  -t,    t, // Vertex  2
                 dsize,   0,   tt, // Vertex  1
                 t,   t,    t // Vertex  0
                 );
    
    glNormal3f(-t, 0, dsize);
    drawPentagon( // Face 7
                 0, -tt,dsize, // Vertex  3
                 0,  tt,dsize, // Vertex  4
                 -t,   t,    t, // Vertex 15
                 -dsize,   0,   tt, // Vertex 14
                 -t,  -t,    t // Vertex 18
                 );
    
    glNormal3f(t, 0, -dsize);
    drawPentagon( // Face 8
                 0, -tt,-dsize, // Vertex 17
                 0,  tt,-dsize, // Vertex 10
                 t,   t,    -t, // Vertex  6
                 dsize,   0,   -tt, // Vertex  5
                 t,  -t,    -t // Vertex 11
                 );
    
    glNormal3f(-t, 0, -dsize);
    drawPentagon( // Face 9
                 -t,   t,    -t, // Vertex  9
                 0,  tt,-dsize, // Vertex 10
                 0, -tt,-dsize, // Vertex 17
                 -t,    -t,  -t, // Vertex 16
                 -dsize,   0,   -tt // Vertex 19
                 );
    
    glNormal3f(-dsize, t, 0);
    drawPentagon( // Face 10
                 -tt,dsize,   0, // Vertex  8
                 -t,    t,  -t, // Vertex  9
                 -dsize,    0, -tt, // Vertex 19
                 -dsize,    0,  tt, // Vertex 14
                 -t,    t,   t // Vertex 15
                 );
    
    glNormal3f(-dsize, -t, 0);
    drawPentagon( // Face 11
                 -dsize,     0, -tt, // Vertex 19
                 -t,    -t,  -t, // Vertex 16
                 -tt,-dsize,   0, // Vertex 13
                 -t,    -t,   t, // Vertex 18
                 -dsize,     0,  tt // Vertex 14
                 );
}

void drawTriangle(
                  GLfloat a, GLfloat b, GLfloat c,
                  GLfloat d, GLfloat e, GLfloat f,
                  GLfloat g, GLfloat h, GLfloat i
                  )
{
    GLfloat vertices[] = 
    {
        a, b, c,
        d, e, f,
        g, h, i,
    };
    glVertexPointer(3, GL_FLOAT, 0, vertices);
    glDrawArrays(GL_TRIANGLES, 0, 3);
}

void displayListYes() 
{
    // top
    // front
    glNormal3f(-1, -1, -1);
    drawTriangle(
                 -1,  0,  0,
                 0,  0, -1,
                 0, -1,  0);
    
    glNormal3f( 1, -1, -1);
    drawTriangle(
                 1,  0,  0,
                 0, -1,  0,
                 0,  0, -1);
    
    // back
    glNormal3f(-1, -1,  1);
    drawTriangle(
                 0, -1,  0,
                 0,  0,  1,
                 -1,  0,  0);
    
    glNormal3f( 1, -1,  1);
    drawTriangle(
                 0, -1,  0,
                 1,  0,  0,
                 0,  0,  1);
    
    // bottom
    // front
    glNormal3f(-1,  1, -1);
    drawTriangle(
                 -1,  0,  0,
                 0,  1,  0,
                 0,  0, -1);
    
    glNormal3f( 1,  1, -1);
    drawTriangle(
                 1,  0,  0,
                 0,  0, -1,
                 0,  1,  0);
    
    // back
    glNormal3f(-1,  1,  1);
    drawTriangle(
                 0,  1,  0,
                 -1,  0,  0,
                 0,  0,  1);
    
    glNormal3f( 1,  1,  1);
    drawTriangle(
                 0,  1,  0,
                 0,  0,  1,
                 1,  0,  0);
}   

@implementation ES1Renderer

// Create an ES 1.1 context
- (id) init
{
    if (self = [super init])
    {
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context])
        {
            [self release];
            return nil;
        }
        
        // Create default framebuffer object. The backing will be allocated for the current layer in -resizeFromLayer
        glGenFramebuffersOES(1, &defaultFramebuffer);
        glGenRenderbuffersOES(1, &colorRenderbuffer);
        glBindFramebufferOES(GL_FRAMEBUFFER_OES, defaultFramebuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, colorRenderbuffer);
    }
    
    return self;
}

- (void)render
{   
    wobbleAngle += (float)(5.0f/timeMultiplier);
    if (wobbleAngle > 360.0f)
        wobbleAngle -= 360.0f;
    
    rotationMomentum /= 1.05;
    if (rotationMomentum < 0.1)
        rotationMomentum = 0.1;
    
    addRotationByDegree(rotationMomentum);
    
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
    
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustumf(-1.0, 1.0, -1.0, 1.0, 1.5, 20.0);
    
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    
    
    glTranslatef(0.0f, 0.0f, -3.0f);
    
    glViewport(0, 0, backingWidth, backingHeight);
    
    glEnable(GL_CULL_FACE);
    //glDrawBuffer(GL_FRONT);
    glEnable(GL_DEPTH_TEST);
    glDepthFunc( GL_LEQUAL );
    glDepthMask( GL_TRUE ); 
    
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0, 0, 0, 0);
    
    const GLfloat glfLightAmbient[4] = {0.1f, 0.1f, 0.1f, 1.0f};
    const GLfloat glfLightSpecular[4] = {0.7f, 0.7f, 0.7f, 1.0f};
    
    glLightfv(GL_LIGHT0, GL_AMBIENT,  glfLightAmbient);
    glLightfv(GL_LIGHT0, GL_SPECULAR, glfLightSpecular);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnable(GL_COLOR_MATERIAL);
    
    GLfloat yesScale = sin(yesAngle*3.14/180.0);
    GLfloat noScale = sin(noAngle*3.14/180.0);
    
    GLfloat lightDiffuse[4] = {(95/255.0f)*dScale, (159/255.0f)*dScale, (234/255.0f)*dScale, 1.0f};
    GLfloat lightDiffuseYes[4] = {0.988f*dYesScale, 0.8f*dYesScale, 0.25f*dYesScale, 1.0f};
    GLfloat lightDiffuseNo[4] = {0.788f*dNoScale, 0.35f*dNoScale, 0.075f*dNoScale, 1.0f};
    
    if (yesAnimation)
    {
        GLfloat light[4] = 
        {
            (GLfloat)(lightDiffuse[0]*(1-yesScale)+lightDiffuseYes[0]*yesScale), 
            (GLfloat)(lightDiffuse[1]*(1-yesScale)+lightDiffuseYes[1]*yesScale), 
            (GLfloat)(lightDiffuse[2]*(1-yesScale)+lightDiffuseYes[2]*yesScale), 
            1.0f
        };
        //glLightfv(GL_LIGHT0, GL_DIFFUSE, light);
        glColor4fv(light);
    }
    else if (noAnimation)
    {
        GLfloat light[4] = 
        {
            (GLfloat)(lightDiffuse[0]*(1-noScale)+lightDiffuseNo[0]*noScale), 
            (GLfloat)(lightDiffuse[1]*(1-noScale)+lightDiffuseNo[1]*noScale), 
            (GLfloat)(lightDiffuse[2]*(1-noScale)+lightDiffuseNo[2]*noScale), 
            1.0f
        };
        glColor4fv(light);
    }
    else
    {
        glColor4fv(lightDiffuse);
    }
        
    glPushMatrix();
    glMultMatrixf(rotationMatrix);
    glScalef(0.9, 0.9, 0.9);
    
    GLfloat wobble = 0.9+fabs(sin(wobbleAngle*3.14/180.0))/2 - yesScale/2 - noScale;
    glPushMatrix();
    glScalef(wobble, wobble, wobble);
    displayListIcosahedron();
    glPopMatrix();
    
    wobble = 1+fabs(sin((wobbleAngle+90)*3.14/180.0))/2 - yesScale/2 - noScale;
    glPushMatrix();
    glScalef(wobble, wobble, wobble);
    displayListDodecahedron();
    glPopMatrix();
    
    glPushMatrix();
    yesScale *= 1.7;
    glScalef(yesScale, yesScale, yesScale);
    displayListYes();
    glPopMatrix();
    
    glPushMatrix();
    noScale *= 1.7;
    glScalef(noScale, noScale, noScale);
    displayListNo();
    glPopMatrix();
    
    glPopMatrix();
    
    glFinish(); 
    
    // This application only creates a single color renderbuffer which is already bound at this point.
    // This call is redundant, but needed if dealing with multiple renderbuffers.
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [context presentRenderbuffer:GL_RENDERBUFFER_OES];
}

- (BOOL) resizeFromLayer:(CAEAGLLayer *)layer
{   
    // Allocate color buffer backing based on the current layer size
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, colorRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:layer];
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &rawBackingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &rawBackingHeight);
    
    // Can't detect screen res in pre 3.2 devices, but they are all 320x480 anyway.
    backingWidth = rawBackingWidth;
    backingHeight = rawBackingHeight;
    
    if (glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES)
    {
        NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }

    glGenRenderbuffersOES(1, &depthRenderbuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
    glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
        
    return YES;
}

- (void) dealloc
{
    // Tear down GL
    if (defaultFramebuffer)
    {
        glDeleteFramebuffersOES(1, &defaultFramebuffer);
        defaultFramebuffer = 0;
    }

    if (colorRenderbuffer)
    {
        glDeleteRenderbuffersOES(1, &colorRenderbuffer);
        colorRenderbuffer = 0;
    }
    
    // Tear down context
    if ([EAGLContext currentContext] == context)
        [EAGLContext setCurrentContext:nil];
    
    [context release];
    context = nil;
    
    [super dealloc];
}

- (void) tap
{
    if (!yesAnimation && !noAnimation)
    {
        NSString* path;
        if (rand() % 2)
        {
            yesAnimation = true;
            //PlaySound(MAKEINTRESOURCE(IDSound_yes), hInst, SND_RESOURCE | SND_ASYNC);
            path = [[NSBundle mainBundle] pathForResource:@"tron_bit_yes" ofType:@"aiff"];  
        }
        else
        {
            noAnimation = true;
            //PlaySound(MAKEINTRESOURCE(IDSound_no), hInst, SND_RESOURCE | SND_ASYNC);
            path = [[NSBundle mainBundle] pathForResource:@"tron_bit_no" ofType:@"aiff"];  
        }
        /*AVAudioPlayer* foo = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
        foo.delegate = self;
        [foo play];*/
        SystemSoundID soundID = 0;
        NSURL *filePath = [NSURL fileURLWithPath:path isDirectory:NO];
        AudioServicesCreateSystemSoundID((CFURLRef)filePath, &soundID);
        
        AudioServicesPlaySystemSound(soundID);
    }
}

@end
