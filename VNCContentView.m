//
//  VNCContentView.m
//  vnsea
//
//  Created by Chris Reed on 9/15/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//  Modified by: Glenn Kreisel

#import "VNCContentView.h"

@implementation VNCContentView

@synthesize delegate;


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self setOpaque:YES];
        [self setAlpha:1.0f];
        [self setBackgroundColor:[UIColor grayColor]];
        
        // The CotVNC code gives us output with the y-coordinates reversed from
        // how the iPhone likes to think about them.  Flip it vertically to fix
        // things up.
        CGAffineTransform matrix = CGAffineTransformRotate(CGAffineTransformMakeScale(-1.0, 1.0), M_PI);
        [self setTransform:matrix];
    }

    return self;
}


- (void)dealloc
{
    [_frameBuffer release];
    [super dealloc];
}


- (void)setFrameBuffer:(FrameBuffer *)buffer
{
    [_frameBuffer autorelease];
    if (buffer)
    {
        _frameBuffer = [buffer retain];
        
        CGRect f = [self frame];
        f.size = [buffer size];
        [self setFrame:f];
    }
    else
    {
        _frameBuffer = nil;
    }
}


- (void)setRemoteDisplaySize:(CGSize)remoteSize animate:(BOOL)bAnimate
{
    CGRect frame = CGRectMake(0,0, remoteSize.width, remoteSize.height);
    [self setFrame:frame];
    
    // Set our transformation matrix so that we're inverted top to bottom.
    // This accounts for the bitmap being drawn inverted. If we don't set the
    // matrix after setting the bounds, then we'd have to translate in addition
    // to scale.
    CGAffineTransform matrix = 
	CGAffineTransformRotate(CGAffineTransformMakeScale(-1.0, 1.0), M_PI);
    [self setTransform:matrix];
    _matrixPreviousTransform = matrix;
}


- (void)drawRect:(CGRect)destRect
{
	CGRect b = [self bounds];
	CGRect r = destRect;
	
	r.origin.y = b.size.height - CGRectGetMaxY(r);
	
    if (_frameBuffer){
		[_frameBuffer drawRect:r at:destRect.origin];
    } else {
		[[UIColor grayColor] set];
		CGContextRef ctx = UIGraphicsGetCurrentContext();

		CGContextFillRect (ctx, r);
	}
}


- (void)displayFromBuffer:(CGRect)aRect
{
    CGRect b = [self bounds];
    CGRect r = aRect;

    r.origin.y = b.size.height - CGRectGetMaxY(r);
    [self setNeedsDisplayInRect:r];
}

@end
