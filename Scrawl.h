//
//  Scrawl.h
//  GEForms3
//
//  Created by Steve Marriott on 10/7/11.
//  Copyright (c) 2011 Big Nerd Ranch. All rights reserved.
//
//  Adapted from BNR iOS book example "TouchDraw"
#import <Foundation/Foundation.h>

extern NSString *kScrawlPointsEncodingKey;

@interface Scrawl : NSObject <NSCoding>
{
    NSMutableArray *scrawlPoints;
}

@property (nonatomic, retain) NSMutableArray *scrawlPoints;

+ (id)createWithPoint:(CGPoint)point;

-(void)addPoint:(CGPoint)pt;
-(void)addPoint:(CGPoint)pt asIntegralValues:(BOOL)asIntegralValues;

-(NSInteger)numPoints;
-(NSMutableArray *)allScrawlPoints;

@end
