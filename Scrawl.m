//
//  Scrawl.m
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//
//  Adapted from BNR iOS book example "TouchDraw"

#import "Scrawl.h"

NSString *kScrawlPointsEncodingKey = @"scrawlPoints";

@implementation Scrawl

@synthesize scrawlPoints;

/* Note that the saved signature "scrawl" data ultimately would be sent back
	to a server over a possibly very poor network connection (dialup even).
	For efficiency's sake it may be necessary to save the data as recommeded
	in WWDC 2010 session <name escapes me now, "Server Controlled UI" or something>
	as binary plist containing packed drawing points rather than a keyed archive of custom 
	objects. In a very rough comparison, the archiving custom objects looks to be about about 
	10X larger: a "typical" scribble is ~10KB and 3 allocation blocks on disk (on 256GB flash drive)
	versus ~1KB and 1 disk allocation block for the old packed format. 
	While it probably won't matter for storage space reasons (even with hundreds or
	thousands of signatures in a hypothetical GE installation), 
	it may matter for network reasons. BMonk 10/25/11
*/

-(Scrawl *)init
{
    self = [super init];
    if (self) {
        scrawlPoints = [[NSMutableArray alloc] init];
    }
    
    return self;
}

+ (id)createWithPoint:(CGPoint)point
{
    Scrawl *newObj = [[[self alloc] init] autorelease];
    [newObj addPoint:point];
    return newObj;
}

// MARK: -

-(void)addPoint:(CGPoint)pt asIntegralValues:(BOOL)asIntegralValues
{
    [scrawlPoints addObject:[NSValue valueWithCGPoint:pt]];
}

-(void)addPoint:(CGPoint)pt
{
    [scrawlPoints addObject:[NSValue valueWithCGPoint:pt]];
}

-(NSInteger)numPoints
{
    return [scrawlPoints count];
}


-(NSMutableArray *)allScrawlPoints
{    // return a copy of the scrawlPoints array
   // NSMutableArray *points = [[NSMutableArray alloc]initWithArray:scrawlPoints copyItems:YES];

    return scrawlPoints;
}


// MARK: -
// MARK: NSCoding methods

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:scrawlPoints forKey:kScrawlPointsEncodingKey];
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
		
		// I had to add the retain below to get the app to work. Now this is a leak :(
		//
		// No, no worries, it's not a leak: decodeObjectForKey returns an autoreleased object
		// and this object needs to retain it. -Bill
		scrawlPoints = [[aDecoder decodeObjectForKey:kScrawlPointsEncodingKey] retain]; 
		
		
		//NSLog(@"in initWithCoder, scrawlPoints contains %d items", [scrawlPoints count]);
    }
    return self;
}

// MARK: -

-(void)dealloc 
{
	[scrawlPoints release];

	[super dealloc];
}


@end
