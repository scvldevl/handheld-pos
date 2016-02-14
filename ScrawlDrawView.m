//
//  ScrawlDrawView.m
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//
//  Adapted from BNR iOS book example "TouchDraw"

#import <QuartzCore/QuartzCore.h>

#import "ScrawlDrawView.h"
#import "NSBundle+Utils.h"

@implementation ScrawlDrawView
@synthesize completeScrawls, doubletapClearsDrawing, shakeClearsDrawing, shakeClearsIncrementally, erasingSound, scrawlColor;

- (id)initWithFrame:(CGRect)r scrawlColor:(UIColor *)scrColor backGroundColor:(UIColor *)bgColor
{
    self = [super initWithFrame:r];
    
    if (self) {
        [self setMultipleTouchEnabled:NO];

        self.completeScrawls = [NSMutableArray array];
        
        scrawlInProcess = [[NSMutableDictionary alloc] init];
		
		erasingSound = [[SoundEffect soundEffectWithContentsOfFile:[NSBundle bundlePathForResourceName:@"Erase.caf"]] retain];

        if (!bgColor) {
            bgColor = [UIColor blackColor];
        }
        [self setBackgroundColor:bgColor];
            
        if (!scrColor) {
            scrColor = [UIColor whiteColor];
        }
		scrawlColor = [scrColor retain];
	}
    return self;
}
	
- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame scrawlColor:nil backGroundColor:nil];
}

+ (id)createWithFrame:(CGRect)r scrawlColor:(UIColor *)scrColor backGroundColor:(UIColor *)bgColor
{
    return [[[self alloc] initWithFrame:r scrawlColor:scrColor backGroundColor:bgColor] autorelease];
}

- (void)dealloc
{
	[scrawlInProcess release];
	[completeScrawls release];
	[erasingSound release];
	
	[super dealloc];
}

//MARK: - Gestures


//MARK -
//MARK: Accessors

- (void)setShakeClearsDrawing:(BOOL)flag
{
	shakeClearsDrawing = flag;
	if (shakeClearsDrawing) {
		[self becomeFirstResponder];
	}
	else {
		[self resignFirstResponder];
	}
}

- (NSMutableArray *)completedScrawls
{    
    return completeScrawls;
}


// MARK: -

- (NSMutableArray *)loadScrawlForStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber 
{   // This should get called during view willAppear by its viewController
    NSString *path = [self scrawlPathForStepNumber:stepNumber inSection:sectionNumber];
   // NSLog(@"Looking for saved scrawlArray at path:%@",path);

	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data) {
		[self setCompleteScrawls:[NSMutableArray array]];
		return completeScrawls;
	}
	else {
		// avoid crashing if it's old-style data
		NSPropertyListFormat formatOnDisk = 0;
		NSError *error = nil;
		NSArray *oldFormatArray = [NSPropertyListSerialization propertyListWithData:data 
																			options:kCFPropertyListImmutable
																			 format:&formatOnDisk 
																			  error:&error];
		if (oldFormatArray && (formatOnDisk == kCFPropertyListXMLFormat_v1_0)) {
			// old format data exists. Will crash if attempt to KeyedUnarchive it
			// so just toss it and return empty array;
			NSLog(@"Discarding deprecated signature data found for step:%ld in sectionL%ld", (long)stepNumber, (long)sectionNumber);
			[[NSFileManager defaultManager] removeItemAtPath:path error:&error];
			[self setCompleteScrawls:[NSMutableArray array]];
			return completeScrawls;
		}
	}
	
	NSMutableArray *decodedArray = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	[self setCompleteScrawls:decodedArray];
	if (!completeScrawls) {
       // NSLog(@"Didn't find saved scrawlArray at path:%@, so creating new one.",path);  
		[self setCompleteScrawls:[NSMutableArray array]];
	}
	
    return completeScrawls;
}

- (void)saveScrawlArray:(NSMutableArray *)scrawlArray forStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber
{    // This save method should be called by current view's controller during viewWillDisappear

	NSString *path = [self scrawlPathForStepNumber:stepNumber inSection:sectionNumber];
    //NSLog(@"size of signature array is:%d",[scrawlArray count]);
    if ([scrawlArray count] == 0) {
        // Saving an empty signature file doesn't make sense.
        // If the scrawlArray count is 0 then delete any file that may already be
        // at path and do not save a new one.
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm removeItemAtPath:path error:nil];
    } else {
        //NSLog( @"saving signature data at path:%@", path );
        if (![NSKeyedArchiver archiveRootObject:scrawlArray toFile:path]) {
            NSLog(@"FAILED to save scrawlArray at path:%@",path);
        }        
    }
}


- (NSString *)scrawlPathForStepNumber:(NSInteger)stepNumber inSection:(NSInteger)sectionNumber
{	
	NSString *path = [self scrawlDocumentsPath];
	path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"section%ld-step%ld.scrawl", (long)sectionNumber, (long)stepNumber]];
	//NSLog( @"path for step:%d in section:%d %@", stepNumber, sectionNumber, path );
	return path;
}


- (NSString *)scrawlDocumentsPath
{
	NSArray *pathArray = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *scrawlDocumentsPath = [pathArray objectAtIndex:0];
	scrawlDocumentsPath = [scrawlDocumentsPath stringByAppendingPathComponent:@"SavedSignatures"];
	
	BOOL isDirectory = NO;
	
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:scrawlDocumentsPath isDirectory:&isDirectory];
	if ( !exists )
	{
		NSError *error = nil;
		[[NSFileManager defaultManager] createDirectoryAtPath:scrawlDocumentsPath withIntermediateDirectories:YES attributes:NULL error:&error];
		exists = [[NSFileManager defaultManager] fileExistsAtPath:scrawlDocumentsPath isDirectory:&isDirectory];
	}
	
	if ( exists && isDirectory )
		return scrawlDocumentsPath;
	else 
		return nil;
}


//MARK: -

- (void)endTouches:(NSSet *)touches 
{
    // add ending touches to "completed lines" and remove from "in process" lines
    for (UITouch *t in touches) {
        NSValue *key = [NSValue valueWithNonretainedObject:t];
        Scrawl *line = [scrawlInProcess objectForKey:key];
        
        if (line) {
            //NSLog(@"Adding scrawl with %d points.",[line numPoints]);
            [completeScrawls addObject:line];
            //NSLog(@"Total number of scrawls is now %d.",[completeScrawls count]);
            [scrawlInProcess removeObjectForKey:key];
        }
    }
    [self setNeedsDisplay];
    // If drew each scrawl in a different layer, I could could avoid the overhead of redrawing all
    // lines too often and only redraw the line in process each time.
    // This would be much faster. However, in the GEForms instance where this view will be used for initials, 
    // there aren't enough points in the drawing to hit any noticable performance degredation.    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
    [self endTouches:touches];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self endTouches:touches];
}

#define BORDER 40.0

- (BOOL)isLegit:(CGPoint)p {
    BOOL ret=NO;

    if(p.x > BORDER && p.x < (self.frame.size.width - BORDER) &&
       p.y > BORDER && p.y < (self.frame.size.height - BORDER))
        ret = YES;
    return ret;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *t in touches) {
        // Is this a double tap, and do we want to clear in response?
        if (([t tapCount] > 1) && [self doubletapClearsDrawing]) {
            [self clearAll];
            return;
        }
        
        // use the touch object (packed in an NSValue) as the key
        NSValue *key = [NSValue valueWithNonretainedObject:t];

        // Create a new scrawl for the value
        CGPoint loc = [t locationInView:self];

        if([self isLegit:loc]) {
            Scrawl *newScrawl = [Scrawl createWithPoint:loc];

            // put pair in dictionary
            [scrawlInProcess setObject:newScrawl forKey:key];
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
    
    for (UITouch *t in touches) {
        NSValue *key = [NSValue valueWithNonretainedObject:t];
        
        Scrawl *scrawl = [scrawlInProcess objectForKey:key];
        
        CGPoint loc = [t locationInView:self];
        if(scrawl)
            [scrawl addPoint:loc];
    }
    // redraw
    [self setNeedsDisplay];
    
}

// MARK: -

- (void)drawScrawlsInArray:(NSArray *)scrawlArray inContext:(CGContextRef)context
{
    for (Scrawl *cScrawl in scrawlArray) {
        
        NSArray *pointsArray = [cScrawl allScrawlPoints];
        NSInteger numPoints  = [pointsArray count];

        // Odd number of points?
        // Need to allow for single-point "dots", such as periods after initials
        NSInteger loopStartIndex = 0;
        if (numPoints % 2) {
            CGPoint oddPoint = [[pointsArray objectAtIndex:0] CGPointValue];
            CGPoint secondPoint;
            if (numPoints == 1) {
                secondPoint = CGPointMake( oddPoint.x + 1, oddPoint.y + 1); // just fake a second point 
            }
            else {
                secondPoint = [[pointsArray objectAtIndex:1] CGPointValue];
            }
            CGContextMoveToPoint(context, oddPoint.x, oddPoint.y);
            CGContextAddLineToPoint(context, secondPoint.x, secondPoint.y); 
            CGContextStrokePath(context);
            
            loopStartIndex++;;
        }
        // draw lines between remaining (known to be even number of) points
        //for (int i = loopStartIndex; i < (numPoints - 1); i++) { - implicit conversion loses integer precision
        for (long i = loopStartIndex; i < (numPoints - 1); i++) {
            // draw the sub segment of the scrawl
            CGPoint pt1 = [[pointsArray objectAtIndex:i] CGPointValue]; 
            CGPoint pt2 = [[pointsArray objectAtIndex:i+1] CGPointValue];
            CGContextMoveToPoint(context, pt1.x, pt1.y);
            CGContextAddLineToPoint(context, pt2.x, pt2.y);
            CGContextStrokePath(context);
            //NSLog(@"----drawing a sub segment");
        }
        //NSLog(@"Just completed drawing a scrawl");
    }
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(context, 3.0);
    CGContextSetLineCap(context, kCGLineCapRound);
    
    [[self scrawlColor] set];
    
    [self drawScrawlsInArray:completeScrawls inContext:context];
    
    [self drawScrawlsInArray:[scrawlInProcess allValues] inContext:context];
}

- (UIImage *)imageWithScrawlColor:(UIColor *)desiredScrawlColor backgroundColor:(UIColor *)desiredBackgroundColor
{
	UIColor *saveScrawlColor = [self scrawlColor];
	UIColor *savebackgroundColor = [self backgroundColor];
	
	if (desiredScrawlColor) {
		[self setScrawlColor:desiredScrawlColor];
	}
	if (desiredBackgroundColor) {
		[self setBackgroundColor:desiredBackgroundColor];
	}
	
	CGRect frame = [self frame];
    UIGraphicsBeginImageContext(frame.size);
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
   
	// flip the image
    //CGContextTranslateCTM(currentContext, 0, frame.size.height);
	// CGContextScaleCTM(currentContext, 1.0, -1.0);
	
	CGContextSetInterpolationQuality(currentContext, kCGInterpolationHigh);  // Image+Resize.m can be useful to further process the result
	
    [[self layer] renderInContext:currentContext];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
	[self setScrawlColor:saveScrawlColor];
	[self setBackgroundColor:savebackgroundColor];

    return image;
}

- (UIImage *)image
{
	return [self imageWithScrawlColor:nil backgroundColor:nil];
}

// MARK: -

- (void)clearAll
{
    // Clear the collections
    [scrawlInProcess removeAllObjects];
    [completeScrawls removeAllObjects];
    
    [erasingSound play];

    // Redraw
    [self setNeedsDisplay];
}

- (void)clearLastScrawl
{
    // Called from the shake event 
    if ([scrawlInProcess count] > 0) {
        // remove the scrawl in process (this won't happen much)
        [scrawlInProcess removeAllObjects];
        // Play the erasing sound
        [erasingSound play];
        // Redraw
        [self setNeedsDisplay];
        
    } else {
        // remove the last scrawl in the completeLines array (if one exists)
        if ([completeScrawls count] > 0) {
            [completeScrawls removeLastObject];
            // Play the erasing sound
            [erasingSound play];
            // Redraw
            [self setNeedsDisplay];
        }
    }
}

- (void)clearEachScrawl
{
    // Useful when user cancels, to let them see the sig being erased.
    while ([completeScrawls count]) {
        [self clearLastScrawl];
    }
}

// MARK: -
// MARK: - Shake Suport
//
// Perhaps a shake, instead of clearing the drawing, should *undo*
// a previous clear initiated by a doubletap or button.

- (BOOL)canBecomeFirstResponder {
	// we receive shake events only if someone sends us -becomeFirstResponder
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
	if ([self shakeClearsIncrementally]) {
		[self performSelector:@selector(clearLastScrawl) withObject:nil afterDelay:0.0];
	}
	else {
		[self performSelector:@selector(clearAll) withObject:nil afterDelay:0.0];
	}
}

- (void)motionCancelled:(UIEventSubtype)motion withEvent:(UIEvent *)event
{
}

@end
